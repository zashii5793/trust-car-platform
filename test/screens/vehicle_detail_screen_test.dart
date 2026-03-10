// ignore_for_file: avoid_implementing_value_types

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/screens/vehicle_detail_screen.dart';
import 'package:trust_car_platform/services/firebase_service.dart';

// ---------------------------------------------------------------------------
// Mock FirebaseService
// ---------------------------------------------------------------------------

class MockFirebaseService implements FirebaseService {
  final StreamController<List<MaintenanceRecord>> _recordsController =
      StreamController<List<MaintenanceRecord>>.broadcast();

  bool deleteWasCalled = false;
  String? lastDeletedId;

  @override
  String? get currentUserId => 'test-user-id';

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(
          String vehicleId) =>
      _recordsController.stream;

  void emitRecords(List<MaintenanceRecord> records) =>
      _recordsController.add(records);

  void dispose() => _recordsController.close();

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(
      String recordId) async {
    deleteWasCalled = true;
    lastDeletedId = recordId;
    return const Result.success(null);
  }

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(
          MaintenanceRecord record) async =>
      const Result.success('new-id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
          String recordId, MaintenanceRecord record) async =>
      const Result.success(null);

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateVehicle(
          String vehicleId, Vehicle vehicle) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String licensePlate,
          {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>>
      getMaintenanceRecordsForVehicles(List<String> vehicleIds,
              {int limitPerVehicle = 20}) async =>
          const Result.success({});

  @override
  Future<Result<List<MaintenanceRecord>, AppError>>
      getMaintenanceRecordsForVehicle(String vehicleId,
              {int limit = 20}) async =>
          const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadImage(
          io.File imageFile, String path) async =>
      const Result.success('url');

  @override
  Future<Result<String, AppError>> uploadImageBytes(
          Uint8List imageBytes, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(
          List<io.File> imageFiles, String basePath) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(
          Uint8List imageBytes, String path,
          {required dynamic imageService}) async =>
      const Result.success('url');
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

Vehicle _testVehicle() => Vehicle(
      id: 'v1',
      userId: 'test-user-id',
      maker: 'トヨタ',
      model: 'ヴォクシー',
      year: 2023,
      grade: 'Z',
      mileage: 10000,
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
    );

MaintenanceRecord _record({
  String id = 'r1',
  String title = 'オイル交換',
  int cost = 5000,
  MaintenanceType type = MaintenanceType.oilChange,
  String? shopName,
  String? description,
  int? mileageAtService,
  List<WorkItem> workItems = const [],
}) =>
    MaintenanceRecord(
      id: id,
      vehicleId: 'v1',
      userId: 'test-user-id',
      type: type,
      title: title,
      cost: cost,
      date: DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
      shopName: shopName,
      description: description,
      mileageAtService: mileageAtService,
      workItems: workItems,
    );

// ---------------------------------------------------------------------------
// Widget builders
// ---------------------------------------------------------------------------

/// VehicleDetailScreen 全体をテストするビルダー
///
/// ProviderをMaterialAppの外側に置くことで、Navigator.pushで遷移した
/// 画面（MaintenanceStatsScreen等）からもProviderを参照できる。
Widget _buildDetailScreen(
  Vehicle vehicle,
  MaintenanceProvider provider,
) {
  return ChangeNotifierProvider<MaintenanceProvider>.value(
    value: provider,
    child: MaterialApp(
      home: VehicleDetailScreen(vehicle: vehicle),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFirebaseService mockFirebase;
  late MaintenanceProvider provider;

  setUpAll(() {
    final sl = ServiceLocator.instance;
    if (!sl.isRegistered<FirebaseService>()) {
      sl.registerLazySingleton<FirebaseService>(() => MockFirebaseService());
    }
  });

  setUp(() {
    mockFirebase = MockFirebaseService();
    provider = MaintenanceProvider(firebaseService: mockFirebase);
  });

  tearDown(() {
    provider.dispose();
    mockFirebase.dispose();
  });

  tearDownAll(Injection.reset);

  // =========================================================================
  // 1. 基本表示テスト
  // =========================================================================

  group('基本表示', () {
    testWidgets('車両名が AppBar とボディに表示される', (tester) async {
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      await tester.pump();

      expect(find.text('トヨタ ヴォクシー'), findsWidgets);
    });

    testWidgets('統計セクション: 履歴 0 件のとき ¥0 と 0 件を表示', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([]);
      await tester.pumpAndSettle();

      expect(find.text('¥0'), findsOneWidget);
      expect(find.text('0 件'), findsOneWidget);
    });

    testWidgets('履歴なし → 空状態メッセージを表示', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([]);
      await tester.pumpAndSettle();

      expect(find.text('メンテナンス履歴がありません'), findsOneWidget);
    });

    testWidgets('統計セクション: 1 件追加後に費用と件数が反映される', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([_record(cost: 12000)]);
      await tester.pumpAndSettle();

      expect(find.text('¥12,000'), findsWidgets); // 統計カード + タイムライン
      expect(find.text('1 件'), findsOneWidget);
    });
  });

  // =========================================================================
  // 2. タイムライン表示テスト（ビューポート内に収まる情報）
  // =========================================================================

  group('タイムライン表示', () {
    testWidgets('記録タイトルがタイムラインに表示される', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      // タイムライン表示範囲を広げるためウィンドウを縦長に
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      mockFirebase.emitRecords([_record(title: 'エンジンオイル交換')]);
      await tester.pumpAndSettle();

      expect(find.text('エンジンオイル交換'), findsWidgets); // カード + タイプバッジ
    });

    testWidgets('費用がタイムラインカードに表示される', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([_record(cost: 8800)]);
      await tester.pumpAndSettle();

      // ¥8,800 が統計カード（総費用）とタイムラインカードの両方に表示
      expect(find.text('¥8,800'), findsWidgets);
    });

    testWidgets('日付が yyyy/MM/dd 形式で表示される', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([_record()]);
      await tester.pumpAndSettle();

      expect(find.text('2024/03/15'), findsOneWidget);
    });

    testWidgets('shopName があればタイムラインカードに店舗名を表示', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([_record(shopName: 'オートバックス')]);
      await tester.pumpAndSettle();

      expect(find.text('オートバックス'), findsOneWidget);
    });

