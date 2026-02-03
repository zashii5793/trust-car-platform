import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/maintenance_record.dart';
import '../services/firebase_service.dart';
import '../core/error/app_error.dart';

/// 整備記録状態管理Provider
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class MaintenanceProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

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

  // 特定車両の履歴をリスニング
  void listenToMaintenanceRecords(String vehicleId) {
    // 既存のサブスクリプションをキャンセル
    _recordsSubscription?.cancel();

    _recordsSubscription = _firebaseService.getVehicleMaintenanceRecords(vehicleId).listen(
      (records) {
        _records = records;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = mapFirebaseError(error);
        notifyListeners();
      },
    );
  }

  // リソースの解放
  void stopListening() {
    _recordsSubscription?.cancel();
    _recordsSubscription = null;
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
    _recordsSubscription?.cancel();
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
  Future<bool> updateMaintenanceRecord(String recordId, MaintenanceRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _firebaseService.updateMaintenanceRecord(recordId, record);

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
