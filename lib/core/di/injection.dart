import 'package:flutter/foundation.dart';
import 'service_locator.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/recommendation_service.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_vehicle_repository.dart';
import '../../data/repositories/firebase_maintenance_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

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

    // Services（レガシー：段階的に移行）
    locator.registerLazySingleton<FirebaseService>(() => FirebaseService());
    locator.registerLazySingleton<AuthService>(() => AuthService());
    locator.registerLazySingleton<RecommendationService>(() => RecommendationService());

    // Repositories
    locator.registerLazySingleton<VehicleRepository>(
      () => FirebaseVehicleRepository(),
    );
    locator.registerLazySingleton<MaintenanceRepository>(
      () => FirebaseMaintenanceRepository(),
    );
    locator.registerLazySingleton<AuthRepository>(
      () => FirebaseAuthRepository(),
    );

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
