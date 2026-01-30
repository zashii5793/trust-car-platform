import 'package:flutter/foundation.dart';

/// Provider共通のベースクラス
/// ローディング状態とエラー状態を統一管理
mixin BaseProviderMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// ローディング状態を開始
  @protected
  void setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  /// ローディング状態を終了
  @protected
  void setLoaded() {
    _isLoading = false;
    notifyListeners();
  }

  /// エラーを設定
  @protected
  void setError(String message) {
    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 非同期処理のラッパー
  /// ローディング状態の管理とエラーハンドリングを統一
  @protected
  Future<bool> executeAsync(Future<void> Function() action) async {
    setLoading();
    try {
      await action();
      setLoaded();
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }
}
