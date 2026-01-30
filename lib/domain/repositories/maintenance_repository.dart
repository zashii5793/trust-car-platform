import '../../core/result/result.dart';
import '../../core/error/app_error.dart';
import '../../models/maintenance_record.dart';

/// メンテナンス記録リポジトリのインターフェース
abstract interface class MaintenanceRepository {
  /// 車両のメンテナンス記録一覧を取得（リアルタイム）
  Stream<Result<List<MaintenanceRecord>, AppError>> watchVehicleRecords(String vehicleId);

  /// 車両のメンテナンス記録一覧を取得（一度だけ）
  Future<Result<List<MaintenanceRecord>, AppError>> getVehicleRecords(String vehicleId);

  /// ユーザーの全メンテナンス記録を取得
  Future<Result<List<MaintenanceRecord>, AppError>> getUserRecords(String userId);

  /// 記録IDで取得
  Future<Result<MaintenanceRecord, AppError>> getRecordById(String recordId);

  /// メンテナンス記録を追加
  Future<Result<String, AppError>> addRecord(MaintenanceRecord record);

  /// メンテナンス記録を更新
  Future<Result<void, AppError>> updateRecord(MaintenanceRecord record);

  /// メンテナンス記録を削除
  Future<Result<void, AppError>> deleteRecord(String recordId);

  /// タイプ別の記録を取得
  Future<Result<List<MaintenanceRecord>, AppError>> getRecordsByType(
    String vehicleId,
    MaintenanceType type,
  );

  /// 期間を指定して記録を取得
  Future<Result<List<MaintenanceRecord>, AppError>> getRecordsByDateRange(
    String vehicleId,
    DateTime startDate,
    DateTime endDate,
  );
}
