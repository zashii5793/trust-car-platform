import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/config/app_config.dart';
import 'package:trust_car_platform/services/feature_flag_service.dart';

class _FakeSource implements RemoteFlagSource {
  _FakeSource(this._data, {this.throwError = false});

  final Map<String, dynamic> _data;
  final bool throwError;

  @override
  Future<Map<String, dynamic>> fetch() async {
    if (throwError) throw Exception('remote fetch failed');
    return _data;
  }
}

void main() {
  late AppConfig config;

  setUp(() {
    AppConfig.instance.reset();
    config = AppConfig.instance;
  });

  tearDown(() => AppConfig.instance.reset());

  group('applyOverrides', () {
    test('既知キー=true でフラグが有効化される', () {
      // デフォルトは false（凍結中）
      expect(config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isFalse);

      final service = FeatureFlagService(config: config);
      final applied = service.applyOverrides({'c2c_parts_marketplace': true});

      expect(applied[FeatureFlag.c2cPartsMarketplace], isTrue);
      expect(config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isTrue);
    });

    test('既知キー=false でフラグが無効化される', () {
      config.setFeatureFlag(FeatureFlag.c2cPartsMarketplace, true);

      final service = FeatureFlagService(config: config);
      service.applyOverrides({'c2c_parts_marketplace': false});

      expect(config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isFalse);
    });

    group('Edge Cases', () {
      test('未知キーは無視される', () {
        final service = FeatureFlagService(config: config);
        final applied = service.applyOverrides({'unknown_flag': true});
        expect(applied, isEmpty);
      });

      test('空マップは何もしない', () {
        final service = FeatureFlagService(config: config);
        expect(service.applyOverrides(const {}), isEmpty);
      });

      test('文字列 "true"/"false" を真偽値に変換する', () {
        final service = FeatureFlagService(config: config);

        service.applyOverrides({'c2c_parts_marketplace': 'true'});
        expect(
            config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isTrue);

        service.applyOverrides({'c2c_parts_marketplace': 'false'});
        expect(
            config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isFalse);
      });

      test('数値 1/0 を真偽値に変換する', () {
        final service = FeatureFlagService(config: config);

        service.applyOverrides({'c2c_parts_marketplace': 1});
        expect(
            config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isTrue);

        service.applyOverrides({'c2c_parts_marketplace': 0});
        expect(
            config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isFalse);
      });

      test('変換不能な値は無視される', () {
        config.setFeatureFlag(FeatureFlag.c2cPartsMarketplace, true);
        final service = FeatureFlagService(config: config);

        final applied =
            service.applyOverrides({'c2c_parts_marketplace': 'maybe'});

        expect(applied, isEmpty);
        // 元の値が保持される
        expect(
            config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isTrue);
      });
    });
  });

  group('sync', () {
    test('リモートソースの値を適用する', () async {
      final service = FeatureFlagService(
        config: config,
        source: _FakeSource({'c2c_parts_marketplace': true}),
      );

      final applied = await service.sync();

      expect(applied[FeatureFlag.c2cPartsMarketplace], isTrue);
      expect(config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isTrue);
    });

    test('NoopRemoteFlagSource は何も変更しない', () async {
      final service = FeatureFlagService(config: config);
      final applied = await service.sync();
      expect(applied, isEmpty);
      expect(config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isFalse);
    });

    test('ソースが例外を投げてもフェイルセーフでデフォルト維持', () async {
      final service = FeatureFlagService(
        config: config,
        source: _FakeSource(const {}, throwError: true),
      );

      final applied = await service.sync();

      expect(applied, isEmpty);
      // 凍結デフォルトが維持される
      expect(config.isFeatureEnabled(FeatureFlag.c2cPartsMarketplace), isFalse);
    });
  });
}
