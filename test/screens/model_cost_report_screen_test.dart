// 車種別の維持費レポートの画面（docs/SHOP_CRM_DESIGN_2026-09-27.md §8）。
//
// 数字が出ているかより、**出せないときに出せないと言えているか**を見る。
// 人数が足りない項目を0円や空欄で出すと、嘘になる。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/models/model_cost_report.dart';
import 'package:trust_car_platform/screens/vehicle/model_cost_report_screen.dart';
import 'package:trust_car_platform/services/analytics_service.dart';
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
  /// 利用者の最初の7日（改善 #6）。開いたら1回だけ送る（build のたびに送らない）。
  group('ModelCostReportScreen の最初の7日', () {
    testWidgets('開いたときに model_cost_viewed を1回だけ送る', (tester) async {
      final sent = <String>[];
      sl.registerSingleton<AnalyticsService>(AnalyticsService.forTesting(
        onLog: (name, params) {
          if (name == 'first_week_step') sent.add(params!['step'] as String);
        },
      ));
      addTearDown(() => sl.unregister<AnalyticsService>());

      await _pump(tester, ModelCostReportScreen(report: _report()));
      // 画面を描き直しても増えない
      await tester.pump();
      await tester.pump();

      expect(sent, ['model_cost_viewed']);
    });

    testWidgets('AnalyticsService が無くても画面は開ける', (tester) async {
      await _pump(tester, ModelCostReportScreen(report: _report()));
      expect(find.text('維持費レポート'), findsOneWidget);
    });
  });

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

    // Issue #208: 買う前の人が、車種を選んで・比べる
    group('選んで比べる', () {
      Future<void> put(String id, String maker, String model, int owners,
              {int? estimate, Map<String, dynamic>? fuel}) =>
          fs.collection('model_cost_reports').doc(id).set({
            'level': 'model',
            'maker': maker,
            'model': model,
            'ownerCount': owners,
            'maintenanceAnnual': {
              'median': 60000,
              'p25': 40000,
              'p75': 90000,
              'n': owners
            },
            if (fuel != null) 'fuelAnnual': fuel,
            if (estimate != null) 'annualEstimate': estimate,
          });

      testWidgets('2車種選ぶと並べて比べられ、出せない項目は「—」', (tester) async {
        final sent = <String>[];
        sl.registerSingleton<AnalyticsService>(AnalyticsService.forTesting(
          onLog: (name, params) {
            if (name == 'first_week_step') sent.add(params!['step'] as String);
          },
        ));
        addTearDown(() => sl.unregister<AnalyticsService>());

        await put('a', 'トヨタ', 'プリウス', 42,
            estimate: 160000,
            fuel: {'median': 100000, 'p25': 1, 'p75': 2, 'n': 30});
        await put('b', 'ホンダ', 'N-BOX', 38, estimate: 60000);
        await _pump(tester, ModelCostBrowseScreen(service: service));

        await tester.tap(find.byKey(const Key('model_cost_select_a')));
        await tester.pump();
        // 1車種だけでは比べられない
        expect(find.text('もう1車種選ぶと比べられます'), findsOneWidget);
        final button = find.byKey(const Key('model_cost_compare'));
        expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);

        await tester.tap(find.byKey(const Key('model_cost_select_b')));
        await tester.pump();
        expect(find.text('2車種を比べる'), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.text('維持費を比べる'), findsOneWidget);
        expect(find.text('トヨタ プリウス'), findsOneWidget);
        expect(find.text('ホンダ N-BOX'), findsOneWidget);
        expect(find.text('160,000円'), findsOneWidget);
        expect(find.text('60,000円'), findsNWidgets(3)); // 目安(b)と整備(a,b)
        // N-BOX の燃料・両方の車検は出せない
        expect(find.text('—'), findsNWidgets(3));
        expect(find.text('0円'), findsNothing);
        // 比べる画面も、レポートを見たのと同じ扱い
        expect(sent, ['model_cost_viewed']);
      });

      testWidgets('比べる画面の車種名から、中古車検索つきのレポートへ', (tester) async {
        await put('a', 'トヨタ', 'プリウス', 42, estimate: 160000);
        await put('b', 'ホンダ', 'N-BOX', 38, estimate: 60000);
        await _pump(tester, ModelCostBrowseScreen(service: service));
        await tester.tap(find.byKey(const Key('model_cost_select_a')));
        await tester.tap(find.byKey(const Key('model_cost_select_b')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('model_cost_compare')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('model_cost_compare_open_b')));
        await tester.pumpAndSettle();
        expect(find.text('維持費レポート'), findsOneWidget);
        expect(find.text('この車種の中古車を探す'), findsOneWidget);
      });

      testWidgets('一覧から開いたレポートには中古車検索が出る', (tester) async {
        await put('a', 'トヨタ', 'プリウス', 42, estimate: 160000);
        await _pump(tester, ModelCostBrowseScreen(service: service));
        await tester.tap(find.text('トヨタ プリウス'));
        await tester.pumpAndSettle();

        expect(find.text('この車種の中古車を探す'), findsOneWidget);
        expect(find.byKey(const Key('model_cost_used_car_0')), findsOneWidget);
        expect(find.text('カーセンサー'), findsOneWidget);
        expect(find.text('Goo-net'), findsOneWidget);
      });

      group('Edge Cases', () {
        testWidgets('3車種まで。4つ目は選べない', (tester) async {
          for (final id in ['a', 'b', 'c', 'd']) {
            await put(id, 'M', id, 10);
          }
          await _pump(tester, ModelCostBrowseScreen(service: service));
          for (final id in ['a', 'b', 'c']) {
            await tester.tap(find.byKey(Key('model_cost_select_$id')));
            await tester.pump();
          }
          expect(find.text('3車種を比べる'), findsOneWidget);
          final d = tester
              .widget<Checkbox>(find.byKey(const Key('model_cost_select_d')));
          expect(d.onChanged, isNull);

          // 1つ外せば、また選べる
          await tester.tap(find.byKey(const Key('model_cost_select_a')));
          await tester.pump();
          await tester.tap(find.byKey(const Key('model_cost_select_d')));
          await tester.pump();
          expect(find.text('3車種を比べる'), findsOneWidget);
        });

        testWidgets('持ち主4人の車種は一覧に出ない（5人は出る）', (tester) async {
          await put('four', 'M', '四人', 4, estimate: 100000);
          await put('five', 'M', '五人', 5, estimate: 100000);
          await _pump(tester, ModelCostBrowseScreen(service: service));

          expect(find.text('M 五人'), findsOneWidget);
          expect(find.text('M 四人'), findsNothing);
        });

        testWidgets('比べる画面に持ち主4人のレポートを渡しても並べない', (tester) async {
          final four = ModelCostReport.fromMap('four', {
            'maker': 'M',
            'model': '四人',
            'ownerCount': 4,
          });
          await _pump(
            tester,
            ModelCostCompareScreen(reports: [_report(), four]),
          );
          expect(find.text('MINI クーパー'), findsOneWidget);
          expect(find.text('M 四人'), findsNothing);
        });

        testWidgets('メーカー全体のレポートを比べるときは、その旨を添える', (tester) async {
          final maker = ModelCostReport.fromMap('toyota', {
            'level': 'maker',
            'maker': 'トヨタ',
            'ownerCount': 30,
          });
          await _pump(
            tester,
            ModelCostCompareScreen(reports: [_report(), maker]),
          );
          expect(find.text('トヨタ（メーカー全体）'), findsOneWidget);
          expect(find.textContaining('メーカー全体の数字です'), findsOneWidget);
        });

        testWidgets('同じ車種を2回渡されても1列だけ', (tester) async {
          await _pump(
            tester,
            ModelCostCompareScreen(reports: [_report(), _report()]),
          );
          expect(find.text('MINI クーパー'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      });
    });
  });

  group('ModelCostReportScreen の中古車検索', () {
    testWidgets('既定（自分の車から開いたとき）は出さない', (tester) async {
      await _pump(tester, ModelCostReportScreen(report: _report()));
      expect(find.text('この車種の中古車を探す'), findsNothing);
      expect(find.byKey(const Key('model_cost_used_car_0')), findsNothing);
    });

    group('Edge Cases', () {
      testWidgets('メーカー全体のレポートでは、メーカーで探す', (tester) async {
        await _pump(
          tester,
          ModelCostReportScreen(
            report: _report(makerLevel: true),
            showUsedCarSearch: true,
          ),
        );
        expect(find.text('MINIの中古車を探す'), findsOneWidget);
      });
    });
  });

  // 5人に満たない数字を画面に出さない境界（サーバーの書き損じがあっても）
  group('ModelCostReportScreen の5人の境界', () {
    ModelCostReport withInspection(int n) => ModelCostReport.fromMap('x', {
          'level': 'model',
          'maker': 'MINI',
          'model': 'クーパー',
          'ownerCount': 12,
          'maintenanceAnnual': {
            'median': 60000,
            'p25': 40000,
            'p75': 90000,
            'n': 12
          },
          'inspectionPerEvent': {
            'median': 120000,
            'p25': 100000,
            'p75': 150000,
            'n': n
          },
          'annualEstimate': 120000,
        });

    testWidgets('車検が5人なら金額を出す', (tester) async {
      await _pump(tester, ModelCostReportScreen(report: withInspection(5)));
      expect(find.text('120,000円'), findsOneWidget);
      expect(find.text('約 120,000円'), findsOneWidget);
    });

    testWidgets('車検が4人なら金額を出さず、目安からも外す', (tester) async {
      await _pump(tester, ModelCostReportScreen(report: withInspection(4)));
      expect(find.text('120,000円'), findsNothing);
      expect(find.textContaining('（4人）'), findsNothing);
      expect(find.text('約 60,000円'), findsOneWidget);
    });
  });
}
