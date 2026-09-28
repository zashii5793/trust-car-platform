// 車検の取りこぼしの画面。取込が古いときに「率を出さない」ことを必ず見る。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/screens/shop/ledger/loss_report_screen.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

final _today = DateTime(2026, 9, 29);

Future<ShopLedgerService> _seed(FakeFirebaseFirestore fs,
    {bool withHistory = true}) async {
  final s = ShopLedgerService(firestore: fs, now: () => _today);
  await s.importPlan(
    shopId: 's1',
    plan: buildImportPlan([
      ['C1', '入庫した人', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
      ['C2', '来なかった人', 'V2', 'ホンダ', 'N-BOX', '2026/5/20'],
    ], guessColumns(['顧客番号', '顧客名', '車両番号', 'メーカー', '車名', '車検満了日'])),
  );
  if (withHistory) {
    await s.importHistory(
      shopId: 's1',
      plan: buildHistoryPlan([
        ['S1', '2026/4/20', 'V1', '車検', '120000'],
      ], guessHistoryColumns(['伝票番号', '作業日', '車両番号', '作業内容', '合計金額'])),
    );
  }
  return s;
}

void main() {
  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pumpAndSettle();
  }

  testWidgets('率と、声をかける相手が出る。タップで顧客を開く', (tester) async {
    final fs = FakeFirebaseFirestore();
    final service = await _seed(fs);
    String? opened;
    await pump(
      tester,
      LossReportScreen(
        service: service,
        shopId: 's1',
        onOpenCustomer: (id) => opened = id,
      ),
    );
    expect(tester.widget<Text>(find.byKey(const Key('loss_rate'))).data, '50%');
    expect(find.text('満了した 2台のうち 1台が、車検で入庫していません'), findsOneWidget);
    expect(find.text('来なかった人'), findsOneWidget);
    await tester.tap(find.text('来なかった人'));
    expect(opened, ShopLedgerService.idForExternal('c', 'C2'));
  });

  testWidgets('整備履歴が無ければ、率は出さずに理由と取り込み方を出す', (tester) async {
    final fs = FakeFirebaseFirestore();
    final service = await _seed(fs, withHistory: false);
    await pump(tester, LossReportScreen(service: service, shopId: 's1'));
    expect(tester.widget<Text>(find.byKey(const Key('loss_rate'))).data,
        'まだ出せません');
    expect(find.byKey(const Key('loss_stale_note')), findsOneWidget);
    expect(find.textContaining('50%'), findsNothing);
  });
}
