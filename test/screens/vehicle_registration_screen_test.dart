// VehicleRegistrationScreen Widget Tests
//
// 3-step wizard coverage:
//   Step 1 — 基本情報:
//     1.  AppBar title '基本情報を入力'
//     2.  Step indicator labels (基本情報 / 車検・保険 / 詳細情報)
//     3.  OCR scan button '車検証をスキャンして自動入力' visible
//     4.  Photo picker '車両の写真を追加（任意）' visible
//     5.  '次へ' button visible
//     6.  Maker selector placeholder 'メーカーを選択 *' visible
//   Validation (Step 1):
//     7.  Tapping '次へ' with empty fields shows 'メーカーを選択してください'
//     8.  Tapping '次へ' with empty fields shows '車種を選択してください'
//     9.  Tapping '次へ' with empty fields shows '年式を入力'
//    10.  Tapping '次へ' with empty fields shows '走行距離を入力してください'
//    11.  Title unchanged (step still 0) when validation fails
//    12.  Mileage validation: negative value → error
//    13.  Year validation: year < 1900 → error
//   Step 2 — 車検・保険:
//    14.  AppBar title '車検・保険の情報' after navigating
//    15.  '戻る' button appears
//    16.  '車検満了日' tile visible
//    17.  '自賠責保険期限' tile visible
//    18.  'ナンバープレート' field visible
//    19.  Notification banner visible
//   Step 3 — 詳細情報:
//    20.  AppBar title '詳細情報（任意）' after navigating to step 3
//    21.  '登録する' button visible
//    22.  Optional badge 'すべて任意入力です' visible
//    23.  '燃料タイプ' section visible
//    24.  '車台番号' field visible
//   Back navigation:
//    25.  Back arrow in AppBar (step > 0) goes to previous wizard step
//   Discard dialog:
//    26.  Entering year makes state dirty → dialog appears on back press
//    27.  '続ける' dismisses dialog, wizard stays
//    28.  '中断する' pops the screen
//   Registration:
//    29.  Success → snackbar '車両を登録しました'
//    30.  addVehicle failure → error snackbar

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:trust_car_platform/screens/vehicle_registration_screen.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/vehicle_master_service.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ===========================================================================
// Test fixtures
// ===========================================================================

const _testMaker = VehicleMaker(
  id: 'maker-1',
  name: 'トヨタ',
  nameEn: 'Toyota',
  country: 'JP',
);

const _testModel = VehicleModel(
  id: 'model-1',
  makerId: 'maker-1',
  name: 'プリウス',
);

const _testGrade = VehicleGrade(
  id: 'grade-1',
  modelId: 'model-1',
  name: 'S',
);

// ===========================================================================
// Stub — VehicleMasterService
// ===========================================================================

class _StubMasterService implements VehicleMasterService {
  @override
  Future<Result<List<VehicleMaker>, AppError>> getMakers() async =>
      const Result.success([_testMaker]);

  @override
  Future<Result<List<VehicleModel>, AppError>> getModelsForMaker(
          String makerId) async =>
      const Result.success([_testModel]);

  @override
  Future<Result<List<VehicleGrade>, AppError>> getGradesForModel(
          String modelId) async =>
      const Result.success([_testGrade]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ===========================================================================
// Stub — FirebaseService
// ===========================================================================

class _StubFirebaseService implements FirebaseService {
  bool addVehicleShouldFail = false;

  @override
  String? get currentUserId => 'test-uid';

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle v) async {
    if (addVehicleShouldFail) {
      return const Result.failure(AppError.server('save error'));
    }
    return const Result.success('new-vehicle-id');
  }

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String plate,
          {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<String, AppError>> uploadImageBytes(
          Uint8List bytes, String path) async =>
      const Result.success('https://example.com/image.jpg');

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle v) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(
          MaintenanceRecord r) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
          String id, MaintenanceRecord r) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String id) async =>
      const Result.success(null);

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vid) =>
      const Stream.empty();

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>>
      getMaintenanceRecordsForVehicles(List<String> ids,
              {int limitPerVehicle = 20}) async =>
          const Result.success({});

  @override
  Future<Result<List<MaintenanceRecord>, AppError>>
      getMaintenanceRecordsForVehicle(String vehicleId,
              {int limit = 20}) async =>
          const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadImage(dynamic f, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(
          List<dynamic> files, String p) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(dynamic bytes,
          String path, {required dynamic imageService}) async =>
      const Result.success('url');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ===========================================================================
// Stub — VehicleCertificateOcrService
// ===========================================================================

class _StubOcrService implements VehicleCertificateOcrService {
  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ===========================================================================
// Fake VehicleProvider
// ===========================================================================

late _StubFirebaseService _firebaseStub;

class _FakeVehicleProvider extends VehicleProvider {
  _FakeVehicleProvider() : super(firebaseService: _firebaseStub);

  @override
  Future<bool> addVehicle(Vehicle vehicle) async {
    final result = await _firebaseStub.addVehicle(vehicle);
    return result.isSuccess;
  }

  @override
  Future<bool> isLicensePlateExists(String licensePlate,
      {String? excludeVehicleId}) async =>
      false;
}

// ===========================================================================
// Widget builder
// ===========================================================================

Widget _buildScreen() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VehicleProvider>.value(
          value: _FakeVehicleProvider()),
    ],
    child: const MaterialApp(
      home: VehicleRegistrationScreen(),
    ),
  );
}

