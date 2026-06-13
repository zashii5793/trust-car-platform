import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../models/user.dart';
import '../core/error/app_error.dart';

/// 認証状態を管理するプロバイダー
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final AnalyticsService? _analytics;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = true;
  AppError? _error;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider(
      {required AuthService authService, AnalyticsService? analyticsService})
      : _authService = authService,
        _analytics = analyticsService {
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

  /// エラー（AppError型）
  AppError? get error => _error;

  /// エラーメッセージ（ユーザー向け）
  String? get errorMessage => _error?.userMessage;

  /// エラーがリトライ可能か
  bool get isRetryable => _error?.isRetryable ?? false;

  /// 初期化
  void _init() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;

      if (user != null) {
        final result = await _authService.getUserProfile();
        result.when(
          success: (profile) => _appUser = profile,
          failure: (error) {
            assert(() {
              debugPrint(
                  'AuthProvider: getUserProfile failed: ${error.message}');
              return true;
            }());
            _appUser = null;
          },
        );
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );

    _isLoading = false;

    return result.when(
      success: (_) async {
        _analytics?.trackSignup('email');
        // Reset onboarding flag so new users see onboarding on next launch.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', false);
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
  }

  /// メールアドレスでサインイン
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    _isLoading = false;

    return result.when(
      success: (_) {
        _analytics?.trackLogin('email');
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
  }

  /// Google でサインイン
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();

    _isLoading = false;

    return result.when(
      success: (credential) {
        if (credential != null) {
          _analytics?.trackLogin('google');
        }
        notifyListeners();
        return credential != null;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
  }

  /// パスワードリセットメールを送信
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.sendPasswordResetEmail(email);

    _isLoading = false;

    return result.when(
      success: (_) {
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
  }

  /// サインアウト
  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signOut();

    result.when(
      success: (_) {},
      failure: (error) => _error = error,
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 法人アカウント情報を更新
  Future<bool> updateBusinessProfile({
    required AccountType accountType,
    required String companyName,
  }) async {
    final result = await _authService.updateBusinessProfile(
      accountType: accountType,
      companyName: companyName,
    );

    return result.when(
      success: (_) async {
        final profileResult = await _authService.getUserProfile();
        profileResult.when(
          success: (profile) => _appUser = profile,
          failure: (_) {},
        );
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
  }

  /// ユーザープロファイルを更新
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.updateUserProfile(
      displayName: displayName,
      photoUrl: photoUrl,
    );

    _isLoading = false;

    return result.when(
      success: (_) async {
        final profileResult = await _authService.getUserProfile();
        profileResult.when(
          success: (profile) => _appUser = profile,
          failure: (_) {},
        );
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
  }

  /// 通知設定を更新
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.updateNotificationSettings(settings);

    _isLoading = false;

    return result.when(
      success: (_) async {
        final profileResult = await _authService.getUserProfile();
        profileResult.when(
          success: (profile) => _appUser = profile,
          failure: (_) {},
        );
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        notifyListeners();
        return false;
      },
    );
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
