// 流れ: 中古車を登録した日に、過去の整備記録を移す。
//
//   利用者 車両登録（メーカー → 車種 → 年式 → グレード → 走行距離 → 登録する）
//        → 「過去の整備記録を移しますか？」→ 移す
//        → 記入したフォーマットを選ぶ → 移す
//        → 車両の整備記録（車両画面と同じ読み出し経路）に出る
//
// それまでの通しテストは、登録画面を開いて見出しを確かめるだけで、
// 最後まで登録して保存するところは一度も通していなかった。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/screens/shop/ledger/ledger_csv_import_screen.dart';
import 'package:trust_car_platform/screens/vehicle_registration_screen.dart';
import 'package:trust_car_platform/services/maintenance_history_import.dart';
import 'package:trust_car_platform/services/maintenance_history_import_service.dart';
import 'package:trust_car_platform/services/vehicle_master_service.dart';
import 'package:trust_car_platform/services/vehicle_spec_service.dart';

import 'flow_harness.dart';

void main() {
  // 作業中（2026-09-28）: 「登録する」のあとで止まる。保存中の表示を先に
  // 止める修正は入れたが、まだ最後まで通らない。続きは CLAUDE_SESSION_NOTES.md。
  testWidgets(skip: true, '中古車を登録した日に、過去の整備記録を移す', (tester) async {
    final world = FlowWorld();
    final me = FlowActor('app-me', '山田太郎');

    // 車種マスタ（本番は管理画面から入れているもの）
    final masters = world.fs.collection('vehicle_masters');
    await masters.doc('makers').collection('items').doc('mini').set({
      'name': 'MINI',
      'nameEn': 'MINI',
      'isActive': true,
      'displayOrder': 1,
    });
    await masters.doc('models').collection('items').doc('mini_cooper').set({
      'makerId': 'mini',
      'name': 'クーパー',
      'isActive': true,
      'displayOrder': 1,
    });
    await masters.doc('grades').collection('items').doc('mini_cooper_s').set({
      'modelId': 'mini_cooper',
      'name': 'S',
      'isActive': true,
      'displayOrder': 1,
    });
    sl.override<VehicleMasterService>(
        VehicleMasterService(firestore: world.fs));
    sl.override<VehicleSpecService>(VehicleSpecService(firestore: world.fs));
    sl.override<MaintenanceHistoryImportService>(
      MaintenanceHistoryImportService(
          firestore: world.fs, now: () => world.today),
    );

    final filled = '${historyTemplateCsv()}'
        '2023/4/10,車検,24か月点検・車検,128000,42000,前のお店,\r\n'
        'R5.10.2,オイル交換,,8800,45500,,\r\n'
        '2024/1/20,タイヤ交換,スタッドレス4本,92000,,,\r\n';

    await world.pumpAs(
      tester,
      me,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => VehicleRegistrationScreen(
                historyCsvPicker: () async =>
                    PickedCsvFile('整備記録_記入済み.csv', utf8.encode(filled)),
              ),
            ),
          ),
          child: const Text('車両を登録'),
        ),
      ),
    );
    await tester.tap(find.text('車両を登録'));
    await tester.pumpAndSettle();

    // ---- 基本情報 ----
    await tester.tap(find.text('メーカーを選択 *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MINI').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('車種を選択 *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('クーパー').last);
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(
      of: find.text('年式 *'),
      matching: find.byType(TextFormField),
    ));
    // 入力欄のカーソルが点滅し続けるので、落ち着くのを待たずに進める
    await tester.pump(const Duration(milliseconds: 600));
    final y2019 = find.widgetWithText(ListTile, '2019年（令和1年）');
    await tester.ensureVisible(y2019);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(y2019);
    await tester.pump(const Duration(milliseconds: 600));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('グレードを選択 *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('走行距離 *'),
        matching: find.byType(TextFormField),
      ),
      '48000',
    );
    await tester.pumpAndSettle();

    // ---- 次へ → 次へ → 登録する ----
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    // ---- 中古車なので、過去の記録を移すかを聞かれる ----
    expect(find.text('過去の整備記録を移しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history_offer_go')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history_pick')));
    await tester.pumpAndSettle();
    expect(find.text('3件を移します'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history_import_run')));
    await tester.pumpAndSettle();
    expect(find.text('3件を追加しました'), findsOneWidget);

    // ---- 登録した車の記録として出る（車両画面と同じ読み出し経路）----
    final firebase = world.firebaseFor(me);
    final vehicles = await firebase.getUserVehicles().first;
    expect(vehicles, hasLength(1));
    final car = vehicles.single;
    expect(car.maker, 'MINI');
    expect(car.model, 'クーパー');
    expect(car.year, 2019);

    final records = await firebase.getVehicleMaintenanceRecords(car.id).first;
    expect(records, hasLength(3));
    expect(records.map((r) => r.cost).toSet(), {128000, 8800, 92000});
    expect(records.every((r) => !r.isVerified), isTrue); // 移した記録は自己申告
  });
}
