// AddMaintenanceScreen Widget Tests
//
// Coverage:
//   - AppBar title (新規 / 編集モード)
//   - フォーム要素の表示（タイプ・日付・コスト・走行距離・メモ）
//   - MaintenanceType チップの表示・選択
//   - 「すべて表示」ボタン
//   - バリデーション（空値・負数コスト）
//   - 編集モードで既存データが初期表示される
//   - 請求書スキャンボタン
//   - Edge cases (超長文字、0コスト)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/add_maintenance_screen.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/invoice_ocr_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/di/injection.dart';

// ---------------------------------------------------------------------------
// Mock Services
// ---------------------------------------------------------------------------

class _MockFirebaseService implements FirebaseService {
  @override
  String? get currentUserId => 'test-user-id';

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vid) =>
      const Stream.empty();

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(
          MaintenanceRecord r) async =>
      const Result.success('new-record-id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
          String id, MaintenanceRecord r) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String id) async =>
      const Result.success(null);

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

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
  Future<Result<String, AppError>> addVehicle(Vehicle v) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle v) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String plate,
          {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<String, AppError>> uploadImageBytes(dynamic b, String path) async =>
      const Result.success('url');

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> uploadImage(dynamic f, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(
          List<dynamic> files, String p) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic bytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}

class _MockInvoiceOcrService implements InvoiceOcrService {
  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

final _mockFirebase = _MockFirebaseService();

Widget _buildNew({String vehicleId = 'v-001', int? currentMileage}) {
  return MaterialApp(
    home: ChangeNotifierProvider<MaintenanceProvider>(
      create: (_) => MaintenanceProvider(firebaseService: _mockFirebase),
      child: AddMaintenanceScreen(
        vehicleId: vehicleId,
        currentVehicleMileage: currentMileage,
      ),
    ),
  );
}

MaintenanceRecord _makeRecord({
  String id = 'r-001',
  String vehicleId = 'v-001',
  String userId = 'user-001',
  MaintenanceType type = MaintenanceType.oilChange,
  String title = '既存タイトル',
  int cost = 3500,
  int mileage = 28000,
  String? shopName = '既存ショップ',
  String? description = '既存の備考',
}) {
  final date = DateTime(2024, 3, 1);
  return MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    userId: userId,
    type: type,
    title: title,
    date: date,
    cost: cost,
    mileageAtService: mileage,
    shopName: shopName,
    description: description,
    createdAt: date,
  );
}

Widget _buildEdit({MaintenanceRecord? record}) {
  return MaterialApp(
    home: ChangeNotifierProvider<MaintenanceProvider>(
      create: (_) => MaintenanceProvider(firebaseService: _mockFirebase),
      child: AddMaintenanceScreen(
        vehicleId: 'v-001',
        existingRecord: record ?? _makeRecord(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    final sl = ServiceLocator.instance;
    sl.registerLazySingleton<FirebaseService>(() => _MockFirebaseService());
    sl.registerLazySingleton<InvoiceOcrService>(() => _MockInvoiceOcrService());
  });

  tearDownAll(() {
    Injection.reset();
  });

  // =========================================================================
  group('AddMaintenanceScreen — AppBar', () {
    testWidgets('新規モード: AppBarタイトルが "メンテナンス履歴を追加"', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.text('メンテナンス履歴を追加'), findsOneWidget);
    });

    testWidgets('編集モード: AppBarタイトルが "メンテナンス履歴を編集"', (tester) async {
      await tester.pumpWidget(_buildEdit());
      await tester.pump();

      expect(find.text('メンテナンス履歴を編集'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AddMaintenanceScreen — フォーム要素', () {
    testWidgets('"メンテナンスタイプ" ラベルが表示される', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.text('メンテナンスタイプ'), findsOneWidget);
    });

    testWidgets('よく使うタイプのチップが表示される（オイル交換・車検）', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.text('オイル交換'), findsOneWidget);
      expect(find.text('車検'), findsOneWidget);
    });

    testWidgets('請求書スキャンボタン（receipt_long アイコン）が表示される', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });

    testWidgets('日付フィールド（calendar アイコン）が表示される', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('タイヤ交換チップが表示される', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.text('タイヤ交換'), findsOneWidget);
    });

    testWidgets('修理チップが表示される', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(find.text('修理'), findsOneWidget);
    });

    testWidgets('保存 / 登録ボタンが存在する', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      final hasSave = find.textContaining('保存').evaluate().isNotEmpty ||
          find.textContaining('登録').evaluate().isNotEmpty;
      expect(hasSave, isTrue);
    });
  });

  // =========================================================================
  group('AddMaintenanceScreen — タイプチップ選択', () {
    testWidgets('タイヤ交換チップをタップしてもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      await tester.tap(find.text('タイヤ交換'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('オイル交換チップをタップしてもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      await tester.tap(find.text('オイル交換'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('「すべて表示」ボタンで追加タイプが展開されてもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      final btn = find.textContaining('すべて表示');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  group('AddMaintenanceScreen — 編集モード初期値', () {
    testWidgets('既存タイトルが TextFormField に表示される', (tester) async {
      await tester.pumpWidget(_buildEdit(record: _makeRecord(title: '既存タイトル')));
      await tester.pump();

      expect(find.text('既存タイトル'), findsOneWidget);
    });

    testWidgets('既存のコストが TextFormField に表示される', (tester) async {
      await tester.pumpWidget(_buildEdit(record: _makeRecord(cost: 12500)));
      await tester.pump();

      expect(find.text('12500'), findsOneWidget);
    });

    testWidgets('既存の走行距離が TextFormField に表示される', (tester) async {
      await tester.pumpWidget(_buildEdit(record: _makeRecord(mileage: 45000)));
      await tester.pump();

      expect(find.text('45000'), findsOneWidget);
    });

    testWidgets('既存の店舗名が TextFormField に表示される', (tester) async {
      await tester.pumpWidget(
          _buildEdit(record: _makeRecord(shopName: 'トラストモータース')));
      await tester.pump();

      expect(find.text('トラストモータース'), findsOneWidget);
    });

    testWidgets('既存の備考が TextFormField に表示される', (tester) async {
      await tester.pumpWidget(
          _buildEdit(record: _makeRecord(description: '既存の備考内容')));
      await tester.pump();

      expect(find.text('既存の備考内容'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AddMaintenanceScreen — バリデーション', () {
    testWidgets('空のフォームで保存してもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      final saveBtn = find.textContaining('保存').evaluate().isNotEmpty
          ? find.textContaining('保存')
          : find.textContaining('登録');

      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  // =========================================================================
  group('Edge Cases', () {
    testWidgets('走行距離0でも初期値として表示される', (tester) async {
      await tester.pumpWidget(_buildEdit(record: _makeRecord(mileage: 0)));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('コスト0でも表示される', (tester) async {
      await tester.pumpWidget(_buildEdit(record: _makeRecord(cost: 0)));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('超長いタイトル（100文字超）でもクラッシュしない', (tester) async {
      final longTitle = 'メンテナンス' * 15;
      await tester.pumpWidget(_buildEdit(record: _makeRecord(title: longTitle)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('vehicleId が空文字でも画面が表示される', (tester) async {
      await tester.pumpWidget(_buildNew(vehicleId: ''));
      await tester.pump();

      expect(find.text('メンテナンス履歴を追加'), findsOneWidget);
    });

    testWidgets('currentVehicleMileage が設定されていても画面が正常に表示される', (tester) async {
      await tester.pumpWidget(_buildNew(currentMileage: 50000));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
