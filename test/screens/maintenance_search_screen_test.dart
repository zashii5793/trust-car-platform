// MaintenanceSearchScreen Widget Tests

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/maintenance_search_screen.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseService
// ---------------------------------------------------------------------------

class _StubFirebaseService implements FirebaseService {
  final StreamController<List<MaintenanceRecord>> _controller =
      StreamController<List<MaintenanceRecord>>.broadcast();

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(
          String vehicleId) =>
      _controller.stream;

  void emit(List<MaintenanceRecord> records) => _controller.add(records);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

MaintenanceRecord _record({
  required String id,
  required MaintenanceType type,
  required String title,
  required int cost,
  String? shopName,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: 'v1',
    userId: 'u1',
    type: type,
    title: title,
    cost: cost,
    shopName: shopName,
    date: DateTime(2024, 5, 1),
    createdAt: DateTime(2024, 5, 1),
  );
}

Widget _buildUnderTest(MaintenanceProvider provider) {
  return ChangeNotifierProvider<MaintenanceProvider>.value(
    value: provider,
    child: const MaterialApp(home: MaintenanceSearchScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _StubFirebaseService service;
  late MaintenanceProvider provider;

  // NOTE: no real-async await here — testWidgets runs under FakeAsync,
  // so stream delivery is flushed by the pump calls in each test.
  void loadRecords(List<MaintenanceRecord> records) {
    provider.listenToMaintenanceRecords('v1');
    service.emit(records);
  }

  setUp(() {
    service = _StubFirebaseService();
    provider = MaintenanceProvider(firebaseService: service);
  });

  tearDown(() {
    provider.dispose();
  });

  group('MaintenanceSearchScreen — 基本表示', () {
    testWidgets('AppBar タイトル・検索フィールド・フィルタチップが表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('整備履歴を検索'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
    });

    testWidgets('全記録が一覧表示され、件数と合計費用が表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
        _record(
            id: 'r2',
            type: MaintenanceType.tireChange,
            title: 'タイヤ交換',
            cost: 48000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('オイル交換'), findsWidgets);
      expect(find.text('タイヤ交換'), findsWidgets);
      expect(find.text('2件'), findsOneWidget);
      expect(find.text('合計 ¥53,000'), findsOneWidget);
    });
  });

  group('MaintenanceSearchScreen — キーワード検索', () {
    testWidgets('キーワード入力で結果が絞り込まれる', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
        _record(
            id: 'r2',
            type: MaintenanceType.tireChange,
            title: 'タイヤ交換',
            cost: 48000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'タイヤ');
      await tester.pump();

      expect(find.text('1件'), findsOneWidget);
      // 結果カードはタイヤ交換のみ（チップのラベルとは別に判定）
      expect(find.text('オイル交換'), findsOneWidget); // FilterChip のみ
      expect(find.text('タイヤ交換'), findsNWidgets(2)); // チップ + 結果カード
    });

    testWidgets('該当なしキーワードで空状態が表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '存在しない記録');
      await tester.pump();

      expect(find.text('該当する整備記録がありません'), findsOneWidget);
      expect(find.text('0件'), findsOneWidget);
    });
  });

  group('MaintenanceSearchScreen — タイプフィルタ', () {
    testWidgets('FilterChip タップで該当タイプのみ表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'エンジンオイル',
            cost: 5000),
        _record(
            id: 'r2',
            type: MaintenanceType.tireChange,
            title: 'スタッドレス',
            cost: 48000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      // 「オイル交換」チップをタップ
      await tester.tap(find.widgetWithText(FilterChip, 'オイル交換'));
      await tester.pump();

      expect(find.text('1件'), findsOneWidget);
      expect(find.text('エンジンオイル'), findsOneWidget);
      expect(find.text('スタッドレス'), findsNothing);

      // 再タップで解除 → 全件に戻る
      await tester.tap(find.widgetWithText(FilterChip, 'オイル交換'));
      await tester.pump();

      expect(find.text('2件'), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('記録0件でも空状態でクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('該当する整備記録がありません'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('クリアボタンでキーワードがリセットされる', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('0件'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.text('1件'), findsOneWidget);
    });
  });

  // =========================================================================
  group('MaintenanceSearchScreen — 検索フィールド', () {
    testWidgets('9. 検索フィールドのヒントテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('タイトル・店舗名・メモで検索'), findsOneWidget);
    });

    testWidgets('10. 入力前はクリアアイコンが表示されない', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('11. テキスト入力後にクリアアイコンが表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'テスト');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });

  // =========================================================================
  group('MaintenanceSearchScreen — 結果カード詳細', () {
    testWidgets('12. カードに費用が表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('¥5,000'), findsOneWidget);
    });

    testWidgets('13. カードに日付が表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      // Record date is DateTime(2024, 5, 1) → '2024/05/01'
      expect(find.text('2024/05/01'), findsOneWidget);
    });

    testWidgets('14. カードに店舗名が表示される', (tester) async {
      loadRecords([
        _record(
            id: 'r1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 5000,
            shopName: 'トヨタディーラー'),
      ]);

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('トヨタディーラー'), findsOneWidget);
    });
  });

  // =========================================================================
  group('MaintenanceSearchScreen — サマリー表示', () {
    testWidgets('15. ソートラベル「日付が新しい順」がサマリーに表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('日付が新しい順'), findsOneWidget);
    });

    testWidgets('16. 合計費用0円の場合「合計 ¥0」が表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('合計 ¥0'), findsOneWidget);
    });
  });
}
