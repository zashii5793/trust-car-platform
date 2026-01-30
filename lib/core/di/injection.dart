import 'package:flutter/foundation.dart';
import 'service_locator.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/recommendation_service.dart';

/// 依存性の登録を行うクラス
///
/// アプリ起動時に `Injection.init()` を呼び出す
class Injection {
  Injection._();

  static bool _initialized = false;

  /// 依存性を初期化
  static Future<void> init() async {
    if (_initialized) return;

    final locator = ServiceLocator.instance;

    // Services
    locator.registerLazySingleton<FirebaseService>(() => FirebaseService());
    locator.registerLazySingleton<AuthService>(() => AuthService());
    locator.registerLazySingleton<RecommendationService>(() => RecommendationService());

    // Repositories（将来的に実装）
    // locator.registerLazySingleton<VehicleRepository>(
    //   () => FirebaseVehicleRepository(locator.get<FirebaseService>()),
    // );
    // locator.registerLazySingleton<MaintenanceRepository>(
    //   () => FirebaseMaintenanceRepository(locator.get<FirebaseService>()),
    // );
    // locator.registerLazySingleton<AuthRepository>(
    //   () => FirebaseAuthRepository(locator.get<AuthService>()),
    // );

    // UseCases（将来的に実装）
    // locator.register<GetUserVehicles>(
    //   () => GetUserVehicles(locator.get<VehicleRepository>()),
    // );

    _initialized = true;
  }

  /// テスト用：依存性をリセット
  @visibleForTesting
  static void reset() {
    // ignore: invalid_use_of_visible_for_testing_member
    ServiceLocator.instance.reset();
    _initialized = false;
  }
}