    testWidgets('複数記録がすべてタイムラインに表示される', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([
        _record(id: 'r1', title: 'オイル交換A'),
        _record(id: 'r2', title: 'タイヤ交換B', type: MaintenanceType.tireChange),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('オイル交換A'), findsWidgets);
      expect(find.text('タイヤ交換B'), findsWidgets);
    });

    testWidgets('総費用は全記録の合計を表示する', (tester) async {
      provider.listenToMaintenanceRecords('v1');
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([
        _record(id: 'r1', cost: 3000),
        _record(id: 'r2', cost: 7000),
      ]);
      await tester.pumpAndSettle();

      // 合計 ¥10,000 が統計カードに表示
      expect(find.text('¥10,000'), findsWidgets);
      expect(find.text('2 件'), findsOneWidget);
    });
  });

  // =========================================================================
  // 3. BottomSheet 詳細表示テスト
  //    タイムラインカードは大きな画面サイズで確実にビューポート内に収める
  // =========================================================================

  group('詳細 BottomSheet', () {
    /// 縦長画面 + タイムラインカードをタップして BottomSheet を開く
    ///
    /// find.byType(GestureDetector).first は AppBar の IconButton 等に含まれる
    /// 内部 GestureDetector を誤って拾うため、レコードタイトルテキストをタップする。
    Future<void> openBottomSheet(
      WidgetTester tester, {
      required MaintenanceRecord record,
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      provider.listenToMaintenanceRecords('v1');
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([record]);
      await tester.pumpAndSettle();

      // タイムラインカード内のレコードタイトルをタップして BottomSheet を開く
      await tester.tap(find.text(record.title).first);
      await tester.pumpAndSettle();
    }

    testWidgets('タイトルが BottomSheet に表示される', (tester) async {
      await openBottomSheet(tester, record: _record(title: '車検2024'));

      // BottomSheet が開くとタイトルが2か所に（カード + BottomSheet ヘッダー）
      expect(find.text('車検2024'), findsAtLeastNWidgets(2));
    });

    testWidgets('費用が BottomSheet に大きく表示される', (tester) async {
      await openBottomSheet(tester, record: _record(cost: 95000));

      expect(find.text('¥95,000'), findsAtLeastNWidgets(1));
    });

    testWidgets('日付が BottomSheet ヘッダーに表示される', (tester) async {
      await openBottomSheet(tester, record: _record());

      // BottomSheet ヘッダーの日付: yyyy年MM月dd日 形式
      expect(find.text('2024年03月15日'), findsOneWidget);
    });

    testWidgets('shopName が BottomSheet に表示される', (tester) async {
      await openBottomSheet(
          tester, record: _record(shopName: 'トヨタディーラー港区'));

      expect(find.text('トヨタディーラー港区'), findsAtLeastNWidgets(1));
    });

    testWidgets('mileageAtService が BottomSheet に表示される', (tester) async {
      await openBottomSheet(tester, record: _record(mileageAtService: 25000));

      expect(
        find.text('${NumberFormat('#,###').format(25000)} km'),
        findsOneWidget,
      );
    });

    testWidgets('description が BottomSheet に表示される', (tester) async {
      await openBottomSheet(
          tester, record: _record(description: '次回5000km後に交換'));

      // DraggableScrollableSheet でスクロール外に出る可能性があるため skipOffstage: false
      expect(find.text('次回5000km後に交換', skipOffstage: false), findsOneWidget);
    });

    testWidgets('workItems が BottomSheet にリスト表示される', (tester) async {
      await openBottomSheet(
        tester,
        record: _record(
          workItems: [
            const WorkItem(name: 'オイルフィルター交換', laborCost: 2000),
            const WorkItem(name: 'ドレンパッキン', laborCost: 500),
          ],
        ),
      );

      expect(find.text('オイルフィルター交換', skipOffstage: false), findsOneWidget);
      expect(find.text('ドレンパッキン', skipOffstage: false), findsOneWidget);
    });

    testWidgets('削除ボタンが BottomSheet に表示される', (tester) async {
      await openBottomSheet(tester, record: _record());

      expect(find.text('この記録を削除', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shopName が null のとき店舗行を表示しない', (tester) async {
      await openBottomSheet(tester, record: _record()); // shopName = null

      // 整備店ラベルが存在しない
      expect(find.text('整備店'), findsNothing);
    });

    testWidgets('mileageAtService が null のとき施工時走行距離行を表示しない',
        (tester) async {
      await openBottomSheet(tester, record: _record()); // mileageAtService = null

      expect(find.text('施工時走行距離'), findsNothing);
    });
  });

  // =========================================================================
  // 4. 削除フロー テスト
  // =========================================================================

  group('削除フロー', () {
    Future<void> openBottomSheetAndScrollToDelete(
        WidgetTester tester, MaintenanceRecord record) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      provider.listenToMaintenanceRecords('v1');
      await tester.pumpWidget(_buildDetailScreen(_testVehicle(), provider));
      mockFirebase.emitRecords([record]);
      await tester.pumpAndSettle();

      // タイムラインカード内のレコードタイトルをタップして BottomSheet を開く
      await tester.tap(find.text(record.title).first);
      await tester.pumpAndSettle();

      // BottomSheet 内の ListView をスクロールして削除ボタンを表示する
      // DraggableScrollableSheet は isScrollControlled:true で開かれるため、
      // 最後の Scrollable が BottomSheet 内の ListView に対応する
      await tester.scrollUntilVisible(
        find.text('この記録を削除'),
        200.0,
        scrollable: find.byType(Scrollable).last,
      );
    }

    testWidgets('削除ボタンをタップすると確認ダイアログが表示される', (tester) async {
      await openBottomSheetAndScrollToDelete(tester, _record());

      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('記録を削除'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('削除'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('キャンセルを選ぶとダイアログが閉じ BottomSheet が残る', (tester) async {
      await openBottomSheetAndScrollToDelete(tester, _record());

      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // ダイアログが閉じた
      expect(find.byType(AlertDialog), findsNothing);
      // BottomSheet はまだ開いている
      expect(find.text('この記録を削除'), findsOneWidget);
    });

    testWidgets('削除を確定すると deleteMaintenanceRecord が呼ばれる', (tester) async {
      final target = _record(id: 'target-id');
      await openBottomSheetAndScrollToDelete(tester, target);

      await tester.tap(find.text('この記録を削除'));
      await tester.pumpAndSettle();

      // 確認ダイアログの「削除」ボタンをタップ
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('削除'),
        ),
      );
      await tester.pumpAndSettle();

      // Service の delete が実際に呼ばれたことを確認
      expect(mockFirebase.deleteWasCalled, isTrue);
      expect(mockFirebase.lastDeletedId, equals('target-id'));
    });
  });
}
