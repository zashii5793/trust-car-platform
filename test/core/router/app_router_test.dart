import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/router/app_router.dart';

/// Pure-function tests for the routing guard.
///
/// [resolveRedirect] holds all of the auth/onboarding gating logic that used
/// to live inside the imperative `AuthWrapper`. Testing it as a pure function
/// keeps the risky branching deterministic and independent of widgets.
void main() {
  group('resolveRedirect', () {
    group('loading', () {
      test('redirects to splash while resolving', () {
        expect(
          resolveRedirect(
            isLoading: true,
            isAuthenticated: false,
            onboardingCompleted: true,
            location: AppRoutes.login,
          ),
          AppRoutes.splash,
        );
      });

      test('stays on splash while still loading', () {
        expect(
          resolveRedirect(
            isLoading: true,
            isAuthenticated: false,
            onboardingCompleted: true,
            location: AppRoutes.splash,
          ),
          isNull,
        );
      });
    });

    group('unauthenticated', () {
      test('first-time user goes to onboarding', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: false,
            onboardingCompleted: false,
            location: AppRoutes.home,
          ),
          AppRoutes.onboarding,
        );
      });

      test('stays on onboarding while in progress', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: false,
            onboardingCompleted: false,
            location: AppRoutes.onboarding,
          ),
          isNull,
        );
      });

      test('returning user goes to login', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: false,
            onboardingCompleted: true,
            location: AppRoutes.home,
          ),
          AppRoutes.login,
        );
      });

      test('stays on login', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: false,
            onboardingCompleted: true,
            location: AppRoutes.login,
          ),
          isNull,
        );
      });

      test('allows the signup screen', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: false,
            onboardingCompleted: true,
            location: AppRoutes.signup,
          ),
          isNull,
        );
      });
    });

    group('authenticated', () {
      test('redirected away from login to home', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: true,
            onboardingCompleted: true,
            location: AppRoutes.login,
          ),
          AppRoutes.home,
        );
      });

      test('redirected away from onboarding to home', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: true,
            onboardingCompleted: true,
            location: AppRoutes.onboarding,
          ),
          AppRoutes.home,
        );
      });

      test('redirected away from splash to home', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: true,
            onboardingCompleted: true,
            location: AppRoutes.splash,
          ),
          AppRoutes.home,
        );
      });

      test('stays on home', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: true,
            onboardingCompleted: true,
            location: AppRoutes.home,
          ),
          isNull,
        );
      });
    });

    group('Edge Cases', () {
      test('loading wins even when authenticated', () {
        expect(
          resolveRedirect(
            isLoading: true,
            isAuthenticated: true,
            onboardingCompleted: true,
            location: AppRoutes.home,
          ),
          AppRoutes.splash,
        );
      });

      test('authed user with incomplete onboarding goes home', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: true,
            onboardingCompleted: false,
            location: AppRoutes.splash,
          ),
          AppRoutes.home,
        );
      });

      test('unknown path for returning user falls back to login', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: false,
            onboardingCompleted: true,
            location: '/some/unknown/path',
          ),
          AppRoutes.login,
        );
      });

      test('unknown path for authed user is allowed', () {
        expect(
          resolveRedirect(
            isLoading: false,
            isAuthenticated: true,
            onboardingCompleted: true,
            location: '/some/unknown/path',
          ),
          isNull,
        );
      });
    });
  });
}
