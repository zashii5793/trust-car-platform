import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/home_screen.dart';

/// Centralised route table for the app.
///
/// Replaces scattered `Navigator.push(MaterialPageRoute(...))` for the
/// top-level auth shell with a single [GoRouter] configuration. Deep,
/// argument-carrying navigation inside feature screens continues to use the
/// root [Navigator] and is migrated incrementally.
class AppRoutes {
  AppRoutes._();

  /// Transient splash shown while the auth state is being restored.
  static const String splash = '/splash';

  /// First-launch product tour.
  static const String onboarding = '/onboarding';

  /// Email / Google sign-in.
  static const String login = '/login';

  /// New account registration.
  static const String signup = '/signup';

  /// Authenticated home (5-tab shell).
  static const String home = '/';
}

/// Pure routing guard.
///
/// Given the current auth + onboarding state and the requested [location],
/// returns the path to redirect to, or `null` to allow the navigation.
///
/// Kept side-effect free so the gating logic can be unit-tested without a
/// widget harness.
String? resolveRedirect({
  required bool isLoading,
  required bool isAuthenticated,
  required bool onboardingCompleted,
  required String location,
}) {
  // Hold on the splash until the auth state has been resolved, otherwise a
  // brief "unauthenticated" flash would bounce the user to login.
  if (isLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final bool atAuth =
      location == AppRoutes.login || location == AppRoutes.signup;
  final bool atOnboarding = location == AppRoutes.onboarding;

  if (!isAuthenticated) {
    if (!onboardingCompleted) {
      return atOnboarding ? null : AppRoutes.onboarding;
    }
    return atAuth ? null : AppRoutes.login;
  }

  // Authenticated: keep the user out of the pre-auth funnel.
  if (atAuth || atOnboarding || location == AppRoutes.splash) {
    return AppRoutes.home;
  }
  return null;
}

/// Builds the application [GoRouter].
///
/// [authProvider] drives auth-based redirects; [onboardingCompleted] is a
/// notifier flipped to `true` when the onboarding flow finishes so the router
/// can leave the onboarding route. Both are listened to via
/// [GoRouter.refreshListenable] so redirects re-run on state changes.
GoRouter createAppRouter({
  required AuthProvider authProvider,
  required ValueNotifier<bool> onboardingCompleted,
}) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: Listenable.merge([authProvider, onboardingCompleted]),
    redirect: (context, state) => resolveRedirect(
      isLoading: authProvider.isLoading,
      isAuthenticated: authProvider.isAuthenticated,
      onboardingCompleted: onboardingCompleted.value,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          // Flipping the notifier triggers the redirect to the login screen.
          onCompleted: () => onboardingCompleted.value = true,
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}

/// Minimal splash shown while the auth state is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
