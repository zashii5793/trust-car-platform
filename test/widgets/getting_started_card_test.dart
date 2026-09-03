// はじめてガイド。
//
// ログイン後に出るのは「まず愛車を登録しよう」だけで、その先に何をすれば
// アプリが役に立つのかが分からなかった。実データから完了を判定する
// チェックリストにして、終わったら黙って消えるようにする。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/widgets/getting_started_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

GettingStartedCard _card({
  bool hasVehicle = false,
  bool hasInspectionDate = false,
  bool hasMaintenanceRecord = false,
  VoidCallback? onRegisterVehicle,
  VoidCallback? onSetInspectionDate,
  VoidCallback? onAddMaintenance,
  VoidCallback? onDismiss,
}) {
  return GettingStartedCard(
    hasVehicle: hasVehicle,
    hasInspectionDate: hasInspectionDate,
    hasMaintenanceRecord: hasMaintenanceRecord,
    onRegisterVehicle: onRegisterVehicle ?? () {},
    onSetInspectionDate: onSetInspectionDate ?? () {},
    onAddMaintenance: onAddMaintenance ?? () {},
    onDismiss: onDismiss ?? () {},
  );
}

void main() {
  group('GettingStartedCard — 進み具合', () {
    testWidgets('3ステップが並ぶ', (tester) async {
      await tester.pumpWidget(_wrap(_card()));

      expect(find.byKey(const Key('getting_started_step_vehicle')),
          findsOneWidget);
      expect(find.byKey(const Key('getting_started_step_inspection')),
          findsOneWidget);
      expect(find.byKey(const Key('getting_started_step_maintenance')),
          findsOneWidget);
    });

    testWidgets('何もしていないと 0/3', (tester) async {
      await tester.pumpWidget(_wrap(_card()));

      expect(find.text('0 / 3'), findsOneWidget);
    });

    testWidgets('車両を登録すると 1/3', (tester) async {
      await tester.pumpWidget(_wrap(_card(hasVehicle: true)));

      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('車検日まで入れると 2/3', (tester) async {
      await tester.pumpWidget(
        _wrap(_card(hasVehicle: true, hasInspectionDate: true)),
      );

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('完了したステップにはチェックが付く', (tester) async {
      await tester.pumpWidget(_wrap(_card(hasVehicle: true)));

      final done = find.descendant(
        of: find.byKey(const Key('getting_started_step_vehicle')),
        matching: find.byIcon(Icons.check_circle),
      );
      expect(done, findsOneWidget);
    });

    testWidgets('未完了のステップにはチェックが付かない', (tester) async {
      await tester.pumpWidget(_wrap(_card(hasVehicle: true)));

      final notDone = find.descendant(
        of: find.byKey(const Key('getting_started_step_inspection')),
        matching: find.byIcon(Icons.check_circle),
      );
      expect(notDone, findsNothing);
    });
  });

  group('GettingStartedCard — 押した先', () {
    testWidgets('未完了のステップを押すとその操作へ進む', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_card(onRegisterVehicle: () => tapped = true)),
      );

      await tester.tap(find.byKey(const Key('getting_started_step_vehicle')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('車検日のステップも押せる', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_card(
        hasVehicle: true,
        onSetInspectionDate: () => tapped = true,
      )));

      await tester
          .tap(find.byKey(const Key('getting_started_step_inspection')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('整備記録のステップも押せる', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_card(
        hasVehicle: true,
        hasInspectionDate: true,
        onAddMaintenance: () => tapped = true,
      )));

      await tester
          .tap(find.byKey(const Key('getting_started_step_maintenance')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('完了済みのステップは押しても何も起きない', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_card(
        hasVehicle: true,
        onRegisterVehicle: () => tapped = true,
      )));

      await tester.tap(find.byKey(const Key('getting_started_step_vehicle')));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });

    testWidgets('閉じるボタンで消せる（急かされたくない人向け）', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(_wrap(_card(onDismiss: () => dismissed = true)));

      await tester.tap(find.byKey(const Key('getting_started_dismiss')));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });

  group('GettingStartedCard — Edge Cases', () {
    testWidgets('全部終わっていたら何も描かない', (tester) async {
      await tester.pumpWidget(_wrap(_card(
        hasVehicle: true,
        hasInspectionDate: true,
        hasMaintenanceRecord: true,
      )));

      expect(find.byKey(const Key('getting_started_card')), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('途中まで終わっていれば表示は続く', (tester) async {
      await tester.pumpWidget(_wrap(_card(
        hasVehicle: true,
        hasMaintenanceRecord: true,
      )));

      expect(find.byKey(const Key('getting_started_card')), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('順番を飛ばしても完了として数える', (tester) async {
      await tester.pumpWidget(_wrap(_card(hasMaintenanceRecord: true)));

      expect(find.text('1 / 3'), findsOneWidget);
    });
  });
}
