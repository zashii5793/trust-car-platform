import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/maintenance_csv_export_service.dart';
import 'package:flutter/foundation.dart';
import 'service_locator.dart';
import '../error/app_error.dart';
import '../logging/logging_service.dart';
import '../logging/logging_service_impl.dart';
import '../logging/browser_user_agent.dart';
import '../logging/web_error_reporter.dart';
import '../performance/performance_service.dart';
import '../performance/performance_service_impl.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/notification_state_store.dart';
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
import '../../services/shop_report_service.dart';
import '../../services/shop_subscription_service.dart';
import '../../services/shop_plan_request_service.dart';
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
import '../../services/safety_tip_service.dart';
import '../../services/vehicle_retirement_service.dart';
import '../../services/fleet_member_service.dart';
import '../../services/shop_comparison_service.dart';
import '../../services/feature_flag_service.dart';
import '../../services/firebase_remote_flag_source.dart';
import '../../services/shop_demand_service.dart';
import '../../services/feedback_service.dart';
import '../constants/app_info.dart';
import '../../services/shop_invite_service.dart';
import '../../services/shop_ledger_service.dart';
import '../../services/vehicle_share_service.dart';
import '../../services/model_cost_report_service.dart';
import '../../services/vehicle_profile_service.dart';
import '../../services/maintenance_history_import_service.dart';
import '../../services/shop_staff_service.dart';
import '../../services/detail_delivery_service.dart';
import '../../services/ledger_link_service.dart';
import '../../services/shop_audit_service.dart';
import '../../services/fuel_service.dart';

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

    // ウェブ版の不具合の送り先（Crashlytics は Web 非対応のため Firestore へ）。
    // 起動の途中で落ちたものも拾えるよう、ログの直後に登録する。
    // フックの取り付けは main.dart（ウェブのリリース版だけ）。
    // uid は送るときに引く（AuthService はこのあとで登録される）。
    locator.registerLazySingleton<WebErrorReporter>(
      () => WebErrorReporter(
        firestore: FirebaseFirestore.instance,
        buildId: AppInfo.buildId,
        currentUrl: () => Uri.base,
        userAgent: browserUserAgent,
        currentUid: () => locator.tryGet<AuthService>()?.currentUser?.uid,
      ),
    );

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
        () => RecommendationService(
              scheduleService: locator.get<MaintenanceScheduleService>(),
            ));
    locator.registerLazySingleton<NotificationStateStore>(
        () => SharedPrefsNotificationStateStore());

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
    locator.registerLazySingleton<ShopReportService>(() => ShopReportService());
    locator.registerLazySingleton<RevenueCatService>(() => RevenueCatService());
    // 店舗プランの申し込み（請求書払い・2026-09-30）
    locator.registerLazySingleton<ShopPlanRequestService>(
        () => ShopPlanRequestService());

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
    locator.registerLazySingleton<MaintenanceCsvExportService>(
        () => const MaintenanceCsvExportService());

    // Maintenance Schedule Service (generates standard maintenance schedule)
    locator.registerLazySingleton<MaintenanceScheduleService>(
        () => const MaintenanceScheduleService());

    // Vehicle Spec Service (community-contributed grade spec data)
    locator
        .registerLazySingleton<VehicleSpecService>(() => VehicleSpecService());

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

    // Safety Tip Service (official-source-only safety information)
    locator.registerLazySingleton<SafetyTipService>(() => SafetyTipService());

    // Vehicle Retirement Service (売却・廃車・リース返却・譲渡)
    locator.registerLazySingleton<VehicleRetirementService>(
        () => VehicleRetirementService());

    // Fleet Member Service (role-based access control for fleet members)
    locator
        .registerLazySingleton<FleetMemberService>(() => FleetMemberService());

    // Shop Comparison Service (pure comparison/recommendation — no Firestore)
    locator.registerLazySingleton<ShopComparisonService>(
        () => const ShopComparisonService());

    // Shop Demand Service (Issue #41 Phase 2: freemium question gate demand accumulation)
    locator.registerLazySingleton<ShopDemandService>(() => ShopDemandService());

    // Feedback Service (in-app requests and bug reports).
    // Write-only from the client — the rule mirrors that. Version and platform
    // are stamped here so a report can be tied to the build it came from.
    locator.registerLazySingleton<FeedbackService>(
      () => FeedbackService(
        firestore: FirebaseFirestore.instance,
        appVersion: AppInfo.fullVersion,
        platform: AppInfo.platform,
      ),
    );

    // Shop invite (店が自分の顧客をアプリに載せるための招待コード).
    // docs/BUSINESS_MODEL_RETHINK_2026-08-27.md §4 — これが無いと、既存客は
    // 自分でアプリを探して自分で店を見つけるところから始めることになる。
    locator.registerLazySingleton<ShopInviteService>(
      () => ShopInviteService(firestore: FirebaseFirestore.instance),
    );

    // 店の顧客台帳（docs/SHOP_CRM_DESIGN_2026-09-27.md）。アプリを入れていない
    // 既存客も載せられるよう、店が自分で書く台帳をユーザーのデータとは別に持つ。
    locator.registerLazySingleton<ShopLedgerService>(
      () => ShopLedgerService(firestore: FirebaseFirestore.instance),
    );

    // 初めて行く店に「この車のこれまで」を写しで渡す（同 §7）。
    locator.registerLazySingleton<VehicleShareService>(
      () => VehicleShareService(firestore: FirebaseFirestore.instance),
    );

    // 車種別の維持費レポート（同 §8。書くのはサーバーの aggregateModelCosts）。
    locator.registerLazySingleton<ModelCostReportService>(
      () => ModelCostReportService(firestore: FirebaseFirestore.instance),
    );

    // 愛車ページ（公開）。車を主役に、公開の投稿・パーツ・ドライブを集める。
    locator.registerLazySingleton<VehicleProfileService>(
      () => VehicleProfileService(firestore: FirebaseFirestore.instance),
    );

    // 車両登録時に、過去の整備記録・請求書の内容をまとめて移す。
    locator.registerLazySingleton<MaintenanceHistoryImportService>(
      () => MaintenanceHistoryImportService(
          firestore: FirebaseFirestore.instance),
    );

    // 店のスタッフ（招待コードで参加）。顧客台帳を店主ひとりで回さないため。
    locator.registerLazySingleton<ShopStaffService>(
      () => ShopStaffService(firestore: FirebaseFirestore.instance),
    );

    // 台帳の顧客とアプリの利用者をつなぎ、整備明細を送る。
    locator.registerLazySingleton<LedgerLinkService>(
      () => LedgerLinkService(firestore: FirebaseFirestore.instance),
    );

    // 取り込んだ伝票から、アプリ利用客への整備明細をまとめて送る
    // （2026-09-29 プロダクト評価 #4）。送り方は上の1件ずつの送付と同じ。
    locator.registerLazySingleton<DetailDeliveryService>(
      () => DetailDeliveryService(
        firestore: FirebaseFirestore.instance,
        linkService: locator.get<LedgerLinkService>(),
        inquiryService: locator.get<InquiryService>(),
      ),
    );

    // 店側の操作の記録（誰がいつ顧客を見た・書いたか）。
    locator.registerLazySingleton<ShopAuditService>(
      () => ShopAuditService(firestore: FirebaseFirestore.instance),
    );

    // Fuel records (給油は月2〜4回あり、唯一の月単位の接点).
    locator.registerLazySingleton<FuelService>(
      () => FuelService(firestore: FirebaseFirestore.instance),
    );

    // Feature Flag Service (applies remote flag overrides onto AppConfig).
    // Backed by Firebase Remote Config so flags like c2cPartsMarketplace can be
    // toggled remotely without an app release.
    locator.registerLazySingleton<FeatureFlagService>(
        () => FeatureFlagService(source: FirebaseRemoteFlagSource()));

    // Apply any remote flag overrides before the app reads flags.
    // Fail-safe: if Remote Config is unavailable, local defaults are kept.
    await locator.get<FeatureFlagService>().sync();

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
