import '../../core/result/result.dart';
import '../../core/error/app_error.dart';
import '../../models/vehicle.dart';

/// 車両リポジトリのインターフェース
///
/// データソース（Firebase、ローカルDB、APIなど）に依存しない抽象化
/// テスト時にはモックに差し替え可能
abstract interface class VehicleRepository {
  /// ユーザーの車両一覧を取得（リアルタイム）
  Stream<Result<List<Vehicle>, AppError>> watchUserVehicles(String userId);

  /// ユーザーの車両一覧を取得（一度だけ）
  Future<Result<List<Vehicle>, AppError>> getUserVehicles(String userId);

  /// 車両IDで取得
  Future<Result<Vehicle, AppError>> getVehicleById(String vehicleId);

  /// 車両を追加
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle);

  /// 車両を更新
  Future<Result<void, AppError>> updateVehicle(Vehicle vehicle);

  /// 車両を削除
  Future<Result<void, AppError>> deleteVehicle(String vehicleId);

  /// 走行距離を更新
  Future<Result<void, AppError>> updateMileage(String vehicleId, int mileage);
}
