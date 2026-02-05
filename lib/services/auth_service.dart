import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// 認証サービス
///
/// すべてのメソッドは[Result]を返し、
/// エラーハンドリングを一貫して行える
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;

  /// GoogleSignInを遅延初期化（テスト時の初期化エラー回避）
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  /// 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  /// 認証状態の変更を監視するストリーム
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// メールアドレスとパスワードでサインアップ
  Future<Result<UserCredential, AppError>> signUpWithEmail({
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

      return Result.success(credential);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// メールアドレスとパスワードでサインイン
  Future<Result<UserCredential, AppError>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ユーザードキュメントが存在しない場合は作成（オフライン時は無視）
      try {
        await _createUserDocument(credential.user!);
      } catch (e) {
        debugPrint('signInWithEmail: _createUserDocument failed (may be offline): $e');
      }

      return Result.success(credential);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Google でサインイン
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async {
    try {
      // Google サインインフローを開始
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // ユーザーがキャンセルした場合
        return const Result.success(null);
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

      return Result.success(userCredential);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// パスワードリセットメールを送信
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const Result.success(null);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// サインアウト
  Future<Result<void, AppError>> signOut() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      await _auth.signOut();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
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
  Future<Result<AppUser?, AppError>> getUserProfile() async {
    final user = currentUser;
    if (user == null) return const Result.success(null);

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // ドキュメントが存在しない場合は作成
        await _createUserDocument(user);
        final newDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!newDoc.exists) return const Result.success(null);
        return Result.success(AppUser.fromFirestore(newDoc));
      }
      return Result.success(AppUser.fromFirestore(doc));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ユーザー情報を更新
  Future<Result<void, AppError>> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const Result.failure(AppError.auth('User not logged in', type: AuthErrorType.sessionExpired));
    }

    try {
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
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 通知設定を更新
  Future<Result<void, AppError>> updateNotificationSettings(
      NotificationSettings settings) async {
    final user = currentUser;
    if (user == null) {
      return const Result.failure(AppError.auth('User not logged in', type: AuthErrorType.sessionExpired));
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'notificationSettings': settings.toMap(),
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Firebase Auth エラーを AppError に変換
  AppError _mapAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => const AppError.auth('User not found', type: AuthErrorType.userNotFound),
      'wrong-password' || 'invalid-credential' => const AppError.auth('Invalid credentials', type: AuthErrorType.invalidCredentials),
      'email-already-in-use' => const AppError.auth('Email already in use', type: AuthErrorType.emailAlreadyInUse),
      'weak-password' => const AppError.auth('Weak password', type: AuthErrorType.weakPassword),
      'invalid-email' => const AppError.auth('Invalid email', type: AuthErrorType.invalidCredentials),
      'user-disabled' => const AppError.auth('User disabled', type: AuthErrorType.unknown),
      'too-many-requests' => const AppError.auth('Too many requests', type: AuthErrorType.tooManyRequests),
      'network-request-failed' => AppError.network(e.message ?? 'Network error'),
      _ => AppError.auth(e.message ?? 'Auth error', type: AuthErrorType.unknown),
    };
  }
}
