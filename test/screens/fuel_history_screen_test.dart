// FuelHistoryScreen のテスト
//
// 給油は記録できるのに振り返る場所が無かった（2026-09-08 に追加）。
// ここでは「溜めた記録が読めること」と「燃費が出ること」を確かめる。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/fuel/fuel_history_screen.dart';
import 'package:trust_car_platform/services/fuel_service.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';

import '../golden/font_loader.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FuelService service;

  Future<void> addRecord({
    required String id,
    required DateTime date,
    required double liters,
    required int cost,
    int? odometer,
    bool isFullTank = true,
    String userId = 'u1',
    String vehicleId = 'v1',
  }) async {
    await firestore.collection('fuel_records').doc(id).set({
      'vehicleId': vehicleId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'liters': liters,
      'cost': cost,
      if (odometer != null) 'odometer': odometer,
      'isFullTank': isFullTank,
      'createdAt': Timestamp.fromDate(date),
    });
  }

  Widget buildScreen() => MaterialApp(
        home: FuelHistoryScreen(
          service: service,
          vehicleId: 'v1',
          userId: 'u1',
          vehicleName: 'トヨタ ハイエース',
          currentOdometer: 45000,
        ),
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = FuelService(firestore: firestore);
  });

  testWidgets('溜めた記録が新しい順に並ぶ', (tester) async {
    await addRecord(
        id: 'f1',
        date: DateTime(2026, 6, 1),
        liters: 40,
        cost: 7000,
        odometer: 30000);
    await addRecord(
        id: 'f2',
        date: DateTime(2026, 7, 1),
        liters: 40,
        cost: 7100,
        odometer: 30600);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('2026/07/01'), findsOneWidget);
    expect(find.text('2026/06/01'), findsOneWidget);
    expect(find.text('¥7,100'), findsOneWidget);
  });

  testWidgets('平均燃費と1kmあたりの金額が出る', (tester) async {
    await addRecord(
        id: 'f1',
        date: DateTime(2026, 6, 1),
        liters: 40,
        cost: 7000,
        odometer: 30000);
    await addRecord(
        id: 'f2',
        date: DateTime(2026, 7, 1),
        liters: 40,
        cost: 7100,
        odometer: 30600);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // 600km を 40L → 15.0km/L。
    expect(find.text('15.0 km/L'), findsWidgets);
    expect(find.text('給油'), findsOneWidget);
    expect(find.text('2回'), findsOneWidget);
    expect(find.text('¥14,100'), findsOneWidget);
  });

  testWidgets('満タンでない回は「継ぎ足し」と分かる', (tester) async {
    await addRecord(
        id: 'f1',
        date: DateTime(2026, 6, 1),
        liters: 40,
        cost: 7000,
        odometer: 30000);
    await addRecord(
      id: 'f2',
      date: DateTime(2026, 6, 15),
      liters: 10,
      cost: 1750,
      odometer: 30200,
      isFullTank: false,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('継ぎ足し'), findsOneWidget);
  });

  testWidgets('記録が無ければ、記録するボタンを出す', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('まだ給油の記録がありません'), findsOneWidget);
    expect(find.text('給油を記録する'), findsOneWidget);
  });

  group('Edge Cases', () {
    testWidgets('他のユーザーの記録は出さない', (tester) async {
      await addRecord(
        id: 'mine',
        date: DateTime(2026, 6, 1),
        liters: 40,
        cost: 7000,
        odometer: 30000,
      );
      await addRecord(
        id: 'theirs',
        date: DateTime(2026, 7, 1),
        liters: 40,
        cost: 99999,
        odometer: 30600,
        userId: 'u2',
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('¥99,999'), findsNothing);
      expect(find.text('1回'), findsOneWidget);
    });

    testWidgets('走行距離が無ければ燃費の欄は「—」', (tester) async {
      await addRecord(
          id: 'f1', date: DateTime(2026, 6, 1), liters: 40, cost: 7000);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('—'), findsWidgets);
    });

    testWidgets('別の車の記録は混ざらない', (tester) async {
      await addRecord(
        id: 'other-car',
        date: DateTime(2026, 6, 1),
        liters: 40,
        cost: 12345,
        vehicleId: 'v2',
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('まだ給油の記録がありません'), findsOneWidget);
    });
  });

  // 1年ぶんの記録が並んだ状態を画像に残す。CI では走らない（tags: 'golden'）。
  group('ゴールデン', () {
    setUpAll(() async {
      await loadMaterialIcons();
      await loadJapaneseFont();
    });

    testWidgets('給油の記録（1年ぶん）', (tester) async {
      // 月1〜2回の給油を1年ぶん。オドメーターは 15,000km/年 のペース。
      var odo = 30000;
      for (var i = 0; i < 14; i++) {
        odo += 520 + (i % 3) * 40;
        await addRecord(
          id: 'f$i',
          date: DateTime(2025, 9, 15).add(Duration(days: 26 * i)),
          liters: 38 + (i % 4).toDouble(),
          cost: 6400 + (i % 5) * 210,
          odometer: odo,
          isFullTank: i != 5,
        );
      }

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        theme: goldenTheme(AppTheme.lightTheme),
        debugShowCheckedModeBanner: false,
        home: FuelHistoryScreen(
          service: service,
          vehicleId: 'v1',
          userId: 'u1',
          vehicleName: 'トヨタ ハイエース',
          currentOdometer: odo,
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../golden/goldens/screen_fuel_history.png'),
      );
    }, tags: 'golden');
  });
}
