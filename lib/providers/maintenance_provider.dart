import 'package:flutter/foundation.dart';
import '../models/maintenance_record.dart';
import '../services/firebase_service.dart';

class MaintenanceProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<MaintenanceRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  List<MaintenanceRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 特定車両の履歴をリスニング
  void listenToMaintenanceRecords(String vehicleId) {
    _firebaseService.getVehicleMaintenanceRecords(vehicleId).listen(
      (records) {
        _records = records;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // 履歴を追加
  Future<bool> addMaintenanceRecord(MaintenanceRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.addMaintenanceRecord(record);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 履歴を更新
  Future<bool> updateMaintenanceRecord(String recordId, MaintenanceRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.updateMaintenanceRecord(recordId, record);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 履歴を削除
  Future<bool> deleteMaintenanceRecord(String recordId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.deleteMaintenanceRecord(recordId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
