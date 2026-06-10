import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/maintenance_record.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../core/constants/retry_config.dart';
import '../core/error/app_error.dart';

/// 整備記録の並び順
enum MaintenanceSortBy {
  /// 日付が新しい順（デフォルト）
  dateDesc,

  /// 日付が古い順
  dateAsc,

  /// 費用が高い順
  costDesc,

  /// 費用が安い順
  costAsc,

  /// 整備時走行距離が多い順（未記録は末尾）
  mileageDesc,
}

/// 整備記録状態管理Provider
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class MaintenanceProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  final AnalyticsService? _analytics;

  MaintenanceProvider(
      {required FirebaseService firebaseService,
      AnalyticsService? analyticsService})
      : _firebaseService = firebaseService,
        _analytics = analyticsService;

  List<MaintenanceRecord> _records = [];
  bool _isLoading = false;
  AppError? _error;
  StreamSubscription<List<MaintenanceRecord>>? _recordsSubscription;

  List<MaintenanceRecord> get records => _records;
  bool get isLoading => _isLoading;

  /// エラー（AppError型）
  AppError? get error => _error;

  /// エラーメッセージ（ユーザー向け）
  String? get errorMessage => _error?.userMessage;

  /// エラーがリトライ可能か
  bool get isRetryable => _error?.isRetryable ?? false;

  String? _currentVehicleId;

  // 特定車両の履歴をリスニング
  void listenToMaintenanceRecords(String vehicleId) {
    // 既存のサブスクリプションをキャンセル
    _recordsSubscription?.cancel();
    _currentVehicleId = vehicleId;

    _recordsSubscription =
        _firebaseService.getVehicleMaintenanceRecords(vehicleId).listen(
      (records) {
        _records = records;
        _error = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (error) {
        _error = mapFirebaseError(error);
        notifyListeners();
        if (_currentVehicleId != null) {
          _scheduleRetry(() => listenToMaintenanceRecords(_currentVehicleId!));
        }
      },
    );
  }

  int _retryCount = 0;
  static const int _maxRetries = RetryConfig.maxRetries;
  Timer? _retryTimer;

  void _scheduleRetry(VoidCallback action) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    final delay =
        Duration(seconds: RetryConfig.baseDelaySeconds << _retryCount);
    _retryCount++;
    _retryTimer = Timer(delay, action);
  }

  // リソースの解放
  void stopListening() {
    _recordsSubscription?.cancel();
    _recordsSubscription = null;
    _retryTimer?.cancel();
    _retryCount = 0;
    _currentVehicleId = null;
  }

  // ログアウト時のクリーンアップ
  void clear() {
    stopListening();
    _records = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  /// 履歴を追加
  Future<bool> addMaintenanceRecord(MaintenanceRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _firebaseService.addMaintenanceRecord(record);

    return result.when(
      success: (_) {
        _analytics?.trackMaintenanceRecorded(record.type.name);
        _isLoading = false;
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        _isLoading = false;
        notifyListeners();
        return false;
      },
    );
  }

  /// 履歴を更新
  Future<bool> updateMaintenanceRecord(
      String recordId, MaintenanceRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result =
        await _firebaseService.updateMaintenanceRecord(recordId, record);

    return result.when(
      success: (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        _isLoading = false;
        notifyListeners();
        return false;
      },
    );
  }

  /// 履歴を削除
  Future<bool> deleteMaintenanceRecord(String recordId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _firebaseService.deleteMaintenanceRecord(recordId);

    return result.when(
      success: (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
      failure: (error) {
        _error = error;
        _isLoading = false;
        notifyListeners();
        return false;
      },
    );
  }

  /// 読み込み済み記録をキーワード・タイプ・日付範囲・費用範囲で絞り込み、
  /// 指定の並び順で返す（元のリストは変更しない）
  ///
  /// - [keyword]: タイトル・説明・店舗名の部分一致（大文字小文字を区別しない）
  /// - [types]: 空または null なら全タイプ
  /// - [from]/[to]: 両端を含む日付範囲
  /// - [minCost]/[maxCost]: 両端を含む費用範囲
  List<MaintenanceRecord> searchRecords({
    String? keyword,
    Set<MaintenanceType>? types,
    DateTime? from,
    DateTime? to,
    int? minCost,
    int? maxCost,
    MaintenanceSortBy sortBy = MaintenanceSortBy.dateDesc,
  }) {
    final kw = keyword?.trim().toLowerCase();
    Iterable<MaintenanceRecord> result = _records;

    if (kw != null && kw.isNotEmpty) {
      result = result.where((r) =>
          r.title.toLowerCase().contains(kw) ||
          (r.description?.toLowerCase().contains(kw) ?? false) ||
          (r.shopName?.toLowerCase().contains(kw) ?? false));
    }
    if (types != null && types.isNotEmpty) {
      result = result.where((r) => types.contains(r.type));
    }
    if (from != null) {
      result = result.where((r) => !r.date.isBefore(from));
    }
    if (to != null) {
      result = result.where((r) => !r.date.isAfter(to));
    }
    if (minCost != null) {
      result = result.where((r) => r.cost >= minCost);
    }
    if (maxCost != null) {
      result = result.where((r) => r.cost <= maxCost);
    }

    final list = result.toList();
    switch (sortBy) {
      case MaintenanceSortBy.dateDesc:
        list.sort((a, b) => b.date.compareTo(a.date));
      case MaintenanceSortBy.dateAsc:
        list.sort((a, b) => a.date.compareTo(b.date));
      case MaintenanceSortBy.costDesc:
        list.sort((a, b) => b.cost.compareTo(a.cost));
      case MaintenanceSortBy.costAsc:
        list.sort((a, b) => a.cost.compareTo(b.cost));
      case MaintenanceSortBy.mileageDesc:
        list.sort((a, b) {
          final am = a.mileageAtService;
          final bm = b.mileageAtService;
          if (am == null && bm == null) return 0;
          if (am == null) return 1;
          if (bm == null) return -1;
          return bm.compareTo(am);
        });
    }
    return list;
  }

  // タイプ別の履歴を取得
  List<MaintenanceRecord> getRecordsByType(MaintenanceType type) {
    return _records.where((record) => record.type == type).toList();
  }

  // 最新の履歴を取得
  MaintenanceRecord? getLatestRecord() {
    if (_records.isEmpty) return null;
    return _records.first;
  }

  // 総コストを計算
  int getTotalCost() {
    return _records.fold(0, (sum, record) => sum + record.cost);
  }
}
