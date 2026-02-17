import 'package:flutter/foundation.dart';
import 'service_locator.dart';
import '../error/app_error.dart';
import '../logging/logging_service.dart';
import '../logging/logging_service_impl.dart';
import '../performance/performance_service.dart';
import '../performance/performance_service_impl.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/vehicle_certificate_ocr_service.dart';
import '../../services/invoice_ocr_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/image_processing_service.dart';
import '../../services/invoice_service.dart';
import '../../services/document_service.dart';
import '../../services/service_menu_service.dart';
import '../../services/vehicle_master_service.dart';
import '../../services/part_recommendation_service.dart';
import '../../services/shop_service.dart';
import '../../services/inquiry_service.dart';
import '../../services/post_service.dart';
import '../../services/follow_service.dart';
import '../../services/vehicle_listing_service.dart';
import '../../services/drive_log_service.dart';

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

    // Logging Service (register first for error logging)
    locator.registerLazySingleton<LoggingService>(() => LoggingServiceImpl());

    // Set up logging hook for app_error.dart
    final loggingService = locator.get<LoggingService>();
    setAppErrorLogger((appError, {tag, stackTrace}) {
      loggingService.logAppError(appError, tag: tag, stackTrace: stackTrace);
    });

    // Performance Service (register after LoggingService)
    locator.registerLazySingleton<PerformanceService>(
      () => PerformanceServiceImpl(loggingService: loggingService),
    );

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

    // Phase 5: Invoice, Document, ServiceMenu Services
    locator.registerLazySingleton<InvoiceService>(() => InvoiceService());
    locator.registerLazySingleton<DocumentService>(() => DocumentService());
    locator.registerLazySingleton<ServiceMenuService>(() => ServiceMenuService());

    // Vehicle Master Service (for maker/model/grade selection)
    locator.registerLazySingleton<VehicleMasterService>(() => VehicleMasterService());

    // Part Recommendation Service (AI-powered part suggestions)
    locator.registerLazySingleton<PartRecommendationService>(() => PartRecommendationService());

    // BtoB Marketplace Services
    locator.registerLazySingleton<ShopService>(() => ShopService());
    locator.registerLazySingleton<InquiryService>(() => InquiryService());

    // SNS/Community Services
    locator.registerLazySingleton<PostService>(() => PostService());
    locator.registerLazySingleton<FollowService>(() => FollowService());

    // Vehicle Listing Service (Purchase Recommendations)
    locator.registerLazySingleton<VehicleListingService>(() => VehicleListingService());

    // Drive Log Service (Drive Log/Map features)
    locator.registerLazySingleton<DriveLogService>(() => DriveLogService());

    _initialized = true;
  }

  /// テスト用：依存性をリセット
  @visibleForTesting
  static void reset() {
    // ignore: invalid_use_of_visible_for_testing_member
    ServiceLocator.instance.reset();
    setAppErrorLogger(null); // Clear logging hook
    _initialized = false;
  }
}
