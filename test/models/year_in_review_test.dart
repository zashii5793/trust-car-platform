import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/year_in_review.dart';

/// 「あなたのクルマの1年」の集計。
///
/// 2026-08-25 の指摘「毎日までは不要でも、見たくなるような設計が必要」への
/// 最初の打ち手（`docs/HABIT_DESIGN.md` 打ち手2）。
///
/// 1年でユーザーは整備記録を数十件入れる。**溜めることには協力してもらって
/// いるのに、溜まった価値を突き返していない。** 履歴の一覧はあるが、自分から
/// 開かないと見えないし、開いても「記録が並んでいる」だけ。
///
/// ここは集計だけを持つ。画面も Firebase も要らない形にして、
/// **数え方が合っているかをテストで固定する。**
void main() {
  MaintenanceRecord rec({
    required DateTime date,
    required int cost,
    MaintenanceType type = MaintenanceType.oilChange,
    int? mileage,
    String? shop,
  }) {
    return MaintenanceRecord(
      id: 'r-${date.microsecondsSinceEpoch}-$cost',
      vehicleId: 'v1',
      userId: 'u1',
      type: type,
      title: type.displayName,
      cost: cost,
      date: date,
      mileageAtService: mileage,
      shopName: shop,
      createdAt: date,
    );
  }

  final now = DateTime(2026, 8, 25);
  final from = DateTime(2025, 8, 25);

  group('YearInReview.from', () {
    test('期間内の費用を合計する', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 10, 1), cost: 5000),
          rec(date: DateTime(2026, 3, 1), cost: 74000),
          rec(date: DateTime(2026, 7, 1), cost: 12000),
        ],
        from: from,
        to: now,
      );

      expect(review.totalCost, 91000);
      expect(review.recordCount, 3);
    });

    test('期間外の記録は数えない', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2024, 5, 1), cost: 100000), // 1年より前
          rec(date: DateTime(2026, 3, 1), cost: 5000),
        ],
        from: from,
        to: now,
      );

      expect(review.totalCost, 5000);
      expect(review.recordCount, 1);
    });

    test('いちばん高かった整備を拾う', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 10, 1), cost: 5000),
          rec(
            date: DateTime(2026, 3, 1),
            cost: 74000,
            type: MaintenanceType.legalInspection24,
          ),
        ],
        from: from,
        to: now,
      );

      expect(review.mostExpensive?.cost, 74000);
      expect(review.mostExpensive?.type, MaintenanceType.legalInspection24);
    });

    test('走行距離は期間内の記録の最大と最小の差', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 9, 1), cost: 5000, mileage: 30000),
          rec(date: DateTime(2026, 2, 1), cost: 5000, mileage: 36000),
          rec(date: DateTime(2026, 7, 1), cost: 5000, mileage: 42400),
        ],
        from: from,
        to: now,
      );

      expect(review.distanceKm, 12400);
    });

    test('種別ごとの費用を出す', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 10, 1), cost: 5000),
          rec(date: DateTime(2026, 1, 1), cost: 6000),
          rec(
            date: DateTime(2026, 3, 1),
            cost: 74000,
            type: MaintenanceType.legalInspection24,
          ),
        ],
        from: from,
        to: now,
      );

      expect(review.costByType[MaintenanceType.oilChange], 11000);
      expect(review.costByType[MaintenanceType.legalInspection24], 74000);
    });

    test('よく行った店を拾う', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 10, 1), cost: 5000, shop: 'タカヤモーター'),
          rec(date: DateTime(2026, 1, 1), cost: 6000, shop: 'タカヤモーター'),
          rec(date: DateTime(2026, 3, 1), cost: 74000, shop: 'ディーラー'),
        ],
        from: from,
        to: now,
      );

      // 金額ではなく回数で見る。「よく行った店」なので。
      expect(review.mostVisitedShop, 'タカヤモーター');
    });
  });

  group('YearInReview — 同車種との比較', () {
    test('平均より安ければ差額を出す', () {
      final review = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 186000)],
        from: from,
        to: now,
        peerAverageCost: 210000,
      );

      expect(review.costDiffFromPeers, -24000);
      expect(review.isCheaperThanPeers, isTrue);
    });

    test('平均より高ければ正の差になる', () {
      final review = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 250000)],
        from: from,
        to: now,
        peerAverageCost: 210000,
      );

      expect(review.costDiffFromPeers, 40000);
      expect(review.isCheaperThanPeers, isFalse);
    });

    test('比較相手がいなければ差は出さない', () {
      final review = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 250000)],
        from: from,
        to: now,
      );

      expect(review.costDiffFromPeers, isNull);
      expect(review.isCheaperThanPeers, isFalse);
    });
  });

  group('Edge Cases', () {
    test('記録が0件でも落ちない', () {
      final review = YearInReview.from(records: [], from: from, to: now);

      expect(review.totalCost, 0);
      expect(review.recordCount, 0);
      expect(review.distanceKm, isNull);
      expect(review.mostExpensive, isNull);
      expect(review.mostVisitedShop, isNull);
      expect(review.hasEnoughData, isFalse);
    });

    test('記録が1件だけなら走行距離は出せない（差が取れない）', () {
      final review = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 5000, mileage: 30000)],
        from: from,
        to: now,
      );

      expect(review.distanceKm, isNull);
    });

    test('走行距離が未入力の記録が混ざっても落ちない', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 9, 1), cost: 5000, mileage: 30000),
          rec(date: DateTime(2026, 1, 1), cost: 5000),
          rec(date: DateTime(2026, 7, 1), cost: 5000, mileage: 42400),
        ],
        from: from,
        to: now,
      );

      expect(review.distanceKm, 12400);
    });

    test('オドメーターが逆行していたら距離を出さない（入力ミス）', () {
      // 桁を間違えて入れると、差がとんでもない値になる。黙って見せない。
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2025, 9, 1), cost: 5000, mileage: 42400),
          rec(date: DateTime(2026, 7, 1), cost: 5000, mileage: 30000),
        ],
        from: from,
        to: now,
      );

      expect(review.distanceKm, isNull);
    });

    test('費用0円の記録も回数には数える（自分で整備した場合）', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2026, 3, 1), cost: 0),
          rec(date: DateTime(2026, 5, 1), cost: 0),
        ],
        from: from,
        to: now,
      );

      expect(review.recordCount, 2);
      expect(review.totalCost, 0);
      expect(review.mostExpensive, isNotNull);
    });

    test('店名が空文字なら「よく行った店」に数えない', () {
      final review = YearInReview.from(
        records: [
          rec(date: DateTime(2026, 3, 1), cost: 5000, shop: ''),
          rec(date: DateTime(2026, 5, 1), cost: 5000, shop: '   '),
        ],
        from: from,
        to: now,
      );

      expect(review.mostVisitedShop, isNull);
    });

    test('期間の端ちょうどの記録は含める', () {
      final review = YearInReview.from(
        records: [
          rec(date: from, cost: 1000),
          rec(date: now, cost: 2000),
        ],
        from: from,
        to: now,
      );

      expect(review.recordCount, 2);
    });

    test('記録が2件以上あって初めて振り返りとして見せる', () {
      final one = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 5000)],
        from: from,
        to: now,
      );
      final two = YearInReview.from(
        records: [
          rec(date: DateTime(2026, 3, 1), cost: 5000),
          rec(date: DateTime(2026, 5, 1), cost: 5000),
        ],
        from: from,
        to: now,
      );

      // 1件だけの「振り返り」は、見せられた側が白ける。
      expect(one.hasEnoughData, isFalse);
      expect(two.hasEnoughData, isTrue);
    });

    test('from と to が逆でも落ちない', () {
      final review = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 5000)],
        from: now,
        to: from,
      );

      expect(review.recordCount, 1);
    });
  });
}
