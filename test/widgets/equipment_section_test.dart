// EquipmentSection Widget Tests
//
// カバレッジ監査（docs/reports/TEST_EXECUTION_2026-08-09_draft.md §1.2）で
// 優先度・高とされたウィジェットテスト。
//
// 仕様の中心は「メーカー候補は補助でありゲートではない」こと:
// 候補シートから選んでも、候補に無い名前を直接入力しても、同じように
// VehicleEquipment へ反映されなければならない。
//
// Coverage:
//   - ナビ/ドラレコ/ETC のスイッチONでメーカー・型番欄が現れる
//   - メーカー候補シートから選択すると欄に入る／候補に無い名前を直接入力できる
//   - FilterChip の選択/解除が VehicleEquipment.features に反映される
//   - 「その他」読点区切りが others リストになる
//   - onChanged で受け取る VehicleEquipment の内容検証
//   - Edge Cases（未操作・型番のみ・スイッチON→OFFの値保持）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle_equipment.dart';
import 'package:trust_car_platform/widgets/vehicle/equipment_section.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// 実際の編集画面と同じ「controlled widget」パターンで EquipmentSection を
/// ホストする。onChanged で受けた値をそのまま value に戻し、履歴も記録する。
class _EquipmentHarness extends StatefulWidget {
  final VehicleEquipment initial;

  const _EquipmentHarness({this.initial = const VehicleEquipment()});

  @override
  State<_EquipmentHarness> createState() => _EquipmentHarnessState();
}

class _EquipmentHarnessState extends State<_EquipmentHarness> {
  late VehicleEquipment value;
  final List<VehicleEquipment> emitted = [];

  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return EquipmentSection(
      value: value,
      onChanged: (next) => setState(() {
        value = next;
        emitted.add(next);
      }),
    );
  }
}

const _navKey = Key('equipment_navigation');
const _recorderKey = Key('equipment_drive_recorder');
const _etcKey = Key('equipment_etc');
const _othersKey = Key('equipment_others');

Future<_EquipmentHarnessState> _pump(
  WidgetTester tester, {
  VehicleEquipment initial = const VehicleEquipment(),
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: _EquipmentHarness(initial: initial),
      ),
    ),
  ));
  return tester.state<_EquipmentHarnessState>(find.byType(_EquipmentHarness));
}

Finder _switchIn(Key cardKey) =>
    find.descendant(of: find.byKey(cardKey), matching: find.byType(Switch));

/// カード内のメーカー欄（1つ目）／型番欄（2つ目）。スイッチONのときのみ存在。
Finder _makerFieldIn(Key cardKey) => find
    .descendant(of: find.byKey(cardKey), matching: find.byType(TextFormField))
    .at(0);

Finder _modelFieldIn(Key cardKey) => find
    .descendant(of: find.byKey(cardKey), matching: find.byType(TextFormField))
    .at(1);

