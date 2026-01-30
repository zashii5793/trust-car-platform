import '../../../core/result/result.dart';
import '../../../core/error/app_error.dart';
import '../../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../usecase.dart';

/// 車両を追加するユースケース
class AddVehicle extends UseCase<String, AddVehicleParams> {
  final VehicleRepository _repository;

  AddVehicle(this._repository);

  @override
  Future<Result<String, AppError>> call(AddVehicleParams params) async {
    // バリデーション
    if (params.vehicle.maker.isEmpty) {
      return const Result.failure(
        AppError.validation('Maker is required', field: 'maker'),
      );
    }
    if (params.vehicle.model.isEmpty) {
      return const Result.failure(
        AppError.validation('Model is required', field: 'model'),
      );
    }
    if (params.vehicle.year < 1900 || params.vehicle.year > DateTime.now().year + 1) {
      return const Result.failure(
        AppError.validation('Invalid year', field: 'year'),
      );
    }

    return _repository.addVehicle(params.vehicle);
  }
}

/// 車両を更新するユースケース
class UpdateVehicle extends UseCase<void, UpdateVehicleParams> {
  final VehicleRepository _repository;

  UpdateVehicle(this._repository);

  @override
  Future<Result<void, AppError>> call(UpdateVehicleParams params) async {
    // 存在確認
    final existingResult = await _repository.getVehicleById(params.vehicle.id);
    if (existingResult.isFailure) {
      return Result.failure(existingResult.errorOrNull!);
    }

    return _repository.updateVehicle(params.vehicle);
  }
}

/// 車両を削除するユースケース
class DeleteVehicle extends UseCase<void, DeleteVehicleParams> {
  final VehicleRepository _repository;

  DeleteVehicle(this._repository);

  @override
  Future<Result<void, AppError>> call(DeleteVehicleParams params) {
    return _repository.deleteVehicle(params.vehicleId);
  }
}

/// 走行距離を更新するユースケース
class UpdateMileage extends UseCase<void, UpdateMileageParams> {
  final VehicleRepository _repository;

  UpdateMileage(this._repository);

  @override
  Future<Result<void, AppError>> call(UpdateMileageParams params) async {
    // バリデーション
    if (params.mileage < 0) {
      return const Result.failure(
        AppError.validation('Mileage cannot be negative', field: 'mileage'),
      );
    }

    // 現在の走行距離を取得して減っていないかチェック
    final vehicleResult = await _repository.getVehicleById(params.vehicleId);
    if (vehicleResult.isFailure) {
      return Result.failure(vehicleResult.errorOrNull!);
    }

    final currentMileage = vehicleResult.valueOrNull!.mileage;
    if (params.mileage < currentMileage && !params.allowDecrease) {
      return Result.failure(
        AppError.validation(
          'New mileage ($params.mileage) is less than current ($currentMileage)',
          field: 'mileage',
        ),
      );
    }

    return _repository.updateMileage(params.vehicleId, params.mileage);
  }
}

// パラメータクラス

class AddVehicleParams {
  final Vehicle vehicle;

  const AddVehicleParams({required this.vehicle});
}

class UpdateVehicleParams {
  final Vehicle vehicle;

  const UpdateVehicleParams({required this.vehicle});
}

class DeleteVehicleParams {
  final String vehicleId;

  const DeleteVehicleParams({required this.vehicleId});
}

class UpdateMileageParams {
  final String vehicleId;
  final int mileage;
  final bool allowDecrease;

  const UpdateMileageParams({
    required this.vehicleId,
    required this.mileage,
    this.allowDecrease = false,
  });
}
