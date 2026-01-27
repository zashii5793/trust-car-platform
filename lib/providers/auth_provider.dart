import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

/// 認証状態を管理するプロバイダー
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider() {
    _init();
  }

  /// 現在の Firebase ユーザー
  User? get firebaseUser => _firebaseUser;

  /// 現在のアプリユーザー
  AppUser? get appUser => _appUser;

  /// 認証済みかどうか
  bool get isAuthenticated => _firebaseUser != null;

  /// ローディング中かどうか
  bool get isLoading => _isLoading;

  /// エラーメッセージ
  String? get error => _error;

  /// 初期化
  void _init() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;

      if (user != null) {
        // ユーザープロファイルを取得
        _appUser = await _authService.getUserProfile();
      } else {
        _appUser = null;
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  /// メールアドレスでサインアップ
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// メールアドレスでサインイン
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Google でサインイン
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.signInWithGoogle();
      return result != null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// パスワードリセットメールを送信
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signOut();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ユーザープロファイルを更新
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.updateUserProfile(
        displayName: displayName,
        photoUrl: photoUrl,
      );

      // プロファイルを再取得
      _appUser = await _authService.getUserProfile();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 通知設定を更新
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.updateNotificationSettings(settings);

      // プロファイルを再取得
      _appUser = await _authService.getUserProfile();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
