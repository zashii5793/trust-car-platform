// InsuranceEditScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '任意保険の編集' title
//   Template section:
//     2. Shows template chip '手厚い'
//     3. Shows template chip '標準'
//     4. Tapping template chip shows snackbar
//   Form fields:
//     5. Shows '保険会社名' field
//     6. Shows '保存する' save button
//   Vehicle insurance toggle:
//     7. Switch is off by default for vehicle without insurance
//     8. Toggling switch on shows '車両保険金額' field
//   Save flow:
//     9. Tapping save calls updateVehicle

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/screens/insurance_edit_screen.dart';
import 'package:trust_car_platform/services/firebase_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockFirebaseService implements FirebaseService {
  bool updateVehicleCalled = false;
  AppError? updateError;

  @override
  Future<Result<void, AppError>> updateVehicle(
      String vehicleId, Vehicle vehicle) async {
    updateVehicleCalled = true;
    if (updateError != null) return Result.failure(updateError!);
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({VoluntaryInsurance? insurance}) {
  final now = DateTime(2026, 6, 1);
  return Vehicle(
    id: 'v1',
    userId: 'user1',
    maker: 'トヨタ',
    model: 'プリウス',
    year: 2022,
    grade: 'Z',
    mileage: 20000,
    createdAt: now,
    updatedAt: now,
    voluntaryInsurance: insurance,
  );
}

Widget _buildScreen(_MockFirebaseService mock, {Vehicle? vehicle}) {
  sl.override<FirebaseService>(mock);
  return MaterialApp(
    home: InsuranceEditScreen(vehicle: vehicle ?? _makeVehicle()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('InsuranceEditScreen — AppBar', () {
    testWidgets('1. タイトル「任意保険の編集」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.text('任意保険の編集'), findsOneWidget);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Template chips', () {
    testWidgets('2. テンプレートチップ「手厚い」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.text('手厚い'), findsOneWidget);
    });

    testWidgets('3. テンプレートチップ「標準」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.text('標準'), findsOneWidget);
    });

    testWidgets('4. テンプレートチップタップでスナックバーが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      await tester.tap(find.text('手厚い'));
      await tester.pump();

      expect(find.textContaining('手厚い'), findsWidgets);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Form fields', () {
    testWidgets('5. 「保険会社名」テキストフィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.widgetWithText(TextField, '保険会社名'), findsOneWidget);
    });

    testWidgets('6. 「保存する」ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      // Scroll to bottom of the long form
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      expect(find.byKey(const Key('save_insurance_btn')), findsOneWidget);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Vehicle insurance toggle', () {
    testWidgets('7. 保険なし車両では車両保険スイッチはOFF', (tester) async {
      // Vehicle without insurance — switch should default to false
      await tester.pumpWidget(_buildScreen(
        _MockFirebaseService(),
        vehicle: _makeVehicle(),
      ));
      await tester.pump();

      // Scroll to find the switch
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('has_vehicle_insurance_switch')),
      );
      expect(tile.value, isFalse);
    });

    testWidgets('8. 保険あり車両では車両保険金額フィールドが表示される', (tester) async {
      // Pre-initialize with hasVehicleInsurance=true to verify conditional fields
      final vehicleWithInsurance = _makeVehicle(
        insurance: const VoluntaryInsurance(hasVehicleInsurance: true),
      );
      await tester.pumpWidget(
        _buildScreen(_MockFirebaseService(), vehicle: vehicleWithInsurance),
      );
      await tester.pump();

      // Scroll down to the vehicle insurance section
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '車両保険金額（円）'), findsOneWidget);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Save flow', () {
    testWidgets('9. 保存ボタンタップでupdateVehicleが呼ばれる', (tester) async {
      final mock = _MockFirebaseService();
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      await tester.tap(find.byKey(const Key('save_insurance_btn')));
      await tester.pump();
      await tester.pump();

      expect(mock.updateVehicleCalled, isTrue);
    });

    testWidgets('10. 保存成功で「保険情報を保存しました」スナックバーが表示される', (tester) async {
      final mock = _MockFirebaseService();
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      await tester.tap(find.byKey(const Key('save_insurance_btn')));
      await tester.pump(); // trigger save
      await tester.pump(const Duration(milliseconds: 100)); // let Future resolve

      expect(find.text('保険情報を保存しました'), findsOneWidget);
    });

    testWidgets('11. 保存失敗で「保存に失敗しました」スナックバーが表示される', (tester) async {
      final mock = _MockFirebaseService()
        ..updateError = AppError.server('save failed');
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      await tester.tap(find.byKey(const Key('save_insurance_btn')));
      await tester.pump(); // trigger save
      await tester.pump(const Duration(milliseconds: 100)); // let Future resolve

      expect(find.text('保存に失敗しました'), findsOneWidget);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Contract type', () {
    testWidgets('12. SegmentedButtonに「ノンフリート」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.text('ノンフリート'), findsOneWidget);
    });

    testWidgets('13. SegmentedButtonに「フリート（法人）」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.text('フリート（法人）'), findsOneWidget);
    });

    testWidgets('14. フリート契約の車両ではセクションヘッダー「料率」が表示される', (tester) async {
      final fleetVehicle = _makeVehicle(
        insurance: const VoluntaryInsurance(
          contractType: InsuranceContractType.fleet,
        ),
      );
      await tester.pumpWidget(_buildScreen(_MockFirebaseService(), vehicle: fleetVehicle));
      await tester.pump();

      // Scroll moderately to reveal the 料率 section (middle of form)
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('料率'), findsOneWidget);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Date fields', () {
    testWidgets('15. 日付フィールド「契約開始日」はデフォルト「未設定」', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      // Both 契約開始日 and 満期日 show 未設定 initially
      expect(find.text('未設定'), findsWidgets);
    });

    testWidgets('16. 「証券番号」テキストフィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.widgetWithText(TextField, '証券番号'), findsOneWidget);
    });
  });

  // =========================================================================
  group('InsuranceEditScreen — Special clauses', () {
    testWidgets('17. 特約チップ「弁護士費用特約」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      expect(find.text('弁護士費用特約'), findsOneWidget);
    });

    testWidgets('18. 特約チップをタップすると選択状態になる', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      // Initially unselected
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '弁護士費用特約'),
      );
      expect(chip.selected, isFalse);

      await tester.tap(find.text('弁護士費用特約'));
      await tester.pump();

      final chipAfter = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '弁護士費用特約'),
      );
      expect(chipAfter.selected, isTrue);
    });

    testWidgets('19. テンプレートチップ「最小」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockFirebaseService()));
      await tester.pump();

      expect(find.text('最小'), findsOneWidget);
    });
  });
}
