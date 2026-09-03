import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/year_in_review.dart';
import 'package:trust_car_platform/screens/year_in_review_screen.dart';

/// 「あなたのクルマの1年」の画面。
///
/// `docs/HABIT_DESIGN.md` 打ち手2。**溜めた記録を突き返す**のが役目なので、
/// 数字がそのまま読めることを固定する。
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

  final to = DateTime(2026, 8, 25);
  final from = DateTime(2025, 8, 25);

  YearInReview fullReview({int? peerAverageCost}) {
    return YearInReview.from(
      records: [
        rec(
            date: DateTime(2025, 9, 1),
            cost: 5000,
            mileage: 30000,
            shop: 'タカヤモーター'),
        rec(
            date: DateTime(2026, 2, 1),
            cost: 6000,
            mileage: 36000,
            shop: 'タカヤモーター'),
        rec(
          date: DateTime(2026, 3, 1),
          cost: 74000,
          type: MaintenanceType.legalInspection24,
          mileage: 38000,
          shop: 'ディーラー',
        ),
        rec(
            date: DateTime(2026, 7, 1),
            cost: 12000,
            mileage: 42400,
            shop: 'タカヤモーター'),
      ],
      from: from,
      to: to,
      peerAverageCost: peerAverageCost,
    );
  }

  Widget wrap(YearInReview review, {String vehicleName = 'トヨタ プリウス'}) {
    return MaterialApp(
      home: YearInReviewScreen(review: review, vehicleName: vehicleName),
    );
  }

  group('YearInReviewScreen', () {
    testWidgets('車名が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('トヨタ プリウス'), findsWidgets);
    });

    testWidgets('かかった費用が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      // 97,000円（5000 + 6000 + 74000 + 12000）
      expect(find.textContaining('97,000'), findsWidgets);
    });

    testWidgets('走った距離が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('12,400'), findsWidgets);
    });

    testWidgets('整備した回数が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('いちばん高かった整備が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('74,000'), findsWidgets);
    });

    testWidgets('よく行った店が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      expect(find.textContaining('タカヤモーター'), findsWidgets);
    });
  });

  group('YearInReviewScreen — 同車種との比較', () {
    // 自分の数字だけでは良し悪しが分からない。比べて初めて見たくなる。
    testWidgets('平均より安ければ、その差額が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview(peerAverageCost: 120000)));
      await tester.pumpAndSettle();

      // 97,000 - 120,000 = -23,000
      expect(find.textContaining('23,000'), findsWidgets);
    });

    testWidgets('比較相手がいなければ、その欄ごと出さない', (tester) async {
      await tester.pumpWidget(wrap(fullReview()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peer_comparison')), findsNothing);
    });

    testWidgets('比較相手がいれば欄が出る', (tester) async {
      await tester.pumpWidget(wrap(fullReview(peerAverageCost: 120000)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peer_comparison')), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('記録が足りないときは、振り返りではなく案内を出す', (tester) async {
      final thin = YearInReview.from(
        records: [rec(date: DateTime(2026, 3, 1), cost: 5000)],
        from: from,
        to: to,
      );

      await tester.pumpWidget(wrap(thin));
      await tester.pumpAndSettle();

      // 1件だけの「振り返り」は白ける。溜まってからまた見に来てもらう。
      expect(find.byKey(const Key('not_enough_data')), findsOneWidget);
      expect(find.byKey(const Key('review_body')), findsNothing);
    });

    testWidgets('記録が0件でも落ちない', (tester) async {
      final empty = YearInReview.from(records: [], from: from, to: to);

      await tester.pumpWidget(wrap(empty));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('not_enough_data')), findsOneWidget);
    });

    testWidgets('走行距離が出せないときは、その欄を出さない', (tester) async {
      // 走行距離が入った記録が1件しかない → 差が取れない
      final noDistance = YearInReview.from(
        records: [
          rec(date: DateTime(2026, 1, 1), cost: 5000, mileage: 30000),
          rec(date: DateTime(2026, 3, 1), cost: 6000),
        ],
        from: from,
        to: to,
      );

      await tester.pumpWidget(wrap(noDistance));
      await tester.pumpAndSettle();

      // 0km と書くと「1年で0km」と読まれる。欄ごと出さない。
      expect(find.byKey(const Key('distance_stat')), findsNothing);
    });

    testWidgets('店名が無くても落ちない', (tester) async {
      final noShop = YearInReview.from(
        records: [
          rec(date: DateTime(2026, 1, 1), cost: 5000),
          rec(date: DateTime(2026, 3, 1), cost: 6000),
        ],
        from: from,
        to: to,
      );

      await tester.pumpWidget(wrap(noShop));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shop_stat')), findsNothing);
      expect(find.byKey(const Key('review_body')), findsOneWidget);
    });

    testWidgets('車名が空でも落ちない', (tester) async {
      await tester.pumpWidget(wrap(fullReview(), vehicleName: ''));
      await tester.pumpAndSettle();

      expect(find.byType(YearInReviewScreen), findsOneWidget);
    });

    testWidgets('狭い画面でもはみ出さない', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(fullReview(peerAverageCost: 120000)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
