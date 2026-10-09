// The car picker for "記録に追加" (usability test 2026-10-09, shop #15).
//
// At 1209x677 the old sheet overflowed (yellow-black stripes) and the 4th car,
// the right one, could not be chosen. The sheet must scroll to fit the screen,
// on a phone (390x844) as well.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/widgets/shop/import_vehicle_sheet.dart';

Vehicle _car(String id, String maker, String model, String plate) => Vehicle(
      id: id,
      userId: 'u1',
      maker: maker,
      model: model,
      year: 2020,
      grade: '',
      mileage: 1000,
      licensePlate: plate,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

final _cars = [
  _car('a', 'Honda', 'N-BOX', '岡山 580 あ 11-11'),
  _car('b', 'Mazda', 'CX-5', '岡山 300 さ 22-22'),
  _car('c', 'Toyota', 'Prius', '岡山 300 あ 33-33'),
  _car('d', 'Toyota', 'Hiace', '岡山 400 な 44-44'),
];

Future<String?> _open(
  WidgetTester tester, {
  required Size size,
  List<Vehicle>? vehicles,
  String? initial,
  String? shopLabel,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  String? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              result = await showImportVehicleSheet(
                context,
                vehicles: vehicles ?? _cars,
                initialVehicleId: initial,
                shopVehicleLabel: shopLabel,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'はみ出していないこと');
  return result;
}

Future<void> _pickFourthAndConfirm(WidgetTester tester) async {
  final fourth = find.byKey(const Key('import_vehicle_d'));
  await tester.scrollUntilVisible(
    fourth,
    80,
    scrollable: find.descendant(
      of: find.byKey(const Key('import_vehicle_list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(fourth);
  await tester.pumpAndSettle();
  await tester.tap(fourth);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('import_vehicle_confirm')));
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [
    ('PC 1209x677', const Size(1209, 677)),
    ('スマホ 390x844', const Size(390, 844)),
    ('低い画面 800x420', const Size(800, 420)),
  ]) {
    testWidgets('$label: 4台目まで選べて、決定ボタンが押せる', (tester) async {
      String? picked;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  picked =
                      await showImportVehicleSheet(context, vehicles: _cars);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _pickFourthAndConfirm(tester);
      expect(tester.takeException(), isNull);
      expect(picked, 'd');
    });
  }

  testWidgets('店の指定した車が最初から選ばれていて、そのまま決定できる', (tester) async {
    await _open(
      tester,
      size: const Size(1209, 677),
      initial: 'd',
      shopLabel: 'トヨタ ハイエース・岡山 400 な 44-44',
    );
    expect(find.byKey(const Key('import_vehicle_shop_label')), findsOneWidget);
    final confirm = tester
        .widget<FilledButton>(find.byKey(const Key('import_vehicle_confirm')));
    expect(confirm.onPressed, isNotNull);
  });

  group('Edge Cases', () {
    testWidgets('初期選択が無ければ、選ぶまで決定できない', (tester) async {
      await _open(tester, size: const Size(390, 844));
      final confirm = tester.widget<FilledButton>(
          find.byKey(const Key('import_vehicle_confirm')));
      expect(confirm.onPressed, isNull);
    });

    testWidgets('手元に無い車の ID が初期選択に来ても、選ばれていない扱い', (tester) async {
      await _open(tester, size: const Size(390, 844), initial: 'gone');
      final confirm = tester.widget<FilledButton>(
          find.byKey(const Key('import_vehicle_confirm')));
      expect(confirm.onPressed, isNull);
    });

    testWidgets('車が20台でもはみ出さない', (tester) async {
      await _open(
        tester,
        size: const Size(390, 844),
        vehicles: [
          for (var i = 0; i < 20; i++) _car('v$i', 'Maker', 'Model $i', '$i'),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });
}
