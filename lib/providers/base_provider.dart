import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/retry_config.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// Provider共通のベースMixin
///
/// 使い方:
/// ```dart
/// class MyProvider with ChangeNotifier, BaseProviderMixin {
///   Future<void> loadData() => runResultWithLoading(
///     () => _service.getData(),
///     onSuccess: (data) { _data = data; },
///   );
/// }
/// ```
mixin BaseProviderMixin on ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  AppError? _appError;
  int _retryCount = 0;
  Timer? _retryTimer;

  bool get isLoading => _isLoading;
  AppError? get appError => _appError;
  String? get errorMessage => _appError?.userMessage;
  bool get isRetryable => _appError?.isRetryable ?? false;

  // ── Loading helpers ───────────────────────────────────────────────────────

  @protected
  void setLoading() {
    _isLoading = true;
    _appError = null;
    notifyListeners();
  }

  @protected
  void setLoaded() {
    _isLoading = false;
    notifyListeners();
  }

  @protected
  void setAppError(AppError error) {
    _appError = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _appError = null;
    notifyListeners();
  }

  // ── Result runner ─────────────────────────────────────────────────────────

  /// Result<T,AppError> を返す非同期処理をローディング状態で包む。
  ///
  /// 成功時は [onSuccess] を呼び出し、失敗時はエラーをセットする。
  /// 戻り値は処理が成功したかどうかを返す。
  @protected
  Future<bool> runResultWithLoading<T>(
    Future<Result<T, AppError>> Function() action, {
    required void Function(T data) onSuccess,
    void Function(AppError error)? onFailure,
  }) async {
    setLoading();
    final result = await action();
    result.when(
      success: (data) {
        onSuccess(data);
        _retryCount = 0;
      },
      failure: (err) {
        setAppError(err);
        onFailure?.call(err);
      },
    );
    setLoaded();
    return result.isSuccess;
  }

  // ── Retry ─────────────────────────────────────────────────────────────────

  /// 指数バックオフでアクションをリトライする。
  /// 上限は [RetryConfig.maxRetries] 回。
  @protected
  void scheduleRetry(VoidCallback action) {
    if (_retryCount >= RetryConfig.maxRetries) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: RetryConfig.baseDelaySeconds << _retryCount);
    _retryCount++;
    _retryTimer = Timer(delay, action);
  }

  /// リトライタイマーをキャンセルし、カウントをリセットする。
  @protected
  void cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
  }

  // ── Legacy string-error support (backward compat) ─────────────────────────

  /// 旧 String エラーインターフェース（既存コードとの互換用）
  String? get error => _appError?.userMessage;

  @protected
  void setError(String message) {
    setAppError(AppError.unknown(message));
  }
}
