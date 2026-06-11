import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/analytics_service.dart';

// Tests verify that AnalyticsService methods are callable without throwing.
// Real Firebase Analytics calls are no-ops in test environments.
void main() {
  late AnalyticsService sut;

  setUp(() {
    sut = AnalyticsService.forTesting();
  });

  group('AnalyticsService', () {
    group('user events', () {
      test('trackLogin does not throw', () async {
        await expectLater(sut.trackLogin('email'), completes);
      });

      test('trackLogin with google method does not throw', () async {
        await expectLater(sut.trackLogin('google'), completes);
      });

      test('trackSignup does not throw', () async {
        await expectLater(sut.trackSignup('email'), completes);
      });

      test('setUserId with uid does not throw', () async {
        await expectLater(sut.setUserId('user_123'), completes);
      });

      test('setUserId with null does not throw', () async {
        await expectLater(sut.setUserId(null), completes);
      });
    });

    group('vehicle events', () {
      test('trackVehicleAdded does not throw', () async {
        await expectLater(sut.trackVehicleAdded(), completes);
      });

      test('trackVehicleOcrUsed does not throw', () async {
        await expectLater(sut.trackVehicleOcrUsed(), completes);
      });
    });

    group('maintenance events', () {
      test('trackMaintenanceRecorded with oil type does not throw', () async {
        await expectLater(sut.trackMaintenanceRecorded('oil'), completes);
      });

      test('trackMaintenanceRecorded with tire type does not throw', () async {
        await expectLater(sut.trackMaintenanceRecorded('tire'), completes);
      });

      test('trackDriveLogged does not throw', () async {
        await expectLater(sut.trackDriveLogged(42.5), completes);
      });

      group('Edge Cases', () {
        test('trackDriveLogged with zero distance', () async {
          await expectLater(sut.trackDriveLogged(0.0), completes);
        });

        test('trackDriveLogged with large distance', () async {
          await expectLater(sut.trackDriveLogged(9999.99), completes);
        });

        test('trackMaintenanceRecorded with empty string', () async {
          await expectLater(sut.trackMaintenanceRecorded(''), completes);
        });
      });
    });

    group('AI recommendation events', () {
      test('trackRecommendationViewed does not throw', () async {
        await expectLater(
            sut.trackRecommendationViewed('oil_change'), completes);
      });

      test('trackRecommendationActioned does not throw', () async {
        await expectLater(sut.trackRecommendationActioned(), completes);
      });
    });

    group('shop events', () {
      test('trackShopViewed does not throw', () async {
        await expectLater(sut.trackShopViewed('shop_abc'), completes);
      });

      test('trackInquirySent does not throw', () async {
        await expectLater(sut.trackInquirySent('shop_abc'), completes);
      });

      group('Edge Cases', () {
        test('trackShopViewed with empty id', () async {
          await expectLater(sut.trackShopViewed(''), completes);
        });
      });
    });

    group('screen view events', () {
      test('trackScreenView does not throw', () async {
        await expectLater(sut.trackScreenView('HomeScreen'), completes);
      });

      group('Edge Cases', () {
        test('trackScreenView with empty name', () async {
          await expectLater(sut.trackScreenView(''), completes);
        });
      });
    });
  });
}
