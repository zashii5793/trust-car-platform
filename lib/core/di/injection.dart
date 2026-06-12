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
import '../../services/part_listing_service.dart';
import '../../services/shop_subscription_service.dart';
import '../../services/revenue_cat_service.dart';
import '../../services/analytics_service.dart';
import '../../services/user_subscription_service.dart';
import '../../services/newsletter_service.dart';
import '../../services/ai_chat_service.dart';
import '../../services/maintenance_comment_service.dart';
import '../../services/mileage_notification_service.dart';
import '../../services/inspection_reminder_service.dart';
import '../../services/fleet_service.dart';
import '../../services/fleet_csv_export_service.dart';
import '../../services/maintenance_schedule_service.dart';
import '../../services/vehicle_spec_service.dart';
import '../../services/maintenance_trend_service.dart';
import '../../services/community_trend_service.dart';
import '../../services/faq_service.dart';
import '../../services/vehicle_history_sharing_service.dart';
import '../../services/license_plate_masking_service.dart';
import '../../services/shop_chain_service.dart';
import '../../services/popular_accessories_service.dart';
import '../../services/car_purchase_inquiry_service.dart';

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

    // Analytics Service (register early for use across all other services)
    locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());

    // User Subscription Service (B2C plan logic)
    locator.registerLazySingleton<UserSubscriptionService>(
      () => const UserSubscriptionService(),
    );

    // Core Services
    locator.registerLazySingleton<FirebaseService>(() => FirebaseService());
    locator.registerLazySingleton<AuthService>(() => AuthService());
    locator.registerLazySingleton<RecommendationService>(
        () => RecommendationService());

    // OCR & Export Services
    locator.registerLazySingleton<VehicleCertificateOcrService>(
        () => VehicleCertificateOcrService());
    locator.registerLazySingleton<InvoiceOcrService>(() => InvoiceOcrService());
    locator.registerLazySingleton<PdfExportService>(() => PdfExportService());

    // Push Notification Service
    locator.registerLazySingleton<PushNotificationService>(
        () => PushNotificationService());

    // Image Processing Service
    locator.registerLazySingleton<ImageProcessingService>(
        () => ImageProcessingService());

    // Phase 5: Invoice, Document, ServiceMenu Services
    locator.registerLazySingleton<InvoiceService>(() => InvoiceService());
    locator.registerLazySingleton<DocumentService>(() => DocumentService());
    locator
        .registerLazySingleton<ServiceMenuService>(() => ServiceMenuService());

    // Vehicle Master Service (for maker/model/grade selection)
    locator.registerLazySingleton<VehicleMasterService>(
        () => VehicleMasterService());

    // Part Recommendation Service (AI-powered part suggestions)
    locator.registerLazySingleton<PartRecommendationService>(
        () => PartRecommendationService());

    // BtoB Marketplace Services
    locator.registerLazySingleton<ShopService>(() => ShopService());
    locator.registerLazySingleton<ShopSubscriptionService>(
        () => ShopSubscriptionService());
    locator.registerLazySingleton<InquiryService>(
      () => InquiryService(
          subscriptionService: locator.get<ShopSubscriptionService>()),
    );
    locator.registerLazySingleton<RevenueCatService>(() => RevenueCatService());

    // SNS/Community Services
    locator.registerLazySingleton<PostService>(() => PostService());
    locator.registerLazySingleton<FollowService>(() => FollowService());

    // Vehicle Listing Service (Purchase Recommendations)
    locator.registerLazySingleton<VehicleListingService>(
        () => VehicleListingService());

    // Drive Log Service (Drive Log/Map features)
    locator.registerLazySingleton<DriveLogService>(() => DriveLogService());

    // Part Listing Service (user-to-user marketplace listings)
    locator.registerLazySingleton<PartListingService>(
      () => PartListingService(
        firebaseService: locator.get<FirebaseService>(),
      ),
    );

    // Newsletter Service (email newsletter creation & delivery)
    locator.registerLazySingleton<NewsletterService>(() => NewsletterService());

    // AI Chat Service (Claude-powered automotive advice)
    locator.registerLazySingleton<AiChatService>(() => AiChatService());

    // Maintenance Comment Service (rule-based AI comments for maintenance records)
    locator.registerLazySingleton<MaintenanceCommentService>(
      () => MaintenanceCommentService(),
    );

    // Mileage Notification Service (schedules 30-day local reminder after mileage update)
    locator.registerLazySingleton<MileageNotificationService>(
      () => MileageNotificationService(),
    );

    // Inspection Reminder Service (schedules 30/7/1-day local reminders
    // before each vehicle's inspection deadline)
    locator.registerLazySingleton<InspectionReminderService>(
      () => InspectionReminderService(),
    );

    // Fleet Service (corporate fleet vehicle management)
    locator.registerLazySingleton<FleetService>(() => FleetService());

    // Fleet CSV Export Service (vehicle list export for fleet admins)
    locator.registerLazySingleton<FleetCsvExportService>(
        () => const FleetCsvExportService());

    // Maintenance Schedule Service (generates standard maintenance schedule)
    locator.registerLazySingleton<MaintenanceScheduleService>(
        () => const MaintenanceScheduleService());

    // Vehicle Spec Service (community-contributed grade spec data)
    locator.registerLazySingleton<VehicleSpecService>(
        () => VehicleSpecService());

    // Maintenance Trend Service (pure analytics — no Firestore)
    locator.registerLazySingleton<MaintenanceTrendService>(
        () => const MaintenanceTrendService());

    // Community Trend Service (anonymized aggregate trends by make/model)
    locator.registerLazySingleton<CommunityTrendService>(
        () => CommunityTrendService());

    // FAQ Service (structured Q&A with shop permission control)
    locator.registerLazySingleton<FaqService>(() => FaqService());

    // Vehicle History Sharing Service (permission-based shop access to vehicle records)
    locator.registerLazySingleton<VehicleHistorySharingService>(
        () => VehicleHistorySharingService());

    // License Plate Masking Service (privacy: black-mask plate numbers on photos)
    locator.registerLazySingleton<LicensePlateMaskingService>(
        () => const LicensePlateMaskingService());

    // Shop Chain Service (multi-branch chains like コバック, ジェームス)
    locator.registerLazySingleton<ShopChainService>(() => ShopChainService());

    // Popular Accessories Service (community-driven accessory trends)
    locator.registerLazySingleton<PopularAccessoriesService>(
        () => PopularAccessoriesService());

    // Car Purchase Inquiry Service (used-car search deep links + inquiries)
    locator.registerLazySingleton<CarPurchaseInquiryService>(
        () => CarPurchaseInquiryService());

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
