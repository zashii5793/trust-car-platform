// MileageReminderBanner Tests
//
// 「登録直後に走行距離の更新を催促される」バグの再発防止。
// 以前は mileageUpdatedAt が null のとき常に表示しており、たった今
// 距離を入力して登録したユーザーに「最終更新: 未設定」と出ていた。
// null のときは登録日（createdAt）を基準に判定する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/widgets/vehicle/mileage_reminder_banner.dart';

Vehicle _vehicle({DateTime? mileageUpdatedAt, DateTime? createdAt}) {
  final created = createdAt ?? DateTime.now();
  return Vehicle(
    id: 'v1',
    userId: 'u1',
    maker: 'トヨタ',
    model: 'プリウス',
    year: 2021,
    grade: 'S',
    mileage: 30000,
    mileageUpdatedAt: mileageUpdatedAt,
    createdAt: created,
    updatedAt: created,
  );
}

Future<void> _pump(WidgetTester tester, Vehicle vehicle) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MileageReminderBanner(vehicle: vehicle, onTapUpdate: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('登録直後（mileageUpdatedAt null・登録も今日）は表示しない', (tester) async {
    // 登録フォームで距離を入力した直後に催促しない。これがバグの本体。
    await _pump(tester, _vehicle());
    expect(find.textContaining('走行距離を更新'), findsNothing);
  });

  testWidgets('最終更新が30日以上前なら表示する', (tester) async {
    await _pump(
      tester,
      _vehicle(
        mileageUpdatedAt: DateTime.now().subtract(const Duration(days: 31)),
      ),
    );
    expect(find.textContaining('走行距離を更新'), findsOneWidget);
    expect(find.textContaining('31日前'), findsOneWidget);
  });

  testWidgets('mileageUpdatedAt が無い旧データは登録日を基準にする', (tester) async {
    // 導入前に登録された車両で null が残っていても、永遠に催促し続けない。
    await _pump(
      tester,
      _vehicle(
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
    );
    expect(find.textContaining('走行距離を更新'), findsOneWidget);
  });

  group('Edge Cases', () {
    testWidgets('29日前は表示しない（境界）', (tester) async {
      await _pump(
        tester,
        _vehicle(
          mileageUpdatedAt: DateTime.now().subtract(const Duration(days: 29)),
        ),
      );
      expect(find.textContaining('走行距離を更新'), findsNothing);
    });

    testWidgets('ちょうど30日で表示する（境界）', (tester) async {
      await _pump(
        tester,
        _vehicle(
          mileageUpdatedAt:
              DateTime.now().subtract(const Duration(days: 30, minutes: 1)),
        ),
      );
      expect(find.textContaining('走行距離を更新'), findsOneWidget);
    });
  });
}
