import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/di/injection.dart';
import 'core/di/service_locator.dart';
import 'services/analytics_service.dart';
import 'core/logging/crashlytics_wrapper.dart';
import 'core/logging/logging_service.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/recommendation_service.dart';
import 'services/push_notification_service.dart';
import 'services/inspection_reminder_service.dart';
import 'services/notification_state_store.dart';
import 'providers/vehicle_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/part_recommendation_provider.dart';
import 'providers/post_provider.dart';
import 'providers/drive_log_provider.dart';
import 'providers/drive_recording_provider.dart';
import 'providers/shop_provider.dart';
import 'services/part_recommendation_service.dart';
import 'services/post_service.dart';
import 'services/drive_log_service.dart';
import 'services/shop_service.dart';
import 'services/inquiry_service.dart';
import 'services/shop_subscription_service.dart';
import 'providers/subscription_provider.dart';
import 'providers/user_subscription_provider.dart';
import 'services/user_subscription_service.dart';
import 'screens/auth/onboarding_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'providers/ai_chat_provider.dart';
import 'services/ai_chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Use Firebase Emulator in debug mode (local development)
  if (kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    // Disable persistence for emulator (data is ephemeral)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } else {
    // Production: enable offline persistence with 100MB cache
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB
    );
  }

  // Initialize Crashlytics (only in release mode)
  await _initializeCrashlytics();

  await Injection.init();

  // Set up logging for auth state changes
  _setupAuthLogging();

  // Initialize timezone for scheduled notifications
  PushNotificationService.initializeTimezone();

  // Initialize push notifications
  final pushService = sl.get<PushNotificationService>();
  await pushService.initialize();

  // Load the first-launch flag up front so the router can gate onboarding
  // synchronously instead of flashing a loading screen.
  final onboardingCompleted = await hasCompletedOnboarding();

  runApp(MyApp(onboardingCompleted: onboardingCompleted));
}

/// Initialize Firebase Crashlytics for crash reporting
Future<void> _initializeCrashlytics() async {
  final crashlytics = CrashlyticsWrapper.instance;
  final initialized = await crashlytics.initialize(enabled: !kDebugMode);

  if (initialized) {
    // Pass Flutter errors to Crashlytics
    FlutterError.onError = crashlytics.flutterErrorHandler;

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }
}

/// Set up logging and analytics tracking for authentication state changes
void _setupAuthLogging() {
  final logger = sl.tryGet<LoggingService>();
  final analytics = sl.tryGet<AnalyticsService>();

  final authService = sl.get<AuthService>();
  authService.authStateChanges.listen((user) {
    logger?.setUserId(user?.uid);
    analytics?.setUserId(user?.uid);
    if (user != null) {
      logger?.info('User signed in', tag: 'Auth');
    } else {
      logger?.info('User signed out', tag: 'Auth');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.onboardingCompleted});

  /// Whether onboarding was already completed (loaded at startup).
  final bool onboardingCompleted;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;
  late final ValueNotifier<bool> _onboardingCompleted;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // AuthProvider is owned here (not created inside MultiProvider) so the
    // same instance can drive the router's auth-based redirects.
    _authProvider = AuthProvider(
      authService: sl.get<AuthService>(),
      analyticsService: sl.get<AnalyticsService>(),
    );
    _onboardingCompleted = ValueNotifier<bool>(widget.onboardingCompleted);
    _router = createAppRouter(
      authProvider: _authProvider,
      onboardingCompleted: _onboardingCompleted,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _onboardingCompleted.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(
            create: (_) => VehicleProvider(
                  firebaseService: sl.get<FirebaseService>(),
                  analyticsService: sl.get<AnalyticsService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => MaintenanceProvider(
                  firebaseService: sl.get<FirebaseService>(),
                  analyticsService: sl.get<AnalyticsService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => NotificationProvider(
                  firebaseService: sl.get<FirebaseService>(),
                  recommendationService: sl.get<RecommendationService>(),
                  inspectionReminderService:
                      sl.get<InspectionReminderService>(),
                  stateStore: sl.get<NotificationStateStore>(),
                )),
        ChangeNotifierProvider(
            create: (_) => PartRecommendationProvider(
                  partRecommendationService:
                      sl.get<PartRecommendationService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => ShopProvider(
                  shopService: sl.get<ShopService>(),
                  inquiryService: sl.get<InquiryService>(),
                  analyticsService: sl.get<AnalyticsService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => SubscriptionProvider(
                  subscriptionService: sl.get<ShopSubscriptionService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => UserSubscriptionProvider(
                  service: sl.get<UserSubscriptionService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => PostProvider(
                  postService: sl.get<PostService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => DriveLogProvider(
                  driveLogService: sl.get<DriveLogService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => DriveRecordingProvider(
                  driveLogService: sl.get<DriveLogService>(),
                  analyticsService: sl.get<AnalyticsService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => AiChatProvider(
                  service: sl.get<AiChatService>(),
                )),
      ],
      child: MaterialApp.router(
        title: 'クルマ統合管理',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
