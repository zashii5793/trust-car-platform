// Issue #41 Phase 2 — ShopDemandService TDD Tests
//
// RED→GREEN: 提携フリーミアム質問ゲートの需要蓄積ロジック
//   1. recordDemand — 正常系（非提携店への質問を需要として記録）
//   2. getDemandCountForShop — 件数取得
//   3. getDemandsForShop — 一覧取得（店舗オーナー向け）
//   4. Shop.isPartner — 算出ゲッター
//   5. Edge Cases

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/services/shop_demand_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 's1',
  ShopSubscriptionStatus status = ShopSubscriptionStatus.free,
  ShopPlanType plan = ShopPlanType.free,
  String? ownerId,
}) {
  return Shop(
    id: id,
    name: 'テスト工場',
    type: ShopType.maintenanceShop,
    subscriptionStatus: status,
    planType: plan,
    ownerId: ownerId ?? 'owner1',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

Future<void> _seedDemand(
  FakeFirebaseFirestore fakeFs, {
  required String shopId,
  required String userId,
  String? shopOwnerId,
  String subject = 'タイヤ交換の見積もりが欲しい',
  InquiryType type = InquiryType.estimate,
}) async {
  await fakeFs.collection('shop_inquiry_demands').add({
    'shopId': shopId,
    'shopOwnerId': shopOwnerId ?? 'owner1',
    'userId': userId,
    'type': type.name,
    'subject': subject,
    'message': null,
    'vehicleId': null,
    'createdAt': Timestamp.fromDate(DateTime(2026, 7, 10)),
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFs;
  late ShopDemandService sut;

  setUp(() {
    fakeFs = FakeFirebaseFirestore();
    sut = ShopDemandService(firestore: fakeFs);
  });

  // -------------------------------------------------------------------------
  // 1. recordDemand
  // -------------------------------------------------------------------------
  group('recordDemand', () {
    test('正常系: 非提携店への質問を需要として記録する', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: 'owner1',
        userId: 'user1',
        type: InquiryType.estimate,
        subject: 'タイヤ交換の見積もりが欲しい',
      );

      expect(result.isSuccess, isTrue);
      final demand = result.valueOrNull!;
      expect(demand.shopId, 's1');
      expect(demand.userId, 'user1');
      expect(demand.shopOwnerId, 'owner1');
      expect(demand.subject, 'タイヤ交換の見積もりが欲しい');
      expect(demand.type, InquiryType.estimate);
      expect(demand.id, isNotEmpty);
    });

    test('message を含む需要を記録できる', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: 'owner1',
        userId: 'user1',
        type: InquiryType.serviceInquiry,
        subject: 'オイル交換について',
        message: '5W-30を使用したいのですが対応していますか？',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.message, '5W-30を使用したいのですが対応していますか？');
    });

    test('vehicleId 付きで記録できる', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: 'owner1',
        userId: 'user1',
        type: InquiryType.estimate,
        subject: 'ブレーキパッド交換',
        vehicleId: 'v1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.vehicleId, 'v1');
    });

    test('Firestore に保存されドキュメントIDが返る', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: 'owner1',
        userId: 'user1',
        type: InquiryType.general,
        subject: '営業時間を教えてください',
      );

      expect(result.isSuccess, isTrue);
      final demand = result.valueOrNull!;
      // ID はランダムに生成されるので空でないことを確認
      expect(demand.id, isNotEmpty);
      // Firestore に実際に書き込まれているか確認
      final snapshot =
          await fakeFs.collection('shop_inquiry_demands').doc(demand.id).get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['shopId'], 's1');
    });
  });

  // -------------------------------------------------------------------------
  // 2. getDemandCountForShop
  // -------------------------------------------------------------------------
  group('getDemandCountForShop', () {
    test('指定 shopId の需要件数を返す', () async {
      await _seedDemand(fakeFs, shopId: 's1', userId: 'u1');
      await _seedDemand(fakeFs, shopId: 's1', userId: 'u2');
      await _seedDemand(fakeFs, shopId: 's1', userId: 'u3');
      await _seedDemand(fakeFs, shopId: 's2', userId: 'u4'); // 別の店舗

      final result = await sut.getDemandCountForShop('s1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 3);
    });

    test('需要が0件の場合 0 を返す', () async {
      final result = await sut.getDemandCountForShop('s_no_demand');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 0);
    });

    test('他店舗の需要はカウントしない', () async {
      await _seedDemand(fakeFs, shopId: 's2', userId: 'u1');
      await _seedDemand(fakeFs, shopId: 's2', userId: 'u2');

      final result = await sut.getDemandCountForShop('s1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 0);
    });
  });

  // -------------------------------------------------------------------------
  // 3. getDemandsForShop
  // -------------------------------------------------------------------------
  group('getDemandsForShop', () {
    test('shopId に紐づく需要一覧を返す', () async {
      await _seedDemand(fakeFs, shopId: 's1', userId: 'u1', subject: '質問A');
      await _seedDemand(fakeFs, shopId: 's1', userId: 'u2', subject: '質問B');
      await _seedDemand(fakeFs, shopId: 's2', userId: 'u3', subject: '質問C');

      final result = await sut.getDemandsForShop('s1');

      expect(result.isSuccess, isTrue);
      final demands = result.valueOrNull!;
      expect(demands.length, 2);
      final subjects = demands.map((d) => d.subject).toSet();
      expect(subjects, containsAll(['質問A', '質問B']));
    });

    test('需要が0件の場合は空リストを返す', () async {
      final result = await sut.getDemandsForShop('s_empty');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Shop.isPartner
  // -------------------------------------------------------------------------
  group('Shop.isPartner', () {
    test('subscriptionStatus が active の場合 true', () {
      final shop = _makeShop(status: ShopSubscriptionStatus.active);
      expect(shop.isPartner, isTrue);
    });

    test('subscriptionStatus が trialing の場合 true', () {
      final shop = _makeShop(status: ShopSubscriptionStatus.trialing);
      expect(shop.isPartner, isTrue);
    });

    test('subscriptionStatus が free の場合 false', () {
      final shop = _makeShop(status: ShopSubscriptionStatus.free);
      expect(shop.isPartner, isFalse);
    });

    test('subscriptionStatus が expired の場合 false', () {
      final shop = _makeShop(status: ShopSubscriptionStatus.expired);
      expect(shop.isPartner, isFalse);
    });

    test('subscriptionStatus が cancelled の場合 false', () {
      final shop = _makeShop(status: ShopSubscriptionStatus.cancelled);
      expect(shop.isPartner, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('shopId が空文字の場合 failure を返す', () async {
      final result = await sut.recordDemand(
        shopId: '',
        shopOwnerId: 'owner1',
        userId: 'user1',
        type: InquiryType.general,
        subject: '質問',
      );

      expect(result.isFailure, isTrue);
    });

    test('userId が空文字の場合 failure を返す', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: 'owner1',
        userId: '',
        type: InquiryType.general,
        subject: '質問',
      );

      expect(result.isFailure, isTrue);
    });

    test('subject が空文字の場合 failure を返す', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: 'owner1',
        userId: 'user1',
        type: InquiryType.general,
        subject: '',
      );

      expect(result.isFailure, isTrue);
    });

    test('shopOwnerId が空文字の場合 failure を返す', () async {
      final result = await sut.recordDemand(
        shopId: 's1',
        shopOwnerId: '',
        userId: 'user1',
        type: InquiryType.general,
        subject: '質問',
      );

      expect(result.isFailure, isTrue);
    });

    test('getDemandCountForShop: 空 shopId は failure を返す', () async {
      final result = await sut.getDemandCountForShop('');
      expect(result.isFailure, isTrue);
    });
  });
}
