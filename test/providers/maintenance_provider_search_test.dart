// MaintenanceProvider.searchRecords Unit Tests
//
// Verifies keyword / type / date-range / cost-range filtering and sorting
// of in-memory maintenance records (pure Dart logic, no Firebase).

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseService — only the stream used by listenToMaintenanceRecords
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
  required DateTime date,
  String? description,
  String? shopName,
  int? mileageAtService,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: 'v1',
    userId: 'u1',
    type: type,
    title: title,
    description: description,
    cost: cost,
    shopName: shopName,
    date: date,
    mileageAtService: mileageAtService,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// r1: オイル交換 / 5,000円 / 2024-01-15 / Autobacs / 10,000km
/// r2: タイヤ交換 / 48,000円 / 2024-03-10 / タイヤ館 / 12,000km
/// r3: 車検 / 120,000円 / 2024-06-01 / ディーラー / 15,000km
/// r4: オイル交換 / 5,500円 / 2024-07-20 / 店舗なし / 走行距離なし
List<MaintenanceRecord> _fixtures() => [
      _record(
        id: 'r1',
        type: MaintenanceType.oilChange,
        title: 'オイル交換',
        cost: 5000,
        date: DateTime(2024, 1, 15),
        shopName: 'Autobacs',
        mileageAtService: 10000,
      ),
      _record(
        id: 'r2',
        type: MaintenanceType.tireChange,
        title: 'タイヤ交換',
        cost: 48000,
        date: DateTime(2024, 3, 10),
        shopName: 'タイヤ館',
        mileageAtService: 12000,
      ),
      _record(
        id: 'r3',
        type: MaintenanceType.carInspection,
        title: '車検',
        description: '24ヶ月点検整備付き',
        cost: 120000,
        date: DateTime(2024, 6, 1),
        shopName: 'ディーラー',
        mileageAtService: 15000,
      ),
      _record(
        id: 'r4',
        type: MaintenanceType.oilChange,
        title: '2回目オイル交換',
        cost: 5500,
        date: DateTime(2024, 7, 20),
      ),
    ];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _StubFirebaseService service;
  late MaintenanceProvider provider;

  /// Loads fixtures into the provider via the listening stream.
  Future<void> loadFixtures() async {
    provider.listenToMaintenanceRecords('v1');
    service.emit(_fixtures());
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    service = _StubFirebaseService();
    provider = MaintenanceProvider(firebaseService: service);
  });

  tearDown(() {
    provider.dispose();
  });

  group('MaintenanceProvider.searchRecords', () {
    group('キーワード検索', () {
      test('正常系: タイトル部分一致で絞り込める', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: 'オイル');

        expect(result.map((r) => r.id), containsAll(['r1', 'r4']));
        expect(result.length, 2);
      });

      test('正常系: 店舗名で検索できる', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: 'タイヤ館');

        expect(result.single.id, 'r2');
      });

      test('正常系: 説明文で検索できる', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: '24ヶ月');

        expect(result.single.id, 'r3');
      });

      test('正常系: 英字キーワードは大文字小文字を区別しない', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: 'autobacs');

        expect(result.single.id, 'r1');
      });
    });

    group('タイプフィルタ', () {
      test('正常系: 単一タイプで絞り込める', () async {
        await loadFixtures();

        final result =
            provider.searchRecords(types: {MaintenanceType.oilChange});

        expect(result.map((r) => r.id), containsAll(['r1', 'r4']));
        expect(result.length, 2);
      });

      test('正常系: 複数タイプで絞り込める', () async {
        await loadFixtures();

        final result = provider.searchRecords(types: {
          MaintenanceType.tireChange,
          MaintenanceType.carInspection,
        });

        expect(result.map((r) => r.id), containsAll(['r2', 'r3']));
        expect(result.length, 2);
      });
    });

    group('日付範囲フィルタ', () {
      test('正常系: from〜to の範囲（両端含む）で絞り込める', () async {
        await loadFixtures();

        final result = provider.searchRecords(
          from: DateTime(2024, 3, 10),
          to: DateTime(2024, 6, 1),
        );

        expect(result.map((r) => r.id), containsAll(['r2', 'r3']));
        expect(result.length, 2);
      });

      test('正常系: from のみ指定で以降の記録を返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(from: DateTime(2024, 6, 1));

        expect(result.map((r) => r.id), containsAll(['r3', 'r4']));
        expect(result.length, 2);
      });
    });

    group('費用範囲フィルタ', () {
      test('正常系: minCost 以上で絞り込める', () async {
        await loadFixtures();

        final result = provider.searchRecords(minCost: 10000);

        expect(result.map((r) => r.id), containsAll(['r2', 'r3']));
        expect(result.length, 2);
      });

      test('正常系: maxCost 以下で絞り込める', () async {
        await loadFixtures();

        final result = provider.searchRecords(maxCost: 6000);

        expect(result.map((r) => r.id), containsAll(['r1', 'r4']));
        expect(result.length, 2);
      });
    });

    group('複合条件', () {
      test('正常系: キーワード + タイプの AND 条件', () async {
        await loadFixtures();

        final result = provider.searchRecords(
          keyword: '2回目',
          types: {MaintenanceType.oilChange},
        );

        expect(result.single.id, 'r4');
      });
    });

    group('ソート', () {
      test('デフォルトは日付降順', () async {
        await loadFixtures();

        final result = provider.searchRecords();

        expect(result.map((r) => r.id).toList(), ['r4', 'r3', 'r2', 'r1']);
      });

      test('日付昇順', () async {
        await loadFixtures();

        final result =
            provider.searchRecords(sortBy: MaintenanceSortBy.dateAsc);

        expect(result.map((r) => r.id).toList(), ['r1', 'r2', 'r3', 'r4']);
      });

      test('費用降順', () async {
        await loadFixtures();

        final result =
            provider.searchRecords(sortBy: MaintenanceSortBy.costDesc);

        expect(result.map((r) => r.id).toList(), ['r3', 'r2', 'r4', 'r1']);
      });

      test('費用昇順', () async {
        await loadFixtures();

        final result =
            provider.searchRecords(sortBy: MaintenanceSortBy.costAsc);

        expect(result.map((r) => r.id).toList(), ['r1', 'r4', 'r2', 'r3']);
      });

      test('走行距離降順（null は末尾）', () async {
        await loadFixtures();

        final result =
            provider.searchRecords(sortBy: MaintenanceSortBy.mileageDesc);

        expect(result.map((r) => r.id).toList(), ['r3', 'r2', 'r1', 'r4']);
      });
    });

    group('Edge Cases', () {
      test('空文字キーワードは全件を返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: '');

        expect(result.length, 4);
      });

      test('空白のみのキーワードは全件を返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: '   ');

        expect(result.length, 4);
      });

      test('空の types セットは全件を返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(types: {});

        expect(result.length, 4);
      });

      test('該当なしキーワードは空リストを返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(keyword: '存在しない整備');

        expect(result, isEmpty);
      });

      test('記録が0件のとき空リストを返す', () {
        final result = provider.searchRecords(keyword: 'オイル');

        expect(result, isEmpty);
      });

      test('from > to の矛盾した範囲は空リストを返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(
          from: DateTime(2024, 12, 31),
          to: DateTime(2024, 1, 1),
        );

        expect(result, isEmpty);
      });

      test('minCost > maxCost の矛盾した範囲は空リストを返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(minCost: 100000, maxCost: 100);

        expect(result, isEmpty);
      });

      test('負の minCost でもクラッシュせず全件返す', () async {
        await loadFixtures();

        final result = provider.searchRecords(minCost: -1);

        expect(result.length, 4);
      });

      test('searchRecords は元の records リストを変更しない', () async {
        await loadFixtures();

        provider.searchRecords(sortBy: MaintenanceSortBy.costAsc);

        // Original list order (stream order) is preserved
        expect(
          provider.records.map((r) => r.id).toList(),
          ['r1', 'r2', 'r3', 'r4'],
        );
      });
    });
  });
}
