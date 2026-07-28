import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import '../models/user.dart';
import '../core/constants/firestore_collections.dart';
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
        assert(() {
          debugPrint(
              'signInWithEmail: _createUserDocument failed (may be offline): $e');
          return true;
        }());
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

  /// Apple でサインイン
  ///
  /// Apple は初回認可時のみ氏名・メールを返すため、初回サインイン時に
  /// [_createUserDocument] で displayName を保存する。
  /// ユーザーがキャンセルした場合は `success(null)` を返す。
  Future<Result<UserCredential?, AppError>> signInWithApple() async {
    try {
      // リプレイ攻撃対策の nonce（raw を Firebase に、sha256 を Apple に渡す）
      final rawNonce = generateNonce();
      final hashedNonce = sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple は初回のみ氏名を返す。姓+名（日本語順）で結合。
      final fullName = [
        appleCredential.familyName,
        appleCredential.givenName,
      ].where((e) => e != null && e.isNotEmpty).join(' ');

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        if (fullName.isNotEmpty && userCredential.user?.displayName == null) {
          await userCredential.user?.updateDisplayName(fullName);
        }
        await _createUserDocument(
          userCredential.user!,
          displayName: fullName.isNotEmpty ? fullName : null,
        );
      }

      return Result.success(userCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      // ユーザーがキャンセルした場合は失敗扱いにしない
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Result.success(null);
      }
      return Result.failure(
          AppError.auth(e.message, type: AuthErrorType.unknown));
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Sign in with Apple 用の暗号学的にランダムな nonce を生成する（純粋関数）。
  @visibleForTesting
  static String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// 文字列の SHA-256 ハッシュを16進文字列で返す（純粋関数）。
  @visibleForTesting
  static String sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

  /// アカウントを削除する（App Store ガイドライン 5.1.1(v) 対応）。
  ///
  /// 手順:
  /// 1. `account_deletions/{uid}` に削除要求マーカーを記録（サーバー側の
  ///    連鎖purgeが30日以内に自データを削除するためのトリガー）。
  /// 2. Firebase Auth アカウントを削除（＝ログイン手段の除去）。
  /// 3. 直近ログインが古く `requires-recent-login` になった場合は、マーカーを
  ///    ロールバックして [AuthErrorType.sessionExpired] を返す（何も失わない）。
  ///
  /// 成功時、認証アカウントは消え、`authStateChanges` が null を流すため
  /// UI は自動的にログイン画面へ戻る。
  Future<Result<void, AppError>> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      return const Result.failure(AppError.auth('User not logged in',
          type: AuthErrorType.sessionExpired));
    }

    final uid = user.uid;
    final markerRef = _firestore
        .collection(FirestoreCollections.accountDeletions)
        .doc(uid);

    try {
      // 1. 削除要求マーカー（サーバー側 purge 用）
      await markerRef.set({
        'uid': uid,
        'requestedAt': Timestamp.now(),
        'status': 'pending',
      });

      // 2. 認証アカウント削除
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // 3. ロールバック（アカウントはまだ有効なのでマーカーを残さない）
          await markerRef.delete();
          return const Result.failure(AppError.auth('Recent login required',
              type: AuthErrorType.sessionExpired));
        }
        rethrow;
      }

      // Google セッションもクリア
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }

      return const Result.success(null);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ユーザードキュメントを Firestore に作成
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    final userDoc =
        _firestore.collection(FirestoreCollections.users).doc(user.uid);
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
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        // ドキュメントが存在しない場合は作成
        await _createUserDocument(user);
        final newDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .get();
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
      return const Result.failure(AppError.auth('User not logged in',
          type: AuthErrorType.sessionExpired));
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

      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .update(updates);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 法人アカウント情報を更新（アカウント種別・会社名）
  Future<Result<void, AppError>> updateBusinessProfile({
    required AccountType accountType,
    required String companyName,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const Result.failure(AppError.auth('User not logged in',
          type: AuthErrorType.sessionExpired));
    }

    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .update({
        'accountType': accountType.name,
        'companyName': companyName,
        'updatedAt': Timestamp.now(),
      });
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
      return const Result.failure(AppError.auth('User not logged in',
          type: AuthErrorType.sessionExpired));
    }

    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .update({
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
      'user-not-found' =>
        const AppError.auth('User not found', type: AuthErrorType.userNotFound),
      'wrong-password' || 'invalid-credential' => const AppError.auth(
          'Invalid credentials',
          type: AuthErrorType.invalidCredentials),
      'email-already-in-use' => const AppError.auth('Email already in use',
          type: AuthErrorType.emailAlreadyInUse),
      'weak-password' =>
        const AppError.auth('Weak password', type: AuthErrorType.weakPassword),
      'invalid-email' => const AppError.auth('Invalid email',
          type: AuthErrorType.invalidCredentials),
      'user-disabled' =>
        const AppError.auth('User disabled', type: AuthErrorType.unknown),
      'too-many-requests' => const AppError.auth('Too many requests',
          type: AuthErrorType.tooManyRequests),
      'network-request-failed' =>
        AppError.network(e.message ?? 'Network error'),
      _ =>
        AppError.auth(e.message ?? 'Auth error', type: AuthErrorType.unknown),
    };
  }
}
