import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/config/app_config.dart';
import 'package:trust_car_platform/core/utils/premium_upsell.dart';

/// プレミアムの案内文。
///
/// **凍結中に「アップグレードしてください」と書くと、買えないものを勧める
/// ことになる。** 2026-09-05 まで、購入導線は生きているのに価格が1円も
/// 表示されず、RevenueCat にも商品が無い状態だった。
void main() {
  tearDown(() =>
      AppConfig.instance.setFeatureFlag(FeatureFlag.premiumFeatures, false));

  group('canPurchasePremium', () {
    test('既定は凍結', () {
      expect(canPurchasePremium, isFalse);
    });

    test('フラグを立てると買える', () {
      AppConfig.instance.setFeatureFlag(FeatureFlag.premiumFeatures, true);

      expect(canPurchasePremium, isTrue);
    });
  });

  group('premiumUpsellMessage', () {
    test('凍結中はアップグレードを勧めない', () {
      final message = premiumUpsellMessage('PDF出力');

      expect(message, contains('PDF出力'));
      expect(message, contains('準備中'));
      expect(message, isNot(contains('アップグレード')));
    });

    test('買えるときはアップグレードを案内する', () {
      AppConfig.instance.setFeatureFlag(FeatureFlag.premiumFeatures, true);

      final message = premiumUpsellMessage('PDF出力');

      expect(message, contains('PDF出力'));
      expect(message, contains('アップグレード'));
      expect(message, isNot(contains('準備中')));
    });
  });

  group('Edge Cases', () {
    test('機能名が空でも文として壊れない', () {
      final message = premiumUpsellMessage('');

      expect(message, contains('プレミアムプラン'));
      expect(message.trim(), isNotEmpty);
    });
  });
}
