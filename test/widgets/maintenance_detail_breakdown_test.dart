// MaintenanceDetailBreakdown Widget Tests
//
// 整備記録の明細表示。これまで保存されるだけで画面に出ていなかった
// 部品・金額内訳・次回交換・点検結果・タイヤを出す。
//
// Coverage:
//   - 値がある項目だけが出ること
//   - 何も無ければ何も描画しないこと
//   - 内訳の合計と請求額がずれたときに注記が出ること
//   - Edge cases（0円、割引のみ、数量1、極端な件数）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/widgets/maintenance/maintenance_detail_breakdown.dart';

MaintenanceRecord _record({
  int cost = 10000,
  List<Part> parts = const [],
  int? partsCost,
  int? laborCost,
  int? miscCost,
  int? taxAmount,
  int? discountAmount,
  DateTime? nextReplacementDate,
  int? nextReplacementMileage,
  InspectionResult? inspectionResult,
  bool certificateUpdated = false,
  String? safetyStandardsCertificate,
  String? staffName,
  String? tireSize,
  String? tirePosition,
  int? tireTreadDepth,
}) {
  return MaintenanceRecord(
    id: 'r1',
    vehicleId: 'v1',
    userId: 'u1',
    type: MaintenanceType.other,
    title: '点検',
    cost: cost,
    date: DateTime(2026, 5, 1),
    createdAt: DateTime(2026, 5, 1),
    parts: parts,
    partsCost: partsCost,
    laborCost: laborCost,
    miscCost: miscCost,
    taxAmount: taxAmount,
    discountAmount: discountAmount,
    nextReplacementDate: nextReplacementDate,
    nextReplacementMileage: nextReplacementMileage,
    inspectionResult: inspectionResult,
    certificateUpdated: certificateUpdated,
    safetyStandardsCertificate: safetyStandardsCertificate,
    staffName: staffName,
    tireSize: tireSize,
    tirePosition: tirePosition,
    tireTreadDepth: tireTreadDepth,
  );
}

Future<void> _pump(WidgetTester tester, MaintenanceRecord record) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MaintenanceDetailBreakdown(record: record),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when the record has no breakdown data',
      (tester) async {
    await _pump(tester, _record());
    expect(find.byKey(const Key('maintenance_detail_breakdown')), findsNothing);
  });

  testWidgets('shows parts with quantity, unit price and subtotal',
      (tester) async {
    await _pump(
      tester,
      _record(parts: [
        const Part(
          partNumber: '90915-10003',
          name: 'オイルフィルター',
          manufacturer: 'トヨタ純正',
          unitPrice: 1200,
          quantity: 2,
        ),
      ]),
    );
    expect(find.text('使用部品'), findsOneWidget);
    expect(find.text('オイルフィルター'), findsOneWidget);
    expect(find.text('トヨタ純正 / 品番 90915-10003'), findsOneWidget);
    expect(find.text('¥2,400'), findsOneWidget);
    expect(find.text('¥1,200 × 2'), findsOneWidget);
  });

  testWidgets('hides the unit price line when quantity is 1', (tester) async {
    await _pump(
      tester,
      _record(parts: [
        const Part(
          partNumber: '',
          name: 'ワイパーゴム',
          unitPrice: 800,
          quantity: 1,
        ),
      ]),
    );
    expect(find.text('¥800'), findsOneWidget);
    expect(find.text('¥800 × 1'), findsNothing);
  });

  testWidgets('shows the cost breakdown and total', (tester) async {
    await _pump(
      tester,
      _record(
        cost: 11000,
        partsCost: 4000,
        laborCost: 6000,
        taxAmount: 1000,
      ),
    );
    expect(find.text('金額内訳'), findsOneWidget);
    expect(find.text('部品代'), findsOneWidget);
    expect(find.text('¥4,000'), findsOneWidget);
    expect(find.text('合計'), findsOneWidget);
    expect(find.text('¥11,000'), findsOneWidget);
  });

  testWidgets('warns when the breakdown does not add up to the total',
      (tester) async {
    // 請求額と内訳がずれていることに気付ける唯一の手がかり。
    await _pump(tester, _record(cost: 20000, partsCost: 4000));
    expect(
      find.textContaining('請求額と一致しません'),
      findsOneWidget,
    );
  });

  testWidgets('shows a negative sign for the discount row', (tester) async {
    await _pump(
        tester, _record(cost: 9000, laborCost: 10000, discountAmount: 1000));
    expect(find.text('割引'), findsOneWidget);
    expect(find.text('-¥1,000'), findsOneWidget);
  });

  testWidgets('shows the next replacement date and mileage', (tester) async {
    await _pump(
      tester,
      _record(
        nextReplacementDate: DateTime(2027, 5, 1),
        nextReplacementMileage: 45000,
      ),
    );
    expect(find.text('次回交換の目安'), findsOneWidget);
    expect(find.text('2027年05月01日 / 45,000 km'), findsOneWidget);
  });

  testWidgets('shows the inspection result and certificate info',
      (tester) async {
    await _pump(
      tester,
      _record(
        inspectionResult: InspectionResult.passed,
        certificateUpdated: true,
        safetyStandardsCertificate: 'A-12345',
        staffName: '山田',
      ),
    );
    expect(find.text('点検・証明'), findsOneWidget);
    expect(find.text('合格'), findsOneWidget);
    expect(find.text('A-12345'), findsOneWidget);
    expect(find.text('更新済み'), findsOneWidget);
    expect(find.text('山田'), findsOneWidget);
  });

  testWidgets('shows tire details', (tester) async {
    await _pump(
      tester,
      _record(
        tireSize: '215/55R17',
        tirePosition: '全輪',
        tireTreadDepth: 5,
      ),
    );
    expect(find.text('タイヤ'), findsOneWidget);
    expect(find.text('215/55R17'), findsOneWidget);
    expect(find.text('5 mm'), findsOneWidget);
  });

  group('Edge Cases', () {
    testWidgets('a zero-yen breakdown row is still shown', (tester) async {
      // 0円は「未入力」ではない。無償対応だったという情報が消えてはいけない。
      await _pump(tester, _record(cost: 0, laborCost: 0));
      expect(find.text('工賃'), findsOneWidget);
      expect(find.text('¥0'), findsAtLeastNWidgets(1));
    });

    testWidgets('a discount-only record renders without a crash',
        (tester) async {
      await _pump(tester, _record(cost: 0, discountAmount: 500));
      expect(find.text('割引'), findsOneWidget);
    });

    testWidgets('many parts render without overflow', (tester) async {
      await _pump(
        tester,
        _record(
          parts: List.generate(
            30,
            (i) => Part(
              partNumber: 'P$i',
              name: '部品$i',
              unitPrice: 100,
              quantity: 1,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a part with no manufacturer or part number has no subtitle',
        (tester) async {
      await _pump(
        tester,
        _record(parts: [
          const Part(partNumber: '', name: '雑品', unitPrice: 100, quantity: 1),
        ]),
      );
      expect(find.text('雑品'), findsOneWidget);
      expect(find.textContaining('品番'), findsNothing);
    });
  });
}
