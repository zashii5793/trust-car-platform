import '../../../core/result/result.dart';
import '../../../core/error/app_error.dart';
import '../../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../usecase.dart';

/// ユーザーの車両一覧を取得するユースケース
class GetUserVehicles extends UseCase<List<Vehicle>, GetUserVehiclesParams> {
  final VehicleRepository _repository;

  GetUserVehicles(this._repository);

  @override
  Future<Result<List<Vehicle>, AppError>> call(GetUserVehiclesParams params) {
    return _repository.getUserVehicles(params.userId);
  }
}

/// ユーザーの車両一覧をリアルタイム監視するユースケース
class WatchUserVehicles extends StreamUseCase<List<Vehicle>, WatchUserVehiclesParams> {
  final VehicleRepository _repository;

  WatchUserVehicles(this._repository);

  @override
  Stream<Result<List<Vehicle>, AppError>> call(WatchUserVehiclesParams params) {
    return _repository.watchUserVehicles(params.userId);
  }
}

/// GetUserVehiclesのパラメータ
class GetUserVehiclesParams {
  final String userId;

  const GetUserVehiclesParams({required this.userId});
}

/// WatchUserVehiclesのパラメータ
class WatchUserVehiclesParams {
  final String userId;

  const WatchUserVehiclesParams({required this.userId});
}
