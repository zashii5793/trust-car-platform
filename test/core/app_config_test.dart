import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/config/app_config.dart';

void main() {
  setUp(() {
    AppConfig.instance.reset();
  });

  group('AppConfig', () {
    group('init', () {
      test('環境を設定できる', () {
        AppConfig.instance.init(environment: AppEnvironment.production);

        expect(AppConfig.instance.environment, AppEnvironment.production);
        expect(AppConfig.instance.isProduction, true);
        expect(AppConfig.instance.isDevelopment, false);
      });

      test('Feature Flagsを設定できる', () {
        AppConfig.instance.init(
          environment: AppEnvironment.production,
          featureFlags: {
            FeatureFlag.offlineMode: true,
            FeatureFlag.premiumFeatures: true,
          },
        );

        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.offlineMode), true);
        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.premiumFeatures), true);
      });

      test('設定値を設定できる', () {
        AppConfig.instance.init(
          environment: AppEnvironment.development,
          settings: {
            'maxVehicles': 10,
            'apiTimeout': 30000,
          },
        );

        expect(AppConfig.instance.getSetting<int>('maxVehicles'), 10);
        expect(AppConfig.instance.getSetting<int>('apiTimeout'), 30000);
      });
    });

    group('isFeatureEnabled', () {
      test('デフォルトで有効なFeature Flagを確認', () {
        AppConfig.instance.init(environment: AppEnvironment.production);

        // デフォルトで有効なもの
        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.darkMode), true);
        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.pushNotifications), true);
        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.aiRecommendations), true);

        // デフォルトで無効なもの
        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.offlineMode), false);
        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.premiumFeatures), false);
      });
    });

    group('setFeatureFlag', () {
      test('Feature Flagを動的に変更できる', () {
        AppConfig.instance.init(environment: AppEnvironment.production);

        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.offlineMode), false);

        AppConfig.instance.setFeatureFlag(FeatureFlag.offlineMode, true);

        expect(AppConfig.instance.isFeatureEnabled(FeatureFlag.offlineMode), true);
      });
    });

    group('getSettingOrDefault', () {
      test('未設定の場合デフォルト値を返す', () {
        AppConfig.instance.init(environment: AppEnvironment.development);

        expect(
          AppConfig.instance.getSettingOrDefault<int>('unknownKey', 99),
          99,
        );
      });

      test('設定済みの場合その値を返す', () {
        AppConfig.instance.init(
          environment: AppEnvironment.development,
          settings: {'myKey': 42},
        );

        expect(
          AppConfig.instance.getSettingOrDefault<int>('myKey', 99),
          42,
        );
      });
    });

    group('environment-specific values', () {
      test('開発環境のAPIベースURL', () {
        AppConfig.instance.init(environment: AppEnvironment.development);
        expect(AppConfig.instance.apiBaseUrl, contains('dev'));
      });

      test('ステージング環境のAPIベースURL', () {
        AppConfig.instance.init(environment: AppEnvironment.staging);
        expect(AppConfig.instance.apiBaseUrl, contains('staging'));
      });

      test('本番環境のAPIベースURL', () {
        AppConfig.instance.init(environment: AppEnvironment.production);
        expect(AppConfig.instance.apiBaseUrl, isNot(contains('dev')));
        expect(AppConfig.instance.apiBaseUrl, isNot(contains('staging')));
      });
    });

    group('toDebugMap', () {
      test('デバッグ情報をMap形式で取得できる', () {
        AppConfig.instance.init(
          environment: AppEnvironment.development,
          settings: {'testKey': 'testValue'},
        );

        final debugMap = AppConfig.instance.toDebugMap();

        expect(debugMap['environment'], 'development');
        expect(debugMap['featureFlags'], isA<Map>());
        expect(debugMap['settings'], {'testKey': 'testValue'});
      });
    });

    group('shortcuts', () {
      test('appConfigショートカットが動作する', () {
        AppConfig.instance.init(environment: AppEnvironment.development);

        expect(appConfig, same(AppConfig.instance));
      });

      test('isFeatureEnabledショートカットが動作する', () {
        AppConfig.instance.init(environment: AppEnvironment.development);

        expect(
          isFeatureEnabled(FeatureFlag.darkMode),
          appConfig.isFeatureEnabled(FeatureFlag.darkMode),
        );
      });
    });
  });
}
