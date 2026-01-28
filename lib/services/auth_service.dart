import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

/// 認証サービス
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  /// 認証状態の変更を監視するストリーム
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// メールアドレスとパスワードでサインアップ
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ユーザープロファイルを更新
      if (displayName != null) {
        await credential.user?.updateDisplayName(displayName);
      }

      // Firestore にユーザードキュメントを作成
      await _createUserDocument(credential.user!, displayName: displayName);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// メールアドレスとパスワードでサインイン
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ユーザードキュメントが存在しない場合は作成
      await _createUserDocument(credential.user!);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Google でサインイン
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google サインインフローを開始
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // ユーザーがキャンセルした場合
        return null;
      }

      // Google 認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase 認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase でサインイン
      final userCredential = await _auth.signInWithCredential(credential);

      // 新規ユーザーの場合は Firestore にドキュメントを作成
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// パスワードリセットメールを送信
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// ユーザードキュメントを Firestore に作成
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      final appUser = AppUser(
        id: user.uid,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userDoc.set(appUser.toMap());
    }
  }

  /// ユーザー情報を取得
  Future<AppUser?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // ドキュメントが存在しない場合は作成
        await _createUserDocument(user);
        final newDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!newDoc.exists) return null;
        return AppUser.fromFirestore(newDoc);
      }
      return AppUser.fromFirestore(doc);
    } catch (e) {
      // Firestoreエラー時はnullを返す（フリーズ防止）
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  /// ユーザー情報を更新
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('ユーザーがログインしていません');

    final updates = <String, dynamic>{
      'updatedAt': Timestamp.now(),
    };

    if (displayName != null) {
      updates['displayName'] = displayName;
      await user.updateDisplayName(displayName);
    }

    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
      await user.updatePhotoURL(photoUrl);
    }

    await _firestore.collection('users').doc(user.uid).update(updates);
  }

  /// 通知設定を更新
  Future<void> updateNotificationSettings(
      NotificationSettings settings) async {
    final user = currentUser;
    if (user == null) throw Exception('ユーザーがログインしていません');

    await _firestore.collection('users').doc(user.uid).update({
      'notificationSettings': settings.toMap(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Firebase Auth エラーをハンドリング
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('このメールアドレスは登録されていません');
      case 'wrong-password':
        return Exception('パスワードが正しくありません');
      case 'email-already-in-use':
        return Exception('このメールアドレスは既に使用されています');
      case 'weak-password':
        return Exception('パスワードが弱すぎます。6文字以上で設定してください');
      case 'invalid-email':
        return Exception('メールアドレスの形式が正しくありません');
      case 'user-disabled':
        return Exception('このアカウントは無効化されています');
      case 'too-many-requests':
        return Exception('リクエストが多すぎます。しばらく待ってから再試行してください');
      case 'operation-not-allowed':
        return Exception('この操作は許可されていません');
      case 'network-request-failed':
        return Exception('ネットワークエラーが発生しました');
      default:
        return Exception('認証エラーが発生しました: ${e.message}');
    }
  }
}
