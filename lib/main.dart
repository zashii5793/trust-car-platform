import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/di/injection.dart';
import 'core/di/service_locator.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/recommendation_service.dart';
import 'services/push_notification_service.dart';
import 'providers/vehicle_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/connectivity_provider.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence with 100MB cache limit
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024, // 100MB
  );

  await Injection.init();

  // Initialize timezone for scheduled notifications
  PushNotificationService.initializeTimezone();

  // Initialize push notifications
  final pushService = sl.get<PushNotificationService>();
  await pushService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(
          authService: sl.get<AuthService>(),
        )),
        ChangeNotifierProvider(create: (_) => VehicleProvider(
          firebaseService: sl.get<FirebaseService>(),
        )),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider(
          firebaseService: sl.get<FirebaseService>(),
        )),
        ChangeNotifierProvider(create: (_) => NotificationProvider(
          firebaseService: sl.get<FirebaseService>(),
          recommendationService: sl.get<RecommendationService>(),
        )),
      ],
      child: MaterialApp(
        title: 'クルマ統合管理',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// 認証状態に応じて画面を切り替えるラッパー
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 初期化中はローディング表示
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 認証済みならホーム画面、未認証ならログイン画面
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
