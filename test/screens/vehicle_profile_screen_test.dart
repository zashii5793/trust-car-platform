// 愛車ページ（公開）と、その編集画面。投稿の「どの車の話か」チップ。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_profile.dart';
import 'package:trust_car_platform/screens/vehicle/vehicle_profile_screen.dart';
import 'package:trust_car_platform/services/vehicle_profile_service.dart';
import 'package:trust_car_platform/widgets/sns/post_vehicle_chip.dart';

final _now = DateTime(2026, 9, 27);

final _vehicle = Vehicle(
  id: 'v1',
  userId: 'u1',
  maker: 'MINI',
  model: 'クーパー',
  year: 2019,
  grade: 'S',
  mileage: 48000,
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
    cost: 8800,
    date: DateTime(2026, 5, 1),
    createdAt: DateTime(2026, 5, 1),
  ),
];

void main() {
  late FakeFirebaseFirestore fs;
  late VehicleProfileService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = VehicleProfileService(firestore: fs, now: () => _now);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  group('VehicleProfileEditScreen', () {
    testWidgets('既定は公開・整備は出さない。保存するとページができる', (tester) async {
      VehicleProfile? saved;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              saved = await Navigator.push<VehicleProfile>(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleProfileEditScreen(
                    service: service,
                    vehicle: _vehicle,
                    ownerId: 'u1',
                    ownerName: 'みにお',
                    records: _records,
                  ),
                ),
              );
            },
            child: const Text('開く'),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const Key('vehicle_profile_maintenance')))
            .value,
        isFalse,
      );
      await tester.enterText(
          find.byKey(const Key('vehicle_profile_nickname')), '白いミニ');
      await tester.tap(find.byKey(const Key('vehicle_profile_save')));
      await tester.pumpAndSettle();

      expect(saved!.title, '白いミニ');
      expect(saved!.isPublic, isTrue);
      expect(saved!.maintenance, isEmpty);
    });
  });

  group('VehicleProfileScreen', () {
    testWidgets('投稿が無ければ、どうすれば集まるかを案内する', (tester) async {
      final p = (await service.save(
        ownerId: 'u1',
        ownerName: 'みにお',
        vehicle: _vehicle,
        isPublic: true,
        showsMaintenance: true,
        records: _records,
      ))
          .valueOrNull!;
      await pump(tester, VehicleProfileScreen(service: service, profile: p));

      expect(find.text('MINI クーパー'), findsOneWidget);
      expect(find.text('MINI クーパー S 2019年式'), findsOneWidget);
      expect(find.text('オーナー: みにお'), findsOneWidget);
      // 整備は回数だけ（金額は無い）
      expect(find.text('1回'), findsOneWidget);
      expect(find.textContaining('8,800'), findsNothing);
      expect(find.text('まだこの車の投稿がありません'), findsOneWidget);
    });

    testWidgets('公開の投稿が集まる', (tester) async {
      final p = (await service.save(
        ownerId: 'u1',
        ownerName: 'みにお',
        vehicle: _vehicle,
        isPublic: true,
        showsMaintenance: false,
      ))
          .valueOrNull!;
      await fs.collection('posts').doc('p1').set({
        'userId': 'u1',
        'content': '海沿いを走ってきました',
        'visibility': 'public',
        'vehicleTag': {'vehicleId': 'v1'},
        'createdAt': Timestamp.fromDate(_now),
      });
      await pump(tester, VehicleProfileScreen(service: service, profile: p));
      expect(find.text('海沿いを走ってきました'), findsOneWidget);
    });

    testWidgets('非公開なら、本人にそう伝える', (tester) async {
      final p = (await service.save(
        ownerId: 'u1',
        ownerName: 'みにお',
        vehicle: _vehicle,
        isPublic: false,
        showsMaintenance: false,
      ))
          .valueOrNull!;
      await pump(tester, VehicleProfileScreen(service: service, profile: p));
      expect(find.byKey(const Key('vehicle_profile_private_note')),
          findsOneWidget);
    });
  });

  group('PostVehicleChip', () {
    const tag = PostVehicleTag(
      vehicleId: 'v1',
      makerName: 'MINI',
      modelName: 'クーパー',
      year: 2019,
    );

    testWidgets('車の札が無ければ何も出さない', (tester) async {
      await pump(
          tester,
          Scaffold(
              body: PostVehicleChip(
                  tag: const PostVehicleTag(), service: service)));
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('ページがあれば開く', (tester) async {
      await service.save(
        ownerId: 'u1',
        ownerName: 'みにお',
        vehicle: _vehicle,
        isPublic: true,
        showsMaintenance: false,
      );
      await pump(
          tester, Scaffold(body: PostVehicleChip(tag: tag, service: service)));
      expect(find.text('MINI クーパー (2019年式)'), findsOneWidget);
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(find.text('愛車ページ'), findsOneWidget);
    });

    testWidgets('ページが無ければ、公開されていないと伝える', (tester) async {
      await pump(
          tester, Scaffold(body: PostVehicleChip(tag: tag, service: service)));
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(find.text('この車の愛車ページは公開されていません'), findsOneWidget);
    });
  });
}
