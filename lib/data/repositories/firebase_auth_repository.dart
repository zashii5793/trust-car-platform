import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/result/result.dart';
import '../../core/error/app_error.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../models/user.dart';

/// AuthRepositoryのFirebase実装
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  GoogleSignIn? _googleSignIn;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<AuthState> watchAuthState() {
    return _auth.authStateChanges().map((user) {
      if (user == null) {
        return const Unauthenticated();
      }
      return Authenticated(
        userId: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    });
  }

  @override
  Future<Result<AppUser, AppError>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return const Result.failure(
          AppError.auth('Sign in failed', type: AuthErrorType.unknown),
        );
      }

      // ユーザードキュメントを取得または作成
      final appUser = await _getOrCreateUserDocument(user);
      return Result.success(appUser);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<AppUser, AppError>> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return const Result.failure(
          AppError.auth('Sign up failed', type: AuthErrorType.unknown),
        );
      }

      final appUser = await _createUserDocument(user);
      return Result.success(appUser);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<AppUser, AppError>> signInWithGoogle() async {
    try {
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return const Result.failure(
          AppError.auth('Google sign in cancelled', type: AuthErrorType.unknown),
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return const Result.failure(
          AppError.auth('Google sign in failed', type: AuthErrorType.unknown),
        );
      }

      final appUser = await _getOrCreateUserDocument(user);
      return Result.success(appUser);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<AppUser, AppError>> signInWithApple() async {
    // TODO: Apple Sign In実装
    return const Result.failure(
      AppError.unknown('Apple Sign In not implemented'),
    );
  }

  @override
  Future<Result<void, AppError>> signOut() async {
    try {
      await _googleSignIn?.signOut();
      await _auth.signOut();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
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

  @override
  Future<Result<AppUser, AppError>> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const Result.failure(
        AppError.auth('No user signed in', type: AuthErrorType.sessionExpired),
      );
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final appUser = await _createUserDocument(user);
        return Result.success(appUser);
      }
      return Result.success(AppUser.fromFirestore(doc));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> updateUser(AppUser user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Result.failure(
          AppError.auth('No user signed in', type: AuthErrorType.sessionExpired),
        );
      }

      // Firestoreのユーザードキュメントを削除
      await _firestore.collection('users').doc(user.uid).delete();

      // Firebase Authのユーザーを削除
      await user.delete();

      return const Result.success(null);
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ヘルパーメソッド

  Future<AppUser> _getOrCreateUserDocument(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return await _createUserDocument(user);
    } catch (e) {
      debugPrint('_getOrCreateUserDocument error: $e');
      // Firestoreアクセスに失敗した場合はFirebaseAuthの情報からAppUserを作成
      return AppUser(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<AppUser> _createUserDocument(User user, {String? displayName}) async {
    final appUser = AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: displayName ?? user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
    return appUser;
  }

  AppError _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AppError.auth(
          'User not found',
          type: AuthErrorType.userNotFound,
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AppError.auth(
          'Invalid credentials',
          type: AuthErrorType.invalidCredentials,
        );
      case 'email-already-in-use':
        return const AppError.auth(
          'Email already in use',
          type: AuthErrorType.emailAlreadyInUse,
        );
      case 'weak-password':
        return const AppError.auth(
          'Weak password',
          type: AuthErrorType.weakPassword,
        );
      case 'too-many-requests':
        return const AppError.auth(
          'Too many requests',
          type: AuthErrorType.tooManyRequests,
        );
      default:
        return AppError.auth(e.message ?? 'Authentication error');
    }
  }
}
