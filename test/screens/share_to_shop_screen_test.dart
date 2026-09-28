// 初めて行く店に、車のこれまでを渡す画面（docs/SHOP_CRM_DESIGN_2026-09-27.md §7）。
//
// 見たいのは、**選んでいないものが店に渡っていないこと**と、
// 取り消しが効くこと。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/screens/vehicle/share_to_shop_screen.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

final _now = DateTime(2026, 9, 27);

final _vehicle = Vehicle(
  id: 'v1',
  userId: 'u1',
  maker: 'MINI',
  model: 'クーパー',
  year: 2019,
  grade: '',
  mileage: 48000,
  licensePlate: '品川 300 あ 12-34',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

final _records = [
  MaintenanceRecord(
    id: 'r1',
    vehicleId: 'v1',
    userId: 'u1',
    type: MaintenanceType.oilChange,
    title: 'オイル交換',
    cost: 5500,
    date: DateTime(2026, 5, 1),
    createdAt: DateTime(2026, 5, 1),
  ),
];

Shop _shop(String id, String name) => Shop(
      id: id,
      name: name,
      type: ShopType.values.first,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late FakeFirebaseFirestore fs;
  late VehicleShareService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = VehicleShareService(firestore: fs, now: () => _now);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ShareToShopScreen(
        vehicle: _vehicle,
        records: _records,
        ownerId: 'u1',
        defaultContactName: '山田',
        service: service,
        searchShops: (q) async => Result.success(
          [_shop('takaya', 'タカヤモーター'), _shop('other', 'タカノ自動車')]
              .where((s) => s.name.startsWith(q))
              .toList(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pickTakaya(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('share_shop_query')), 'タカヤ');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share_shop_takaya')));
    await tester.pumpAndSettle();
  }

  testWidgets('店を選ぶまでは渡せない', (tester) async {
    await pump(tester);
    final button = tester.widget<ButtonStyleButton>(find.ancestor(
      of: find.text('このお店に渡す'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ));
    expect(button.onPressed, isNull);
  });

  testWidgets('既定のまま渡すと、ナンバー・費用・連絡先は店に渡らない', (tester) async {
    await pump(tester);
    await pickTakaya(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('share_summary'))).data,
      'タカヤモーター に、MINI クーパー・整備記録1件（費用なし） を30日間渡します。',
    );

    await tester.tap(find.byKey(const Key('share_submit')));
    await tester.pumpAndSettle();

    final d = (await fs.doc('shops/takaya/shared_vehicles/v1').get()).data()!;
    expect(d['plate'], isNull);
    expect(d['contactName'], isNull);
    expect(((d['records'] as List).single as Map).containsKey('cost'), isFalse);
  });

  testWidgets('オンにしたものだけが渡る', (tester) async {
    await pump(tester);
    await pickTakaya(tester);

    await tester.tap(find.byKey(const Key('share_include_plate')));
    await tester.tap(find.byKey(const Key('share_include_costs')));
    await tester.tap(find.byKey(const Key('share_include_contact')));
    await tester.pumpAndSettle();
    // 連絡先の名前は、アカウントの表示名が最初から入っている
    expect(find.text('山田'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share_submit')));
    await tester.pumpAndSettle();

    final d = (await fs.doc('shops/takaya/shared_vehicles/v1').get()).data()!;
    expect(d['plate'], '品川 300 あ 12-34');
    expect(d['contactName'], '山田');
    expect(((d['records'] as List).single as Map)['cost'], 5500);
  });

  testWidgets('共有中の店が出て、取り消せる', (tester) async {
    await service.share(
      ownerId: 'u1',
      vehicle: _vehicle,
      shopId: 'takaya',
      shopName: 'タカヤモーター',
      records: const [],
      days: 30,
    );
    await pump(tester);

    expect(find.text('共有中のお店'), findsOneWidget);
    await tester.tap(find.byKey(const Key('revoke_takaya')));
    await tester.pumpAndSettle();

    expect(find.text('共有中のお店'), findsNothing);
    expect((await fs.doc('shops/takaya/shared_vehicles/v1').get()).exists,
        isFalse);
  });

  testWidgets('見つからなければ、CSV で渡す道を案内する', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('share_shop_query')), 'ない店');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('CSV'), findsOneWidget);
  });
}