// ===========================================================================
// Step 1 navigation helper:
// Selects maker → model → grade, enters year + mileage, taps 次へ.
// After this, the wizard is on step 2.
// ===========================================================================

Future<void> _fillStep1AndAdvance(WidgetTester tester) async {
  // Wait for maker loading
  await tester.pumpAndSettle();

  // Select maker
  await tester.tap(find.text('メーカーを選択 *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('トヨタ'));
  await tester.pumpAndSettle();

  // Select model (loads after maker selection)
  await tester.tap(find.text('車種を選択 *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('プリウス'));
  await tester.pumpAndSettle();

  // Select grade (loads after model selection)
  await tester.tap(find.text('グレードを選択 *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('S'));
  await tester.pumpAndSettle();

  // Enter year and mileage (TextFormField[0]=year, TextFormField[1]=mileage)
  await tester.enterText(find.byType(TextFormField).at(0), '2023');
  await tester.enterText(find.byType(TextFormField).at(1), '15000');
  await tester.pump();

  // Tap 次へ
  await tester.tap(find.text('次へ'));
  await tester.pumpAndSettle();
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  setUpAll(() {
    _firebaseStub = _StubFirebaseService();
    ServiceLocator.instance
      ..override<VehicleMasterService>(_StubMasterService())
      ..override<VehicleCertificateOcrService>(_StubOcrService())
      ..override<FirebaseService>(_firebaseStub);
  });

  tearDownAll(() {
    Injection.reset();
  });

  setUp(() {
    _firebaseStub = _StubFirebaseService();
    ServiceLocator.instance.override<FirebaseService>(_firebaseStub);
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Step 1 AppBar', () {
    testWidgets('1. AppBar title shows 「基本情報を入力」', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('基本情報を入力'), findsOneWidget);
    });

    testWidgets('2a. No back arrow on step 0 (leading is null)', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // Leading is null on step 0 — no IconButton in AppBar
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, isNull);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Step indicator', () {
    testWidgets('2b. Step indicator shows 「基本情報」label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('基本情報'), findsOneWidget);
    });

    testWidgets('2c. Step indicator shows 「車検・保険」label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('車検・保険'), findsOneWidget);
    });

    testWidgets('2d. Step indicator shows 「詳細情報」label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('詳細情報'), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Step 1 content', () {
    testWidgets('3. OCR scan button visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('車検証をスキャンして自動入力'), findsOneWidget);
    });

    testWidgets('4. Photo picker label visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('車両の写真を追加（任意）'), findsOneWidget);
    });

    testWidgets('5. 「次へ」button visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('次へ'), findsOneWidget);
    });

    testWidgets('6. Maker selector placeholder visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(); // wait for makers to load

      expect(find.text('メーカーを選択 *'), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Validation (Step 1)', () {
    testWidgets('7. Tapping 次へ with empty maker shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('メーカーを選択してください'), findsOneWidget);
    });

    testWidgets('8. Tapping 次へ with empty model shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('車種を選択してください'), findsOneWidget);
    });

    testWidgets('9. Tapping 次へ with empty year shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('年式を入力'), findsOneWidget);
    });

    testWidgets('10. Tapping 次へ with empty mileage shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('走行距離を入力してください'), findsOneWidget);
    });

    testWidgets('11. Title unchanged when validation fails (stays step 1)',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // Still on step 1
      expect(find.text('基本情報を入力'), findsOneWidget);
    });

    testWidgets('12. Negative mileage shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), '-1');
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('正しい走行距離を入力してください'), findsOneWidget);
    });

    testWidgets('13. Year < 1900 shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '1800');
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('正しい年式'), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Step 2 (車検・保険)', () {
    testWidgets('14. AppBar title changes to 「車検・保険の情報」', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);

      expect(find.text('車検・保険の情報'), findsOneWidget);
    });

    testWidgets('15. 「戻る」button appears on step 2', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);

      expect(find.text('戻る'), findsOneWidget);
    });

    testWidgets('16. 「車検満了日」tile visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);

      expect(find.text('車検満了日'), findsOneWidget);
    });

    testWidgets('17. 「自賠責保険期限」tile visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);

      expect(find.text('自賠責保険期限'), findsOneWidget);
    });

    testWidgets('18. 「ナンバープレート」field visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);

      expect(find.text('ナンバープレート'), findsOneWidget);
    });

    testWidgets('19. Notification banner visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);

      expect(
          find.textContaining('期限が近づくと自動でアプリが通知します'), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Step 3 (詳細情報)', () {
    Future<void> navigateToStep3(WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester); // → step 2
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle(); // → step 3
    }

    testWidgets('20. AppBar title changes to 「詳細情報（任意）」', (tester) async {
      await navigateToStep3(tester);
      expect(find.text('詳細情報（任意）'), findsOneWidget);
    });

    testWidgets('21. 「登録する」button visible', (tester) async {
      await navigateToStep3(tester);
      expect(find.text('登録する'), findsOneWidget);
    });

    testWidgets('22. Optional badge visible', (tester) async {
      await navigateToStep3(tester);
      expect(find.textContaining('すべて任意入力です'), findsOneWidget);
    });

    testWidgets('23. 「燃料タイプ」section visible', (tester) async {
      await navigateToStep3(tester);
      expect(find.text('燃料タイプ'), findsOneWidget);
    });

    testWidgets('24. 「車台番号」field visible', (tester) async {
      await navigateToStep3(tester);
      expect(find.text('車台番号'), findsOneWidget);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Back navigation', () {
    testWidgets('25. AppBar back arrow returns to step 1', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester); // → step 2

      // Tap AppBar back arrow
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should be back on step 1
      expect(find.text('基本情報を入力'), findsOneWidget);
      // 戻る button gone
      expect(find.text('戻る'), findsNothing);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Discard dialog', () {
    testWidgets('26. Entering year makes state dirty → back triggers dialog',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Make dirty by entering year
      await tester.enterText(find.byType(TextFormField).at(0), '2023');
      await tester.pump();

      // Trigger system back
      final NavigatorState navigator =
          tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('登録を中断しますか？'), findsOneWidget);
    });

    testWidgets('27. Tapping 続ける dismisses dialog, wizard stays',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '2023');
      await tester.pump();

      final NavigatorState navigator =
          tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('続ける'));
      await tester.pumpAndSettle();

      // Dialog dismissed, still on registration screen
      expect(find.text('登録を中断しますか？'), findsNothing);
      expect(find.text('基本情報を入力'), findsOneWidget);
    });

    testWidgets('28. Tapping 中断する pops the screen', (tester) async {
      // Wrap in a Navigator with a home route so popping is observable
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VehicleProvider>.value(
                value: _FakeVehicleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(body: const Text('Home')),
            onGenerateRoute: (settings) {
              if (settings.name == '/register') {
                return MaterialPageRoute(
                  builder: (_) => const VehicleRegistrationScreen(),
                );
              }
              return null;
            },
          ),
        ),
      );

      // Push registration screen
      final NavigatorState navigator =
          tester.state(find.byType(Navigator));
      navigator.pushNamed('/register');
      await tester.pumpAndSettle();

      // Make dirty
      await tester.enterText(find.byType(TextFormField).at(0), '2023');
      await tester.pump();

      // System back
      navigator.maybePop();
      await tester.pumpAndSettle();

      // Tap 中断する
      await tester.tap(find.text('中断する'));
      await tester.pumpAndSettle();

      // Screen popped — back on home
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('基本情報を入力'), findsNothing);
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Registration', () {
    Future<void> navigateToStep3(WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await _fillStep1AndAdvance(tester);
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }

    testWidgets('29. Success → snackbar 「車両を登録しました」', (tester) async {
      await navigateToStep3(tester);

      await tester.tap(find.text('登録する'));
      await tester.pumpAndSettle();

      expect(find.text('車両を登録しました'), findsOneWidget);
    });

    testWidgets('30. addVehicle failure → error snackbar shown', (tester) async {
      _firebaseStub.addVehicleShouldFail = true;

      await navigateToStep3(tester);

      await tester.tap(find.text('登録する'));
      await tester.pumpAndSettle();

      // Shows the error snackbar (サーバーエラーが発生しました or 登録に失敗しました)
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SnackBar ||
              (w is Text &&
                  (w.data?.contains('エラー') == true ||
                      w.data?.contains('失敗') == true)),
        ),
        findsWidgets,
      );
    });
  });

  // =========================================================================
  group('VehicleRegistrationScreen — Edge cases', () {
    testWidgets('no crash on initial render', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('mileage 0 is valid (boundary value)', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Enter 0 mileage
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // Should NOT show mileage range error (0 is valid, ≥ 0)
      expect(find.text('正しい走行距離を入力してください'), findsNothing);
    });
  });
}
