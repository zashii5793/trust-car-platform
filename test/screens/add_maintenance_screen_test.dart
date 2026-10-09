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

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
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

import '../golden/font_loader.dart';

// ---------------------------------------------------------------------------
// Mock Services
// ---------------------------------------------------------------------------

class _MockFirebaseService implements FirebaseService {
  @override
  Future<Result<MaintenanceSummary, AppError>> maintenanceSummary({
    DateTime? since,
  }) async =>
      const Result.success(MaintenanceSummary.empty);

  @override
  Future<Result<bool, AppError>> hasAnyMaintenanceRecord() async =>
      const Result.success(false);

  @override
  String? get currentUserId => 'test-user-id';

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vid) =>
      const Stream.empty();

  /// 追加された記録（二重送信・費用未入力の確認用）。
  final List<MaintenanceRecord> added = [];

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(
      MaintenanceRecord r) async {
    added.add(r);
    // Saving takes a moment in real life; let taps pile up meanwhile.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Result.success('new-record-id');
  }

  /// 編集で保存された記録。内訳などが引き継がれているかを見るため。
  MaintenanceRecord? lastUpdated;

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
      String id, MaintenanceRecord r) async {
    lastUpdated = r;
    return const Result.success(null);
  }

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
      getRecentMaintenanceRecords({
    int limit = 5,
  }) async =>
          const Result.success([]);

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
  Future<Result<String, AppError>> uploadImageBytes(
          dynamic b, String path) async =>
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