Future<void> _turnOn(WidgetTester tester, Key cardKey) async {
  await tester.tap(_switchIn(cardKey));
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EquipmentSection — スイッチと入力欄', () {
    testWidgets('初期状態ではメーカー・型番欄が出ない', (tester) async {
      await _pump(tester);

      expect(find.text('カーナビ'), findsOneWidget);
      expect(find.text('ドライブレコーダー'), findsOneWidget);
      expect(find.text('ETC車載器'), findsOneWidget);
      expect(find.text('メーカー（任意）'), findsNothing);
      expect(find.text('型番（任意）'), findsNothing);
    });

    testWidgets('ナビのスイッチONでメーカー・型番欄が現れ installed が伝わる', (tester) async {
      final state = await _pump(tester);

      await _turnOn(tester, _navKey);

      expect(state.value.navigation.installed, isTrue);
      expect(find.text('メーカー（任意）'), findsOneWidget);
      expect(find.text('型番（任意）'), findsOneWidget);
    });

    testWidgets('ドラレコのスイッチONで欄が現れる', (tester) async {
      final state = await _pump(tester);

      await _turnOn(tester, _recorderKey);

      expect(state.value.driveRecorder.installed, isTrue);
      expect(state.value.navigation.installed, isFalse);
      expect(state.value.etc.installed, isFalse);
      expect(find.text('メーカー（任意）'), findsOneWidget);
    });

    testWidgets('ETCのスイッチONで欄が現れる', (tester) async {
      final state = await _pump(tester);

      await _turnOn(tester, _etcKey);

      expect(state.value.etc.installed, isTrue);
      expect(find.text('メーカー（任意）'), findsOneWidget);
    });
  });

  group('メーカー・型番入力', () {
    testWidgets('候補シートから選択するとメーカー欄に入り値が伝わる', (tester) async {
      final state = await _pump(tester);
      await _turnOn(tester, _navKey);

      // メーカー欄の▼から候補シートを開く
      await tester.tap(find.descendant(
        of: find.byKey(_navKey),
        matching: find.byTooltip('候補から選ぶ'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('候補に無いメーカーは入力欄に直接書けます'), findsOneWidget);

      await tester.tap(find.text('カロッツェリア（パイオニア）'));
      await tester.pumpAndSettle();

      expect(state.value.navigation.maker, 'カロッツェリア（パイオニア）');
      expect(state.value.navigation.installed, isTrue);
      // シートは閉じ、フィールドに選択値が入っている
      expect(find.text('カロッツェリア（パイオニア）'), findsOneWidget);
    });

    testWidgets('候補に無いメーカー名を直接入力できる（候補はゲートではない）', (tester) async {
      final state = await _pump(tester);
      await _turnOn(tester, _recorderKey);

      await tester.enterText(_makerFieldIn(_recorderKey), '無名の海外ブランド');
      await tester.pump();

      expect(state.value.driveRecorder.maker, '無名の海外ブランド');
    });

    testWidgets('型番の入力が伝わる', (tester) async {
      final state = await _pump(tester);
      await _turnOn(tester, _recorderKey);

      await tester.enterText(_makerFieldIn(_recorderKey), 'コムテック');
      await tester.enterText(_modelFieldIn(_recorderKey), 'ZDR035');
      await tester.pump();

      expect(
        state.value.driveRecorder,
        const EquipmentItem(
          installed: true,
          maker: 'コムテック',
          modelNumber: 'ZDR035',
        ),
      );
    });
  });

  group('その他の装備（FilterChip）', () {
    testWidgets('チップ選択で features に追加される', (tester) async {
      final state = await _pump(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'バックカメラ'));
      await tester.pump();

      expect(state.value.features, {VehicleFeature.backCamera});
      final chip =
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'バックカメラ'));
      expect(chip.selected, isTrue);
    });

    testWidgets('選択済みチップの再タップで features から外れる', (tester) async {
      final state = await _pump(
        tester,
        initial: const VehicleEquipment(features: {VehicleFeature.backCamera}),
      );

      final chipFinder = find.widgetWithText(FilterChip, 'バックカメラ');
      expect(tester.widget<FilterChip>(chipFinder).selected, isTrue);

      await tester.tap(chipFinder);
      await tester.pump();

      expect(state.value.features, isEmpty);
      expect(tester.widget<FilterChip>(chipFinder).selected, isFalse);
    });

    testWidgets('複数チップの選択が累積する', (tester) async {
      final state = await _pump(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'サンルーフ'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'シートヒーター'));
      await tester.pump();

      expect(
        state.value.features,
        {VehicleFeature.sunroof, VehicleFeature.seatHeater},
      );
    });
  });

  group('その他（自由入力）', () {
    testWidgets('読点区切りの入力が others リストになる', (tester) async {
      final state = await _pump(tester);

      await tester.enterText(find.byKey(_othersKey), '社外マフラー、牽引フック');
      await tester.pump();

      expect(state.value.others, ['社外マフラー', '牽引フック']);
    });

    testWidgets('カンマ区切りも受け付け、空要素と前後の空白は除かれる', (tester) async {
      final state = await _pump(tester);

      await tester.enterText(find.byKey(_othersKey), ' 社外マフラー ,, 牽引フック、');
      await tester.pump();

      expect(state.value.others, ['社外マフラー', '牽引フック']);
    });

    testWidgets('初期値が読点区切りでプリフィルされる', (tester) async {
      await _pump(
        tester,
        initial: const VehicleEquipment(others: ['社外マフラー', '牽引フック']),
      );

      expect(find.text('社外マフラー、牽引フック'), findsOneWidget);
    });
  });

  group('onChanged 内容検証', () {
    testWidgets('一連の操作の結果が1つの VehicleEquipment に集約される', (tester) async {
      final state = await _pump(tester);

      await _turnOn(tester, _navKey);
      await tester.enterText(_makerFieldIn(_navKey), 'ATOTO');
      await tester.enterText(_modelFieldIn(_navKey), 'S8G2');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'サンルーフ'));
      await tester.pump();
      await tester.enterText(find.byKey(_othersKey), '社外マフラー、牽引フック');
      await tester.pump();

      expect(
        state.value,
        const VehicleEquipment(
          navigation: EquipmentItem(
            installed: true,
            maker: 'ATOTO',
            modelNumber: 'S8G2',
          ),
          features: {VehicleFeature.sunroof},
          others: ['社外マフラー', '牽引フック'],
        ),
      );
      expect(state.value.hasAnyValue, isTrue);
    });
  });

  group('Edge Cases', () {
    testWidgets('空のまま何も触らなければ onChanged は呼ばれない', (tester) async {
      final state = await _pump(tester);

      expect(state.emitted, isEmpty);
      expect(state.value.hasAnyValue, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('型番だけ入力したとき maker は null のまま', (tester) async {
      final state = await _pump(tester);
      await _turnOn(tester, _etcKey);

      await tester.enterText(_modelFieldIn(_etcKey), 'ETC2.0 対応品');
      await tester.pump();

      expect(state.value.etc.installed, isTrue);
      expect(state.value.etc.maker, isNull);
      expect(state.value.etc.modelNumber, 'ETC2.0 対応品');
    });

    testWidgets('空白のみのメーカー入力は未入力（null）として扱われる', (tester) async {
      final state = await _pump(tester);
      await _turnOn(tester, _navKey);

      await tester.enterText(_makerFieldIn(_navKey), '   ');
      await tester.pump();

      expect(state.value.navigation.maker, isNull);
      expect(state.value.navigation.installed, isTrue);
    });

    testWidgets('スイッチON→OFFでメーカー・型番は保持される（現仕様の固定）', (tester) async {
      final state = await _pump(tester);
      await _turnOn(tester, _navKey);

      await tester.enterText(_makerFieldIn(_navKey), '自作ナビ');
      await tester.enterText(_modelFieldIn(_navKey), 'X-100');
      await tester.pump();

      // OFF: 欄は隠れるが、入力済みの値は消えない
      await tester.tap(_switchIn(_navKey));
      await tester.pump();

      expect(
        state.value.navigation,
        const EquipmentItem(
          installed: false,
          maker: '自作ナビ',
          modelNumber: 'X-100',
        ),
      );
      expect(find.text('メーカー（任意）'), findsNothing);

      // 再ON: 前回の入力値が欄に残っている
      await tester.tap(_switchIn(_navKey));
      await tester.pump();

      expect(state.value.navigation.installed, isTrue);
      expect(find.text('自作ナビ'), findsOneWidget);
      expect(find.text('X-100'), findsOneWidget);
    });
  });
}
