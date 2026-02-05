import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../services/firebase_service.dart';
import '../core/error/app_error.dart';

/// 車両状態管理Provider
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class VehicleProvider with ChangeNotifier {
  final FirebaseService _firebaseService;

  VehicleProvider({required FirebaseService firebaseService})
      : _firebaseService = firebaseService;

  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _isLoading = false;
  AppError? _error;
  StreamSubscription<List<Vehicle>>? _vehiclesSubscription;

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;

  /// エラー（AppError型）
  AppError? get error => _error;

  /// エラーメッセージ（ユーザー向け）
  String? get errorMessage => _error?.userMessage;

  /// エラーがリトライ可能か
  bool get isRetryable => _error?.isRetryable ?? false;

  // 車両一覧をリスニング
  void listenToVehicles() {
    // 既存のサブスクリプションをキャンセル
    _vehiclesSubscription?.cancel();

    _vehiclesSubscription = _firebaseService.getUserVehicles().listen(
      (vehicles) {
        _vehicles = vehicles;
        _error = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (error) {
        _error = mapFirebaseError(error);
        notifyListeners();
        _scheduleRetry(() => listenToVehicles());
      },
    );
  }

  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  void _scheduleRetry(VoidCallback action) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: 2 << _retryCount); // 2s, 4s, 8s
    _retryCount++;
    _retryTimer = Timer(delay, action);
  }

  // リソースの解放
  void stopListening() {
    _vehiclesSubscription?.cancel();
    _vehiclesSubscription = null;
    _retryTimer?.cancel();
    _retryCount = 0;
  }

  // ログアウト時のクリーンアップ
  void clear() {
    stopListening();
    _vehicles = [];
    _selectedVehicle = null;
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

  // 選択中の車両を設定
  void selectVehicle(Vehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// 車両を追加
  Future<bool> addVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _firebaseService.addVehicle(vehicle);

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

  /// 車両を更新
  Future<bool> updateVehicle(String vehicleId, Vehicle vehicle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _firebaseService.updateVehicle(vehicleId, vehicle);

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

  /// 車両を削除
  Future<bool> deleteVehicle(String vehicleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _firebaseService.deleteVehicle(vehicleId);

    return result.when(
      success: (_) {
        if (_selectedVehicle?.id == vehicleId) {
          _selectedVehicle = null;
        }
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

  /// ナンバープレートの重複チェック
  Future<bool> isLicensePlateExists(String licensePlate, {String? excludeVehicleId}) async {
    final result = await _firebaseService.isLicensePlateExists(
      licensePlate,
      excludeVehicleId: excludeVehicleId,
    );

    return result.getOrElse(false);
  }
}
