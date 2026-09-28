// 車種別の維持費レポートの画面（docs/SHOP_CRM_DESIGN_2026-09-27.md §8）。
//
// 数字が出ているかより、**出せないときに出せないと言えているか**を見る。
// 人数が足りない項目を0円や空欄で出すと、嘘になる。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/model_cost_report.dart';
import 'package:trust_car_platform/screens/vehicle/model_cost_report_screen.dart';
import 'package:trust_car_platform/services/model_cost_report_service.dart';

ModelCostReport _report({
  bool makerLevel = false,
  int? estimate = 182000,
  bool withFuel = true,
  int shopOwners = 5,
}) {
  return ModelCostReport.fromMap('mini__くーぱー', {
    'level': makerLevel ? 'maker' : 'model',
    'maker': 'MINI',
    'model': makerLevel ? null : 'クーパー',
    'ownerCount': 12,
    'vehicleCount': 14,
    'maintenanceAnnual': {'median': 60000, 'p25': 40000, 'p75': 90000, 'n': 12},
    'inspectionPerEvent': {
      'median': 120000,
      'p25': 100000,
      'p75': 150000,
      'n': 9
    },
    if (withFuel)
      'fuelAnnual': {'median': 62000, 'p25': 50000, 'p75': 80000, 'n': 6},
    'annualEstimate': estimate,
    'byAge': [
      {'label': '4〜6年目', 'median': 90000, 'n': 7},
      {'label': '7〜9年目', 'median': 140000, 'n': 5},
    ],
    'topItems': [
      {'type': 'オイル交換', 'owners': 11, 'medianCost': 8800},
    ],
    'sources': {'app': 7, 'shop': shopOwners},
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  group('ModelCostReportScreen', () {
    testWidgets('目安・内訳・年数ごと・よくある整備が出る', (tester) async {
      await _pump(tester, ModelCostReportScreen(report: _report()));

      expect(
        tester.widget<Text>(find.byKey(const Key('model_cost_estimate'))).data,
        '約 182,000円',
      );
      expect(find.text('整備・修理＋車検（2年に1回として）＋燃料'), findsOneWidget);
      expect(find.text('税金・保険・駐車場は入っていません'), findsOneWidget);
      expect(find.text('60,000円'), findsOneWidget);
      expect(find.textContaining('40,000円〜90,000円'), findsOneWidget);
      expect(find.text('7〜9年目'), findsOneWidget);
      expect(find.text('1回 8,800円'), findsOneWidget);
      expect(find.textContaining('整備工場の実績（5人分）'), findsOneWidget);
    });

    testWidgets('燃料の人数が足りなければ、0円ではなく「出せません」', (tester) async {
      await _pump(
          tester, ModelCostReportScreen(report: _report(withFuel: false)));

      expect(find.textContaining('給油を記録している人がまだ少ない'), findsOneWidget);
      expect(find.text('整備・修理＋車検（2年に1回として）'), findsOneWidget);
    });

    testWidgets('年あたりが出せなければ、そう言う', (tester) async {
      await _pump(
          tester, ModelCostReportScreen(report: _report(estimate: null)));

      expect(
        tester.widget<Text>(find.byKey(const Key('model_cost_estimate'))).data,
        'まだ出せません',
      );
      expect(find.textContaining('1年以上記録している人が5人'), findsOneWidget);
    });

    testWidgets('メーカー全体の数字なら、そうと分かるように出す', (tester) async {
      await _pump(
          tester, ModelCostReportScreen(report: _report(makerLevel: true)));

      expect(find.text('MINI（メーカー全体）'), findsOneWidget);
      expect(find.textContaining('メーカー全体の数字を出しています'), findsOneWidget);
    });

    testWidgets('店の実績が入っていなければ、その一文は出さない', (tester) async {
      await _pump(
          tester, ModelCostReportScreen(report: _report(shopOwners: 0)));
      expect(find.textContaining('整備工場の実績'), findsNothing);
    });
  });

  group('ModelCostBrowseScreen', () {
    late FakeFirebaseFirestore fs;
    late ModelCostReportService service;

    setUp(() {
      fs = FakeFirebaseFirestore();
      service = ModelCostReportService(firestore: fs);
    });

    testWidgets('まだ無ければ、いつ見られるかを案内する', (tester) async {
      await _pump(tester, ModelCostBrowseScreen(service: service));
      expect(find.text('まだ見られる車種がありません'), findsOneWidget);
      expect(find.textContaining('5人集まった車種から'), findsOneWidget);
    });

    testWidgets('表記を問わずに絞り込め、開くとレポートが出る', (tester) async {
      await fs.collection('model_cost_reports').doc('mini__くーぱー').set({
        'level': 'model',
        'maker': 'MINI',
        'model': 'クーパー',
        'ownerCount': 12,
        'annualEstimate': 182000,
      });
      await fs.collection('model_cost_reports').doc('とよた__はいえーす').set({
        'level': 'model',
        'maker': 'トヨタ',
        'model': 'ハイエース',
        'ownerCount': 40,
        'annualEstimate': 310000,
      });
      await _pump(tester, ModelCostBrowseScreen(service: service));

      // 持ち主の多い順
      final hiace = tester.getTopLeft(find.text('トヨタ ハイエース'));
      final mini = tester.getTopLeft(find.text('MINI クーパー'));
      expect(hiace.dy, lessThan(mini.dy));

      await tester.enterText(
          find.byKey(const Key('model_cost_filter')), 'ｸｰﾊﾟｰ');
      await tester.pumpAndSettle();
      expect(find.text('トヨタ ハイエース'), findsNothing);

      await tester.tap(find.text('MINI クーパー'));
      await tester.pumpAndSettle();
      expect(find.text('維持費レポート'), findsOneWidget);
    });
  });
}
