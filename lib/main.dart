import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
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
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'core/theme/app_theme.dart';
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
    // Storage emulator so local image uploads (inquiry photos, accessory
    // showcases, etc.) work end-to-end against the emulator suite.
    FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
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

  runApp(const MyApp());
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
      child: MaterialApp(
        title: 'クルマ統合管理',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // コンセプト「信頼を設計する」に基づき、明るいDeep Blue基調を既定とする。
        // 以前は ThemeMode.system だったため、OS のダーク設定で黒基調が
        // 適用され、ブランドイメージ（落ち着いた青）と乖離していた。
        themeMode: ThemeMode.light,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
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
