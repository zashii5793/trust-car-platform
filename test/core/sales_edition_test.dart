import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/config/app_config.dart';
import 'package:trust_car_platform/services/feature_flag_service.dart';

/// 販売版の構成（docs/FEATURE_SPEC.md「事業の芯」）。
///
/// 既定で出さないもの: 架空データのパーツ提案、凍結中の C2C、価格未定の
/// 個人課金の導線、本番に Functions が無い AI チャット。
/// 店舗プランのアプリ内課金も既定で出さない（2026-09-29。当面は請求書払い）。
/// 既定で出すもの: KPI を動かす機能（記録・期限・台帳まわり）。
void main() {
  final config = AppConfig.instance;

  test('既定で出さないもの', () {
    for (final f in [
      FeatureFlag.partRecommendations,
      FeatureFlag.c2cPartsMarketplace,
      FeatureFlag.premiumFeatures,
      FeatureFlag.aiChat,
      FeatureFlag.shopInAppPurchase,
    ]) {
      expect(config.isFeatureEnabled(f), isFalse, reason: f.name);
    }
  });

  test('既定で出すもの', () {
    for (final f in [
      FeatureFlag.pushNotifications,
      FeatureFlag.carInspectionReminders,
      FeatureFlag.maintenanceReminders,
      FeatureFlag.imageUpload,
      FeatureFlag.multiVehicle,
    ]) {
      expect(config.isFeatureEnabled(f), isTrue, reason: f.name);
    }
  });

  test('既定で出さないものは、アプリを出し直さずに Remote Config で開けられる', () {
    final remote = FeatureFlagService.remoteKeys.values.toSet();
    for (final f in [
      FeatureFlag.partRecommendations,
      FeatureFlag.c2cPartsMarketplace,
      FeatureFlag.premiumFeatures,
      FeatureFlag.aiChat,
      FeatureFlag.shopInAppPurchase,
    ]) {
      expect(remote, contains(f), reason: f.name);
    }
  });

  test('Remote Config で開けるフラグは、すべてテンプレートに false で載っている', () {
    final template = jsonDecode(
      File('remoteconfig.template.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final params = template['parameters'] as Map<String, dynamic>;
    for (final key in FeatureFlagService.remoteKeys.keys) {
      expect(params, contains(key), reason: key);
      final value = (params[key] as Map)['defaultValue'] as Map;
      expect(value['value'], 'false', reason: key);
    }
  });
}
