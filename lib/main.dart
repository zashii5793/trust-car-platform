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
import 'services/shop_report_service.dart';
import 'services/shop_subscription_service.dart';
import 'providers/subscription_provider.dart';
import 'providers/user_subscription_provider.dart';
import 'services/revenue_cat_service.dart';
import 'services/user_subscription_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/app_scroll_behavior.dart';
import 'providers/ai_chat_provider.dart';
import 'providers/theme_provider.dart';
import 'services/ai_chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Use Firebase Emulator in debug mode (local development).
  // Skipped on web so `flutter run -d chrome` targets the production project
  // instead of requiring a locally running emulator.
  if (kDebugMode && !kIsWeb) {
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

  // Push notifications and scheduled local notifications depend on mobile-only
  // plugins (firebase_messaging / flutter_local_notifications) that are not
  // supported on web and throw during initialization. Guarding with kIsWeb
  // keeps main() from crashing before runApp on web builds.
  if (!kIsWeb) {
    // Initialize timezone for scheduled notifications
    PushNotificationService.initializeTimezone();

    // Initialize push notifications
    final pushService = sl.get<PushNotificationService>();
    await pushService.initialize();
  }

  // Load the persisted theme preference before first paint so there is no
  // flash of the wrong theme.
  final themeMode = await ThemeProvider.loadSavedMode();

  runApp(MyApp(initialThemeMode: themeMode));
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

class MyApp extends StatelessWidget {
  final ThemeMode initialThemeMode;

  const MyApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ThemeProvider(initialMode: initialThemeMode)),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
            create: (_) => AuthProvider(
                  authService: sl.get<AuthService>(),
                  analyticsService: sl.get<AnalyticsService>(),
                )),
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
                  reportService: sl.get<ShopReportService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => SubscriptionProvider(
                  subscriptionService: sl.get<ShopSubscriptionService>(),
                )),
        ChangeNotifierProvider(
            create: (_) => UserSubscriptionProvider(
                  service: sl.get<UserSubscriptionService>(),
                  revenueCatService: sl.get<RevenueCatService>(),
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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'クルマ統合管理',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // Enable drag-to-scroll with mouse/trackpad on web & desktop.
          scrollBehavior: const AppScrollBehavior(),
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Routes to Home, Login, or Onboarding based on auth + first-launch state.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final done = await hasCompletedOnboarding();
    if (mounted) {
      setState(() => _onboardingDone = done);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still loading onboarding flag
    if (_onboardingDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Authenticated users always go to HomeScreen
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        // First-time visitors see onboarding. The callback swaps the screen
        // in place — navigating away would destroy this auth-listening route.
        if (!_onboardingDone!) {
          return OnboardingScreen(
            onCompleted: () => setState(() => _onboardingDone = true),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