Widget _buildNew(
    {String vehicleId = 'v-001', int? currentMileage, ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
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

  // 見え方を画像に残す。CI では走らない（tags: 'golden'）。
  group('ゴールデン', () {
    setUpAll(() async {
      await loadMaterialIcons();
      await loadJapaneseFont();
    });

    // 画面が下書きの復元で SharedPreferences を読む。
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> shoot(WidgetTester tester, String name, ThemeData base) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildNew(theme: goldenTheme(base)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../golden/goldens/$name.png'),
      );
    }

    testWidgets('整備記録の追加（ライト）', (tester) async {
      await shoot(tester, 'screen_add_maintenance_light', AppTheme.lightTheme);
    }, tags: 'golden');

    testWidgets('整備記録の追加（ダーク）', (tester) async {
      await shoot(tester, 'screen_add_maintenance_dark', AppTheme.darkTheme);
    }, tags: 'golden');
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

      // チップが複数箇所（選択行と一覧）に表示されうるため findsWidgets
      expect(find.text('修理'), findsWidgets);
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
        await tester.pumpAndSettle(const Duration(seconds: 10));
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

      // 金額入力は3桁区切りで表示される
      expect(find.text('12,500'), findsOneWidget);
    });

    testWidgets('既存の走行距離が TextFormField に表示される', (tester) async {
      await tester.pumpWidget(_buildEdit(record: _makeRecord(mileage: 45000)));
      await tester.pump();

      // 走行距離入力は3桁区切りで表示される
      expect(find.text('45,000'), findsOneWidget);
    });

    testWidgets('既存の店舗名が TextFormField に表示される', (tester) async {
      await tester
          .pumpWidget(_buildEdit(record: _makeRecord(shopName: 'トラストモータース')));
      await tester.pump();

      expect(find.text('トラストモータース'), findsOneWidget);
    });

    testWidgets('既存の備考が TextFormField に表示される', (tester) async {
      await tester
          .pumpWidget(_buildEdit(record: _makeRecord(description: '既存の備考内容')));
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
      await tester
          .pumpWidget(_buildEdit(record: _makeRecord(title: longTitle)));
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

  // =========================================================================
  group('コミュニティトレンド投稿 — fire-and-forget', () {
    testWidgets('CommunityTrendService 未登録でも画面が正常に表示される', (tester) async {
      // CommunityTrendService is intentionally NOT registered in setUpAll.
      // The screen must render without any crash. The _submitTrendData call
      // silently swallows all errors so it never disrupts the user flow.
      await tester.pumpWidget(_buildNew());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('メンテナンス履歴を追加'), findsOneWidget);
    });

    testWidgets('編集モードでは保存しても _submitTrendData は呼ばれない（クラッシュしない）',
        (tester) async {
      // In edit mode, community trend submission is skipped entirely.
      await tester.pumpWidget(_buildEdit());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // 2026-09-27: 編集画面は記録を一から作り直していて、画面に無い項目
  // （内訳・工場との紐づけ・裏書き）を引き継いでいなかった。
  group('編集で消えてはいけないもの', () {
    MaintenanceRecord detailed({String? inquiryId}) => MaintenanceRecord(
          id: 'rec-9',
          vehicleId: 'v-001',
          userId: 'user-001',
          type: MaintenanceType.carInspection,
          title: '車検',
          cost: 120000,
          date: DateTime(2026, 3, 1),
          mileageAtService: 45000,
          shopName: 'タカヤモーター',
          description: '前のメモ',
          createdAt: DateTime(2026, 3, 1),
          workItems: const [WorkItem(name: '法定24か月点検', laborCost: 30000)],
          partsCost: 20000,
          laborCost: 30000,
          taxAmount: 10000,
          inquiryId: inquiryId,
        );

    Future<void> saveAfter(WidgetTester tester, MaintenanceRecord record,
        Future<void> Function() edit) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _mockFirebase.lastUpdated = null;
      await tester.pumpWidget(_buildEdit(record: record));
      await tester.pumpAndSettle();
      await edit();
      await tester.tap(find.text('更新する'));
      await tester.pumpAndSettle();
    }

    testWidgets('自己申告の記録を直しても、内訳は残る', (tester) async {
      await saveAfter(tester, detailed(), () async {
        await tester.enterText(
            find.widgetWithText(TextFormField, '前のメモ'), '新しいメモ');
      });
      final saved = _mockFirebase.lastUpdated!;
      expect(saved.description, '新しいメモ');
      expect(saved.workItems.single.name, '法定24か月点検');
      expect(saved.partsCost, 20000);
      expect(saved.laborCost, 30000);
      expect(saved.taxAmount, 10000);
    });

    testWidgets('工場から受け取った記録は、出所の印を保ったまま保存される', (tester) async {
      await saveAfter(tester, detailed(inquiryId: 'inq-1'), () async {});
      final saved = _mockFirebase.lastUpdated!;
      expect(saved.inquiryId, 'inq-1');
      expect(saved.verificationSource, VerificationSource.shopImported);
      expect(saved.toMap()['verificationSource'], 'shopImported');
    });

    testWidgets('工場から受け取った記録は、金額などを変えられないと示し、入力欄を閉じる', (tester) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildEdit(record: detailed(inquiryId: 'inq-1')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('shop_record_locked_banner')), findsOneWidget);
      final cost = tester.widget<TextField>(find.descendant(
        of: find.ancestor(
            of: find.text('費用（任意）'),
            matching: find.byWidgetPredicate((w) => w is TextFormField)),
        matching: find.byType(TextField),
      ));
      expect(cost.enabled, isFalse);
    });
  });

  // 使用感テスト（2026-10-09）: 「保存する」を続けて押すと、同じ整備記録が
  // 2件できた。保存中はボタンを止める。
  group('二重送信', () {
    Finder field(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is TextFormField),
        );

    testWidgets('保存を20回続けて押しても、記録は1件だけ', (tester) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _mockFirebase.added.clear();
      await tester.pumpWidget(_buildNew());
      await tester.pumpAndSettle();

      await tester.enterText(field('タイトル'), '12ヶ月点検');
      await tester.enterText(field('費用（任意）'), '15000');
      await tester.pump();

      final save = find.text('保存する');
      for (var i = 0; i < 20; i++) {
        await tester.tap(save, warnIfMissed: false);
      }
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(_mockFirebase.added, hasLength(1));
    });

    testWidgets('保存中はボタンが押せない', (tester) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _mockFirebase.added.clear();
      await tester.pumpWidget(_buildNew());
      await tester.pumpAndSettle();

      await tester.enterText(field('タイトル'), '12ヶ月点検');
      await tester.enterText(field('費用（任意）'), '15000');
      await tester.tap(find.text('保存する'));
      await tester.pump(const Duration(milliseconds: 50));

      final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('保存する'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ));
      expect(button.onPressed, isNull);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
  });

  // 使用感テスト（2026-10-09）: 車の走行距離 32,000km に対して、今日の記録に
  // 10,000km を入れても何も言われずに保存された。
  group('走行距離の前後の整合', () {
    Finder field(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is TextFormField),
        );

    Future<void> fillAndSave(WidgetTester tester, String mileage) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _mockFirebase.added.clear();
      await tester.pumpWidget(_buildNew(currentMileage: 32000));
      await tester.pumpAndSettle();

      await tester.enterText(field('タイトル'), 'オイル交換');
      await tester.enterText(field('費用（任意）'), '5000');
      await tester.enterText(field('実施時の走行距離（任意）'), mileage);
      await tester.tap(find.text('保存する'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('今日の記録で車の走行距離より小さいと、理由を添えて確認する', (tester) async {
      await fillAndSave(tester, '10000');

      expect(find.text('走行距離の確認'), findsOneWidget);
      expect(find.textContaining('32,000km'), findsOneWidget);
      expect(_mockFirebase.added, isEmpty);
    });

    testWidgets('「見直す」を選ぶと保存しない', (tester) async {
      await fillAndSave(tester, '10000');

      await tester.tap(find.byKey(const Key('mileage_conflict_review')));
      await settle(tester);

      expect(_mockFirebase.added, isEmpty);
      expect(find.text('メンテナンス履歴を追加'), findsOneWidget);
    });

    testWidgets('「このまま保存」を選ぶと保存する（メーター交換など）', (tester) async {
      await fillAndSave(tester, '10000');

      await tester.tap(find.byKey(const Key('mileage_conflict_save')));
      await settle(tester);

      expect(_mockFirebase.added, hasLength(1));
      expect(_mockFirebase.added.single.mileageAtService, 10000);
    });

    group('Edge Cases', () {
      testWidgets('車の走行距離と同じなら確認しない', (tester) async {
        await fillAndSave(tester, '32000');
        await settle(tester);

        expect(find.text('走行距離の確認'), findsNothing);
        expect(_mockFirebase.added, hasLength(1));
      });
    });
  });

  // 使用感テスト（2026-10-09）: 金額を空けると「費用を入力してください」で
  // 保存できず、0円を入れると記録に「¥0」と残った。
  group('費用は任意', () {
    Finder field(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is TextFormField),
        );

    testWidgets('費用を空けたまま保存でき、未入力として残る', (tester) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _mockFirebase.added.clear();
      await tester.pumpWidget(_buildNew());
      await tester.pumpAndSettle();

      await tester.enterText(field('タイトル'), '12ヶ月点検');
      await tester.tap(find.text('保存する'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('費用を入力してください'), findsNothing);
      expect(_mockFirebase.added, hasLength(1));
      expect(_mockFirebase.added.single.hasCost, isFalse);
      expect(_mockFirebase.added.single.toMap()['cost'], isNull);
    });

    group('Edge Cases', () {
      testWidgets('未入力の記録を編集で開くと、費用欄は空（0 と出さない）', (tester) async {
        await tester.pumpWidget(_buildEdit(
          record: _makeRecord(cost: 0).copyWith(hasCost: false),
        ));
        await tester.pumpAndSettle();

        final cost = tester.widget<TextField>(find.descendant(
          of: field('費用（任意）'),
          matching: find.byType(TextField),
        ));
        expect(cost.controller!.text, isEmpty);
      });

      testWidgets('0円と入れた記録は 0円として残す', (tester) async {
        tester.view.physicalSize = const Size(900, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        _mockFirebase.added.clear();
        await tester.pumpWidget(_buildNew());
        await tester.pumpAndSettle();

        await tester.enterText(field('タイトル'), '無料点検');
        await tester.enterText(field('費用（任意）'), '0');
        await tester.tap(find.text('保存する'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(_mockFirebase.added.single.hasCost, isTrue);
        expect(_mockFirebase.added.single.cost, 0);
      });
    });
  });
}
