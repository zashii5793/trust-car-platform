import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/providers/shop_plan_request_provider.dart';
import 'package:trust_car_platform/services/shop_plan_request_service.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late ShopPlanRequestProvider provider;

  setUp(() {
    fs = FakeFirebaseFirestore();
    provider = ShopPlanRequestProvider(
      service: ShopPlanRequestService(firestore: fs),
    );
  });

  Future<bool> submit({
    ShopPlanType plan = ShopPlanType.standard,
    String email = 'shop@example.com',
  }) =>
      provider.submit(
        shopId: 'shop1',
        requesterUid: 'owner1',
        plan: plan,
        currentPlan: ShopPlanType.free,
        contactEmail: email,
        billingName: 'タカヤモーター',
      );

  test('申し込むと受付中の申し込みとして持つ', () async {
    expect(provider.pending, isNull);
    final ok = await submit(plan: ShopPlanType.premium);
    expect(ok, isTrue);
    expect(provider.pending?.plan, ShopPlanType.premium);
    expect(provider.isSubmitting, isFalse);
    expect(provider.error, isNull);
  });

  test('loadPending で Firestore の受付中の申し込みを読む', () async {
    await ShopPlanRequestService(firestore: fs).submit(
      shopId: 'shop1',
      requesterUid: 'owner1',
      plan: ShopPlanType.enterprise,
      currentPlan: ShopPlanType.free,
      contactEmail: 'shop@example.com',
      billingName: 'タカヤモーター',
    );
    await provider.loadPending('shop1');
    expect(provider.pending?.isQuote, isTrue);
  });

  group('Edge Cases', () {
    test('入力が不正なら false を返し、エラーを持つ', () async {
      final ok = await submit(email: 'bad');
      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.pending, isNull);
    });

    test('店IDが空なら loadPending は何もしない', () async {
      await provider.loadPending('');
      expect(provider.pending, isNull);
      expect(provider.error, isNull);
    });

    test('別の店を読み込むと、前の店の申し込みは消える', () async {
      await submit();
      expect(provider.pending, isNotNull);
      await provider.loadPending('shop2');
      expect(provider.pending, isNull);
    });
  });
}
