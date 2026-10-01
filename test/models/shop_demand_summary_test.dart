// 非提携の店に溜まっている「問い合わせ希望」の内訳。
//
// `shop_inquiry_demands` はフリーミアムのゲートが入ったときから溜まって
// いて、`getDemandsForShop` も実装済みだった。しかし **それを呼ぶ画面が
// 1つも無く**、店には件数しか出ていなかった（2026-09-22 実測）。
//
// 件数だけでは、登録する価値があるか判断できない。
// 「先月は見積もり依頼が4件、修理の相談が2件」なら判断できる。
//
// **本文は入れない。** 書いた人のものであり、同時に登録する理由でもある。
// 無料で渡すと理由が消える。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/shop_demand_summary.dart';
import 'package:trust_car_platform/models/shop_inquiry_demand.dart';

ShopInquiryDemand _d(
  InquiryType type,
  DateTime at, {
  String id = 'd',
}) =>
    ShopInquiryDemand(
      id: id,
      shopId: 'shop_1',
      shopOwnerId: 'owner_1',
      userId: 'user_1',
      type: type,
      subject: '件名',
      createdAt: at,
    );

void main() {
  group('ShopDemandSummary.from', () {
    test('種別ごとに数える', () {
      final s = ShopDemandSummary.from([
        _d(InquiryType.estimate, DateTime(2026, 9, 1)),
        _d(InquiryType.estimate, DateTime(2026, 9, 5)),
        _d(InquiryType.serviceInquiry, DateTime(2026, 9, 10)),
      ]);

      expect(s.total, 3);
      expect(s.byType[InquiryType.estimate], 2);
      expect(s.byType[InquiryType.serviceInquiry], 1);
    });

    test('多い種別が先に来る', () {
      final s = ShopDemandSummary.from([
        _d(InquiryType.serviceInquiry, DateTime(2026, 9, 1)),
        _d(InquiryType.estimate, DateTime(2026, 9, 2)),
        _d(InquiryType.estimate, DateTime(2026, 9, 3)),
      ]);

      expect(s.typesByCount.first, InquiryType.estimate);
    });

    test('いちばん新しい日と古い日が出る', () {
      final s = ShopDemandSummary.from([
        _d(InquiryType.estimate, DateTime(2026, 9, 5)),
        _d(InquiryType.estimate, DateTime(2026, 7, 1)),
        _d(InquiryType.estimate, DateTime(2026, 8, 3)),
      ]);

      expect(s.newestAt, DateTime(2026, 9, 5));
      expect(s.oldestAt, DateTime(2026, 7, 1));
    });

    test('直近30日の件数を数えられる', () {
      final now = DateTime(2026, 9, 22);
      final demands = [
        _d(InquiryType.estimate, DateTime(2026, 9, 20)),
        _d(InquiryType.estimate, DateTime(2026, 9, 1)),
        _d(InquiryType.estimate, DateTime(2026, 5, 1)),
      ];
      final s = ShopDemandSummary.from(demands);

      expect(s.recentCount(demands, now: now), 2);
    });

    group('Edge Cases', () {
      test('空なら isEmpty', () {
        final s = ShopDemandSummary.from(const []);

        expect(s.isEmpty, isTrue);
        expect(s.total, 0);
        expect(s.typesByCount, isEmpty);
        expect(s.newestAt, isNull);
      });

      test('1件だけなら新旧が同じ日', () {
        final s = ShopDemandSummary.from([
          _d(InquiryType.general, DateTime(2026, 9, 5)),
        ]);

        expect(s.newestAt, s.oldestAt);
      });

      test('同数の種別は enum の順で安定する（並びが毎回変わらない）', () {
        final s = ShopDemandSummary.from([
          _d(InquiryType.appointment, DateTime(2026, 9, 1)),
          _d(InquiryType.estimate, DateTime(2026, 9, 2)),
        ]);

        // estimate(2) が appointment(3) より前。
        expect(s.typesByCount, [InquiryType.estimate, InquiryType.appointment]);
      });
    });
  });
}
