import 'package:flutter/foundation.dart';
import '../models/drive_log.dart';
import '../services/drive_log_service.dart';
import '../core/constants/pagination.dart';
import '../core/error/app_error.dart';

/// ドライブログ管理プロバイダー
///
/// - ユーザーのドライブ履歴一覧の管理
/// - ドライブログの削除
class DriveLogProvider with ChangeNotifier {
  final DriveLogService _service;

  DriveLogProvider({required DriveLogService driveLogService})
      : _service = driveLogService;

  // ── 状態 ──────────────────────────────────────────────────────────────────
  List<DriveLog> _logs = [];
  bool _isLoading = false;
  AppError? _error;
  bool _hasMore = true;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<DriveLog> get logs => _logs;
  bool get isLoading => _isLoading;
  AppError? get error => _error;
  String? get errorMessage => _error?.userMessage;
  bool get hasMore => _hasMore;
  bool get isEmpty => _logs.isEmpty && !_isLoading;

  static const int _pageSize = Pagination.driveLogPageSize;

  // ── ドライブログ読み込み ──────────────────────────────────────────────────

  /// ユーザーのドライブログ一覧を読み込む
  Future<void> loadUserDriveLogs(String userId) async {
    _isLoading = true;
    _error = null;
    _logs = [];
    _hasMore = true;
    notifyListeners();

    final result = await _service.getUserDriveLogs(
      userId: userId,
      limit: _pageSize,
    );

    result.when(
      success: (logs) {
        _logs = logs;
        _hasMore = logs.length >= _pageSize;
      },
      failure: (err) {
        _error = err;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 追加ページを読み込む
  Future<void> loadMore(String userId) async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    // **最後の1件から続きを読む。** 件数を増やして取り直す形だと、
    // 1年ぶん（200件近く）を末尾までたどるあいだに同じ記録を何度も読み、
    // 読み取りが1,000件を超える（2026-09-08 に実データで確認）。
    final result = await _service.getUserDriveLogs(
      userId: userId,
      limit: _pageSize,
      startAfterId: _logs.isEmpty ? null : _logs.last.id,
    );

    result.when(
      success: (logs) {
        _hasMore = logs.length >= _pageSize;
        _logs = [..._logs, ...logs];
      },
      failure: (err) {
        _error = err;
        _hasMore = false;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// ドライブログを削除する
  Future<bool> deleteDriveLog(String driveLogId, String userId) async {
    final result = await _service.deleteDriveLog(
      driveLogId: driveLogId,
      userId: userId,
    );

    bool success = false;
    result.when(
      success: (_) {
        _logs = _logs.where((log) => log.id != driveLogId).toList();
        success = true;
      },
      failure: (err) {
        _error = err;
      },
    );

    notifyListeners();
    return success;
  }

  /// 手動入力のドライブログを保存し、一覧の先頭に追加する。
  Future<bool> addManualDriveLog({
    required String userId,
    String? vehicleId,
    required DateTime startTime,
    DateTime? endTime,
    String? title,
    String? description,
    String? startAddress,
    String? endAddress,
    required double distanceKm,
    int durationSeconds = 0,
    WeatherCondition? weather,
    List<String>? tags,
  }) async {
    final result = await _service.createManualDriveLog(
      userId: userId,
      vehicleId: vehicleId,
      startTime: startTime,
      endTime: endTime,
      title: title,
      description: description,
      startAddress: startAddress,
      endAddress: endAddress,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      weather: weather,
      tags: tags,
    );

    var success = false;
    result.when(
      success: (log) {
        _logs = [log, ..._logs];
        _error = null;
        success = true;
      },
      failure: (err) {
        _error = err;
      },
    );
    notifyListeners();
    return success;
  }

  /// 状態をリセットする（ログアウト時など）
  void clear() {
    _logs = [];
    _isLoading = false;
    _error = null;
    _hasMore = true;
    notifyListeners();
  }
}
