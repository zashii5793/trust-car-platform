import 'package:flutter/foundation.dart';
import 'service_locator.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/vehicle_certificate_ocr_service.dart';
import '../../services/invoice_ocr_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/image_processing_service.dart';

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

    // Core Services
    locator.registerLazySingleton<FirebaseService>(() => FirebaseService());
    locator.registerLazySingleton<AuthService>(() => AuthService());
    locator.registerLazySingleton<RecommendationService>(() => RecommendationService());

    // OCR & Export Services
    locator.registerLazySingleton<VehicleCertificateOcrService>(() => VehicleCertificateOcrService());
    locator.registerLazySingleton<InvoiceOcrService>(() => InvoiceOcrService());
    locator.registerLazySingleton<PdfExportService>(() => PdfExportService());

    // Push Notification Service
    locator.registerLazySingleton<PushNotificationService>(() => PushNotificationService());

    // Image Processing Service
    locator.registerLazySingleton<ImageProcessingService>(() => ImageProcessingService());

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
