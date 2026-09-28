// 車両登録時に過去の整備記録を移す画面。

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/screens/shop/ledger/ledger_csv_import_screen.dart';
import 'package:trust_car_platform/screens/vehicle/maintenance_history_import_screen.dart';
import 'package:trust_car_platform/screens/vehicle_registration_screen.dart';
import 'package:trust_car_platform/services/maintenance_history_import.dart';
import 'package:trust_car_platform/services/maintenance_history_import_service.dart';

final _today = DateTime(2026, 9, 28);

Vehicle _vehicle({int year = 2019, int mileage = 48000}) => Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'MINI',
      model: 'クーパー',
      year: year,
      grade: '',
      mileage: mileage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() => fs = FakeFirebaseFirestore());

  Future<List<Object?>> pump(
    WidgetTester tester, {
    PickedCsvFile? file,
    List<String>? shared,
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <Object?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            results.add(await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => MaintenanceHistoryImportScreen(
                  vehicle: _vehicle(),
                  userId: 'u1',
                  service: MaintenanceHistoryImportService(
                    firestore: fs,
                    now: () => _today,
                  ),
                  pickFile: () async => file,
                  shareTemplate: (csv) async => shared?.add(csv),
                  today: _today,
                ),
              ),
            ));
          },
          child: const Text('開く'),
        ),
      ),
    ));
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('記入用フォーマットを渡せる', (tester) async {
    final shared = <String>[];
    await pump(tester, shared: shared);
    await tester.tap(find.byKey(const Key('history_template')));
    await tester.pumpAndSettle();
    expect(shared.single, historyTemplateCsv());
  });

  testWidgets('記入したファイルを選ぶと中身が見え、移すと記録になる', (tester) async {
    final csv = '${historyTemplateCsv()}'
        '2023/4/10,車検,24か月点検・車検,128000,42000,タカヤモーター,\r\n'
        'R5.10.2,オイル交換,,8800,45500,,\r\n'
        '2027/1/1,車検,予定,100000,,,\r\n';
    final results =
        await pump(tester, file: PickedCsvFile('記入済み.csv', utf8.encode(csv)));

    await tester.tap(find.byKey(const Key('history_pick')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('history_plan_summary'))).data,
      '2件を移します',
    );
    expect(find.text('2023/4/10〜2023/10/2・合計 136,800円'), findsOneWidget);
    // 未来の日付は、何行目かを添えて外す
    expect(find.textContaining('未来の日付'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history_import_run')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('history_import_result'))).data,
      '2件を追加しました',
    );
    expect(
        (await fs.collection('maintenance_records').get()).docs, hasLength(2));

    await tester.tap(find.byKey(const Key('history_import_done')));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  group('Edge Cases', () {
    testWidgets('実施日の列が無いファイルは、理由を出して止める', (tester) async {
      await pump(tester,
          file: PickedCsvFile('x.csv', utf8.encode('名前,値段\na,1\n')));
      await tester.tap(find.byKey(const Key('history_pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_import_error')), findsOneWidget);
      expect(find.byKey(const Key('history_import_run')), findsNothing);
    });

    testWidgets('フォーマットを何も書かずに戻したら、移せない', (tester) async {
      await pump(tester,
          file: PickedCsvFile('空.csv', utf8.encode(historyTemplateCsv())));
      await tester.tap(find.byKey(const Key('history_pick')));
      await tester.pumpAndSettle();
      expect(find.text('取り込める行がありません'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('移す'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ));
      expect(button.onPressed, isNull);
    });
  });

  group('isLikelyUsedVehicle', () {
    test('年式が今年より前か、1,000kmを超えていれば中古とみなす', () {
      expect(isLikelyUsedVehicle(_vehicle(year: 2019, mileage: 0), _today),
          isTrue);
      expect(isLikelyUsedVehicle(_vehicle(year: 2026, mileage: 5000), _today),
          isTrue);
    });

    test('今年の年式で走行距離が少なければ新車とみなす（聞かない）', () {
      expect(isLikelyUsedVehicle(_vehicle(year: 2026, mileage: 30), _today),
          isFalse);
    });
  });
}
