// 店舗プランの申し込み（請求書払い）のテスト。
//
// 2026-09-29: 店舗プランは当面、請求書払い（銀行振込）。アプリは
// `shops/{shopId}/plan_requests` に申し込みを置くだけで、プランの切り替えは
// 運営者がサーバ側で行う。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/shop_plan_request.dart';
import 'package:trust_car_platform/services/shop_plan_request_service.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late ShopPlanRequestService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopPlanRequestService(firestore: fs);
  });

  Future<ShopPlanRequest?> submit({
    String shopId = 'shop1',
    String requesterUid = 'owner1',
    ShopPlanType plan = ShopPlanType.standard,
    ShopPlanType currentPlan = ShopPlanType.free,
    String contactEmail = 'shop@example.com',
    String billingName = '株式会社タカヤモーター',
    String? note,
  }) async {
    final r = await service.submit(
      shopId: shopId,
      requesterUid: requesterUid,
      plan: plan,
      currentPlan: currentPlan,
      contactEmail: contactEmail,
      billingName: billingName,
      note: note,
    );
    return r.valueOrNull;
  }

  group('submit', () {
    test('申し込みを shops/{shopId}/plan_requests に pending で置く', () async {
      final req = await submit(note: '来月からお願いします');

      expect(req, isNotNull);
      final docs = await fs.collection('shops/shop1/plan_requests').get();
      expect(docs.docs, hasLength(1));
      final d = docs.docs.single.data();
      expect(d['plan'], 'standard');
      expect(d['currentPlan'], 'free');
      expect(d['requesterUid'], 'owner1');
      expect(d['contactEmail'], 'shop@example.com');
      expect(d['billingName'], '株式会社タカヤモーター');
      expect(d['note'], '来月からお願いします');
      expect(d['status'], 'pending');
      expect(d['createdAt'], isA<Timestamp>());

      expect(req!.id, docs.docs.single.id);
      expect(req.shopId, 'shop1');
      expect(req.status, ShopPlanRequestStatus.pending);
    });

    test('店のドキュメント（planType・subscriptionStatus）には触らない', () async {
      await fs.collection('shops').doc('shop1').set({
        'planType': 'free',
        'subscriptionStatus': 'free',
      });

      await submit(plan: ShopPlanType.premium);

      final shop = await fs.collection('shops').doc('shop1').get();
      expect(shop.data()!['planType'], 'free');
      expect(shop.data()!['subscriptionStatus'], 'free');
    });

    test('エンタープライズは見積もりの相談として同じ形で受ける', () async {
      final req = await submit(plan: ShopPlanType.enterprise);
      expect(req, isNotNull);
      expect(req!.plan, ShopPlanType.enterprise);
      expect(req.isQuote, isTrue);
    });

    test('ダウングレード（フリーへの変更）も申し込みとして受ける', () async {
      final req = await submit(
        plan: ShopPlanType.free,
        currentPlan: ShopPlanType.standard,
      );
      expect(req, isNotNull);
      expect(req!.isQuote, isFalse);
    });

    test('前後の空白は落として保存する', () async {
      await submit(
        contactEmail: '  shop@example.com ',
        billingName: '  タカヤモーター  ',
        note: '  ',
      );
      final d = (await fs.collection('shops/shop1/plan_requests').get())
          .docs
          .single
          .data();
      expect(d['contactEmail'], 'shop@example.com');
      expect(d['billingName'], 'タカヤモーター');
      // 空のご要望は項目ごと書かない
      expect(d.containsKey('note'), isFalse);
    });
  });

  group('latestPending', () {
    test('受付中の申し込みのうち、いちばん新しいものを返す', () async {
      final col = fs.collection('shops/shop1/plan_requests');
      await col.add({
        'plan': 'standard',
        'currentPlan': 'free',
        'requesterUid': 'owner1',
        'contactEmail': 'a@example.com',
        'billingName': 'A',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });
      await col.add({
        'plan': 'premium',
        'currentPlan': 'free',
        'requesterUid': 'owner1',
        'contactEmail': 'a@example.com',
        'billingName': 'A',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 20)),
      });
      await col.add({
        'plan': 'enterprise',
        'currentPlan': 'free',
        'requesterUid': 'owner1',
        'contactEmail': 'a@example.com',
        'billingName': 'A',
        // 運営者が処理を終えたものは出さない
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 25)),
      });

      final r = await service.latestPending('shop1');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.plan, ShopPlanType.premium);
    });

    test('申し込みが無ければ null', () async {
      final r = await service.latestPending('shop1');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, isNull);
    });
  });

  group('Edge Cases', () {
    test('店IDが空なら書かずに validation エラー', () async {
      final r = await service.submit(
        shopId: '',
        requesterUid: 'owner1',
        plan: ShopPlanType.standard,
        currentPlan: ShopPlanType.free,
        contactEmail: 'shop@example.com',
        billingName: 'A',
      );
      expect(r.errorOrNull, isA<ValidationError>());
    });

    test('申込者が空なら validation エラー', () async {
      final r = await service.submit(
        shopId: 'shop1',
        requesterUid: '',
        plan: ShopPlanType.standard,
        currentPlan: ShopPlanType.free,
        contactEmail: 'shop@example.com',
        billingName: 'A',
      );
      expect(r.errorOrNull, isA<ValidationError>());
      expect((await fs.collection('shops/shop1/plan_requests').get()).docs,
          isEmpty);
    });

    test('いまと同じプランは申し込めない', () async {
      final r = await service.submit(
        shopId: 'shop1',
        requesterUid: 'owner1',
        plan: ShopPlanType.standard,
        currentPlan: ShopPlanType.standard,
        contactEmail: 'shop@example.com',
        billingName: 'A',
      );
      expect(r.errorOrNull, isA<ValidationError>());
    });

    for (final bad in ['', '   ', 'shop', 'shop@', '@example.com', 'a b@c.d']) {
      test('メールアドレスが不正（"$bad"）なら validation エラー', () async {
        final r = await service.submit(
          shopId: 'shop1',
          requesterUid: 'owner1',
          plan: ShopPlanType.standard,
          currentPlan: ShopPlanType.free,
          contactEmail: bad,
          billingName: 'A',
        );
        final err = r.errorOrNull;
        expect(err, isA<ValidationError>());
        expect((err as ValidationError).field, 'contactEmail');
      });
    }

    test('請求書の宛名が空なら validation エラー', () async {
      final r = await service.submit(
        shopId: 'shop1',
        requesterUid: 'owner1',
        plan: ShopPlanType.standard,
        currentPlan: ShopPlanType.free,
        contactEmail: 'shop@example.com',
        billingName: '  ',
      );
      final err = r.errorOrNull;
      expect(err, isA<ValidationError>());
      expect((err as ValidationError).field, 'billingName');
    });

    test('宛名は100文字まで（境界値）', () async {
      expect(await submit(billingName: 'あ' * 100), isNotNull);
      expect(await submit(billingName: 'あ' * 101), isNull);
    });

    test('ご要望は1000文字まで（境界値）', () async {
      expect(await submit(note: 'あ' * 1000), isNotNull);
      expect(await submit(note: 'あ' * 1001), isNull);
    });

    test('latestPending: 店IDが空なら validation エラー', () async {
      final r = await service.latestPending('');
      expect(r.errorOrNull, isA<ValidationError>());
    });

    test('latestPending: 知らないプラン名・状態が入っていても落ちない', () async {
      await fs.collection('shops/shop1/plan_requests').add({
        'plan': 'future_plan',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });
      final r = await service.latestPending('shop1');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.plan, ShopPlanType.free);
    });

    test('ShopPlanRequestStatus.fromString: 知らない値は pending 扱いにしない', () {
      expect(ShopPlanRequestStatus.fromString('pending'),
          ShopPlanRequestStatus.pending);
      expect(ShopPlanRequestStatus.fromString('completed'),
          ShopPlanRequestStatus.completed);
      expect(ShopPlanRequestStatus.fromString(null),
          ShopPlanRequestStatus.unknown);
      expect(ShopPlanRequestStatus.fromString('xxx'),
          ShopPlanRequestStatus.unknown);
    });
  });
}
