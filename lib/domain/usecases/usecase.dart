import '../../core/result/result.dart';
import '../../core/error/app_error.dart';

/// ユースケースの基底クラス
///
/// 単一責任原則に従い、1つのユースケースは1つのビジネスロジックのみを担当
///
/// 使用例:
/// ```dart
/// class GetUserVehicles extends UseCase<List<Vehicle>, GetUserVehiclesParams> {
///   final VehicleRepository _repository;
///
///   GetUserVehicles(this._repository);
///
///   @override
///   Future<Result<List<Vehicle>, AppError>> call(GetUserVehiclesParams params) {
///     return _repository.getUserVehicles(params.userId);
///   }
/// }
/// ```
abstract class UseCase<T, Params> {
  /// ユースケースを実行
  Future<Result<T, AppError>> call(Params params);
}

/// パラメータなしのユースケース
abstract class UseCaseNoParams<T> {
  Future<Result<T, AppError>> call();
}

/// Streamを返すユースケース（リアルタイム監視）
abstract class StreamUseCase<T, Params> {
  Stream<Result<T, AppError>> call(Params params);
}

/// パラメータなしのStreamユースケース
abstract class StreamUseCaseNoParams<T> {
  Stream<Result<T, AppError>> call();
}

/// パラメータなしを示すクラス
class NoParams {
  const NoParams();
}
