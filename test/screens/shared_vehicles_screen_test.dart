// 店側：お客さんから渡された車の写しを受け取り、台帳に登録する。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/screens/shop/ledger/shared_vehicles_screen.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

final _now = DateTime(2026, 9, 27);

void main() {
  late FakeFirebaseFirestore fs;
  late VehicleShareService shares;
  late ShopLedgerService ledger;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    shares = VehicleShareService(firestore: fs, now: () => _now);
    ledger = ShopLedgerService(firestore: fs, now: () => _now);
  });

  Future<void> share({String? name}) => shares.share(
        ownerId: 'u1',
        vehicle: Vehicle(
          id: 'v1',
          userId: 'u1',
          maker: 'MINI',
          model: 'クーパー',
          year: 2019,
          grade: '',
          mileage: 48000,
          inspectionExpiryDate: DateTime(2027, 4, 1),
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
        shopId: 'takaya',
        shopName: 'タカヤモーター',
        records: [
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
        ],
        days: 30,
        contactName: name,
        message: '車検の見積もりをお願いします',
      );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SharedVehiclesScreen(
        service: shares,
        ledger: ledger,
        shopId: 'takaya',
        today: _now,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('まだ何も届いていなければ、どうすれば届くかを案内する', (tester) async {
    await pump(tester);
    expect(find.text('まだ共有された車はありません'), findsOneWidget);
    expect(find.text('顧客台帳に戻る'), findsOneWidget);
  });

  testWidgets('届いた車は未読で並び、開くと中身と一言が見える', (tester) async {
    await share(name: '山田太郎');
    await pump(tester);

    expect(find.text('未読'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shared_v1')));
    await tester.pumpAndSettle();

    expect(find.text('車検の見積もりをお願いします'), findsOneWidget);
    expect(find.text('2026/5/1  オイル交換'), findsOneWidget);
    // 費用は渡されていない
    expect(find.textContaining('費用は非公開'), findsOneWidget);
    expect(find.text('¥5500'), findsNothing);

    final d = (await fs.doc('shops/takaya/shared_vehicles/v1').get()).data()!;
    expect(d['seenAt'], isNotNull);
  });

  testWidgets('台帳に登録すると、その顧客の詳細が開く', (tester) async {
    await share(name: '山田太郎');
    await pump(tester);

    await tester.tap(find.byKey(const Key('shared_v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared_import')));
    await tester.pumpAndSettle();

    expect(find.text('山田太郎'), findsOneWidget); // AppBar
    expect(find.text('車両（1台）'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('登録済み'), findsOneWidget);
  });
}
