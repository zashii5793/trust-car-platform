// MaintenanceStatsScreen Widget Tests
//
// Coverage:
//   Empty state:
//     1. Shows 'メンテナンス履歴がありません' when records empty
//   Section headers:
//     2. Shows '年間コスト' section
//     3. Shows '月別コスト推移（直近12ヶ月）' section
//     4. Shows 'タイプ別内訳' section
//   Summary cards:
//     5. Shows formatted total cost
//     6. Shows record count
//     7. Shows average cost per record
//     8. Shows category count
//   Type breakdown:
//     9. Shows maintenance type display name
//    10. Shows percentage for each type
//   Shop breakdown:
//    11. Shop section hidden when no shop names in records
//    12. Shop section shown when records have shop names
//    13. Shop name displayed in breakdown
//   AppBar:
//    14. Shows 'メンテナンス統計' title
//   Edge Cases:
//    15. Single record — average = total cost, 100%
//    16. Records with no shop name — shop section hidden

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:trust_car_platform/screens/maintenance_stats_screen.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseService
// ---------------------------------------------------------------------------

class _StubFirebaseService implements FirebaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake MaintenanceProvider
// ---------------------------------------------------------------------------

class _FakeMaintenanceProvider extends MaintenanceProvider {
  final List<MaintenanceRecord> _fakeRecords;

  _FakeMaintenanceProvider({List<MaintenanceRecord> records = const []})
      : _fakeRecords = records,
        super(firebaseService: _StubFirebaseService());

  @override
  List<MaintenanceRecord> get records => _fakeRecords;

  @override
  bool get isLoading => false;
}

// ---------------------------------------------------------------------------
// Test data factory
// ---------------------------------------------------------------------------

MaintenanceRecord _makeRecord({
  String id = 'rec-1',
  String vehicleId = 'vehicle-1',
  String userId = 'user-1',
  MaintenanceType type = MaintenanceType.oilChange,
  String title = 'オイル交換',
  int cost = 5000,
  String? shopName,
  DateTime? date,
}) {
  final now = date ?? DateTime(2025, 6, 15);
  return MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    userId: userId,
    type: type,
    title: title,
    cost: cost,
    shopName: shopName,
    date: now,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({required _FakeMaintenanceProvider provider}) {
  return ChangeNotifierProvider<MaintenanceProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: MaintenanceStatsScreen(vehicleName: 'テスト車'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MaintenanceStatsScreen — AppBar', () {
    testWidgets('14. shows メンテナンス統計 title', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeMaintenanceProvider()),
      );
      await tester.pump();

      expect(find.text('メンテナンス統計'), findsOneWidget);
    });
  });

  group('MaintenanceStatsScreen — Empty state', () {
    testWidgets('1. shows empty message when no records', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeMaintenanceProvider()),
      );
      await tester.pump();

      expect(find.text('メンテナンス履歴がありません'), findsOneWidget);
    });

    testWidgets('1b. no stat sections rendered when empty', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeMaintenanceProvider()),
      );
      await tester.pump();

      expect(find.text('年間コスト'), findsNothing);
      expect(find.text('タイプ別内訳'), findsNothing);
    });
  });

  group('MaintenanceStatsScreen — Section headers', () {
    late _FakeMaintenanceProvider provider;

    setUp(() {
      provider = _FakeMaintenanceProvider(
        records: [_makeRecord(cost: 10000)],
      );
    });

    testWidgets('2. shows 年間コスト section', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('年間コスト'), findsOneWidget);
    });

    testWidgets('3. shows 月別コスト推移（直近12ヶ月）section', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(
        find.text('月別コスト推移（直近12ヶ月）'),
        200,
      );
      expect(find.text('月別コスト推移（直近12ヶ月）'), findsOneWidget);
    });

    testWidgets('4. shows タイプ別内訳 section', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('タイプ別内訳'), 200);
      expect(find.text('タイプ別内訳'), findsOneWidget);
    });
  });

  group('MaintenanceStatsScreen — Summary cards', () {
    testWidgets('5. shows formatted total cost', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [
          _makeRecord(id: '1', cost: 5000),
          _makeRecord(id: '2', cost: 3000),
        ],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Total = ¥8,000
      expect(find.text('¥8,000'), findsOneWidget);
    });

    testWidgets('6. shows record count', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [
          _makeRecord(id: '1'),
          _makeRecord(id: '2'),
          _makeRecord(id: '3'),
        ],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('3件'), findsOneWidget);
    });

    testWidgets('7. shows average cost per record', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [
          _makeRecord(id: '1', cost: 4000),
          _makeRecord(id: '2', cost: 6000),
        ],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Average = ¥5,000
      expect(find.text('¥5,000'), findsOneWidget);
    });

    testWidgets('8. shows category count', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [
          _makeRecord(id: '1', type: MaintenanceType.oilChange),
          _makeRecord(id: '2', type: MaintenanceType.tireChange),
        ],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('2種類'), findsOneWidget);
    });
  });

  group('MaintenanceStatsScreen — Type breakdown', () {
    testWidgets('9. shows maintenance type display name', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [_makeRecord(type: MaintenanceType.oilChange, cost: 3000)],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('タイプ別内訳'), 200);
      // オイル交換 displayName
      expect(find.text('オイル交換'), findsWidgets);
    });

    testWidgets('10. shows 100% for single-type records', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [
          _makeRecord(id: '1', type: MaintenanceType.repair, cost: 10000),
        ],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('100%'), 200);
      expect(find.text('100%'), findsOneWidget);
    });
  });

  group('MaintenanceStatsScreen — Shop breakdown', () {
    testWidgets('11. shop section hidden when no shop names', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [_makeRecord(shopName: null)],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('店舗別集計'), findsNothing);
    });

    testWidgets('12. shop section shown when records have shop names',
        (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [_makeRecord(shopName: 'オートサービス山田')],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('店舗別集計'), 200);
      expect(find.text('店舗別集計'), findsOneWidget);
    });

    testWidgets('13. shop name displayed in breakdown', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [_makeRecord(shopName: 'トラストモータース', cost: 8000)],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('トラストモータース'), 200);
      expect(find.text('トラストモータース'), findsOneWidget);
    });
  });

  group('MaintenanceStatsScreen — Edge Cases', () {
    testWidgets('15. single record shows total = average', (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [_makeRecord(cost: 12000)],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Both total and average show ¥12,000
      expect(find.text('¥12,000'), findsWidgets);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('16. records with empty shop name — shop section hidden',
        (tester) async {
      final provider = _FakeMaintenanceProvider(
        records: [_makeRecord(shopName: '')],
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('店舗別集計'), findsNothing);
    });
  });
}
