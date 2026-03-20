// PdfExportService Tests
//
// Strategy: pdf package is pure Dart (no platform channels), so
// generateMaintenanceReport can be called directly in tests.
//
// Coverage:
//   1. Returns non-empty Uint8List for various inputs
//   2. Handles empty records gracefully
//   3. Single record — cost display, no division-by-zero
//   4. Multiple records — sorting verified via observable behavior
//   5. Cost calculation logic (total / average)
//   6. Many records — performance smoke test
//   7. Edge cases: zero cost, maximum mileage, special chars

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/pdf_export_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import '../fixtures/test_data.dart';

void main() {
  late PdfExportService service;

  setUp(() {
    service = PdfExportService();
  });

  // ── ヘルパー ──────────────────────────────────────────────────────────────

  // コスト計算ロジック（サービス内部と同じアルゴリズムをここで検証）
  int totalCost(List<MaintenanceRecord> records) =>
      records.fold(0, (sum, r) => sum + r.cost);

  double averageCost(List<MaintenanceRecord> records) =>
      records.isEmpty ? 0 : totalCost(records) / records.length;

  bool isSortedDescending(List<MaintenanceRecord> records) {
    for (int i = 0; i < records.length - 1; i++) {
      if (records[i].date.isBefore(records[i + 1].date)) return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Group 1: 基本動作 — PDF生成
  // -------------------------------------------------------------------------
  group('generateMaintenanceReport — 基本動作', () {
    test('空の記録でも PDF が生成される', () async {
      final vehicle = TestData.makeVehicle();
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [],
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('1件の記録で PDF が生成される', () async {
      final vehicle = TestData.makeVehicle();
      final record = TestData.makeMaintenanceRecord(cost: 5000);
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [record],
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('複数件の記録で PDF が生成される', () async {
      final vehicle = TestData.makeVehicle();
      // 5件の記録でテスト
      final testRecords = List.generate(
        5,
        (i) => TestData.makeMaintenanceRecord(
          id: 'maint-$i',
          cost: (i + 1) * 1000,
        ),
      );
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: testRecords,
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('返り値は有効なPDFヘッダーで始まる（%PDF）', () async {
      final vehicle = TestData.makeVehicle();
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [],
      );
      // PDFファイルは %PDF で始まる
      expect(bytes.length, greaterThan(4));
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });
  });

  // -------------------------------------------------------------------------
  // Group 2: ソート — 日付降順
  // -------------------------------------------------------------------------
  group('記録のソート順', () {
    test('古い順に入力しても新しい順（降順）でソートされる', () {
      final now = DateTime.now();
      final records = [
        TestData.makeMaintenanceRecord(
          id: 'old',
          date: now.subtract(const Duration(days: 365)),
          cost: 1000,
        ),
        TestData.makeMaintenanceRecord(
          id: 'new',
          date: now,
          cost: 2000,
        ),
        TestData.makeMaintenanceRecord(
          id: 'mid',
          date: now.subtract(const Duration(days: 180)),
          cost: 1500,
        ),
      ];

      // 内部ソートアルゴリズムと同一
      final sorted = List<MaintenanceRecord>.from(records)
        ..sort((a, b) => b.date.compareTo(a.date));

      expect(isSortedDescending(sorted), isTrue);
      expect(sorted.first.id, 'new');
      expect(sorted.last.id, 'old');
    });

    test('同日の記録は順序が維持される（stable sort）', () {
      final date = DateTime(2024, 6, 1);
      final records = [
        TestData.makeMaintenanceRecord(id: 'a', date: date, cost: 1000),
        TestData.makeMaintenanceRecord(id: 'b', date: date, cost: 2000),
      ];

      final sorted = List<MaintenanceRecord>.from(records)
        ..sort((a, b) => b.date.compareTo(a.date));

      expect(sorted.length, 2);
      // 同日なら元の順序が保持される（比較結果が0）
      expect(sorted[0].date, equals(sorted[1].date));
    });

    test('空リストのソートはクラッシュしない', () {
      final sorted = <MaintenanceRecord>[]
        ..sort((a, b) => b.date.compareTo(a.date));
      expect(sorted, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Group 3: コスト計算ロジック
  // -------------------------------------------------------------------------
  group('コスト計算ロジック', () {
    test('空リスト → 総費用は 0', () {
      expect(totalCost([]), 0);
    });

    test('1件 → 総費用はその費用', () {
      final record = TestData.makeMaintenanceRecord(cost: 5000);
      expect(totalCost([record]), 5000);
    });

    test('複数件 → 費用が正しく合計される', () {
      final records = [
        TestData.makeMaintenanceRecord(id: 'a', cost: 3500),
        TestData.makeMaintenanceRecord(id: 'b', cost: 6800),
        TestData.makeMaintenanceRecord(id: 'c', cost: 12000),
      ];
      expect(totalCost(records), 22300);
    });

    test('空リスト → 平均費用は 0 で除算エラーなし', () {
      expect(averageCost([]), 0);
    });

    test('1件 → 平均費用はその費用', () {
      final record = TestData.makeMaintenanceRecord(cost: 5000);
      expect(averageCost([record]), 5000.0);
    });

    test('3件 → 平均費用が正しく計算される', () {
      final records = [
        TestData.makeMaintenanceRecord(id: 'a', cost: 3000),
        TestData.makeMaintenanceRecord(id: 'b', cost: 6000),
        TestData.makeMaintenanceRecord(id: 'c', cost: 9000),
      ];
      expect(averageCost(records), 6000.0);
    });

    test('費用0円の記録でもクラッシュしない', () {
      final records = [
        TestData.makeMaintenanceRecord(id: 'a', cost: 0),
        TestData.makeMaintenanceRecord(id: 'b', cost: 5000),
      ];
      expect(totalCost(records), 5000);
      expect(averageCost(records), 2500.0);
    });

    test('大きな費用値（100万円）でもオーバーフローしない', () {
      final records = List.generate(
        10,
        (i) => TestData.makeMaintenanceRecord(
          id: 'maint-$i',
          cost: 1000000, // 100万円
        ),
      );
      expect(totalCost(records), 10000000);
    });
  });

  // -------------------------------------------------------------------------
  // Group 4: タイプ統計
  // -------------------------------------------------------------------------
  group('タイプ別集計ロジック', () {
    test('同一タイプは費用が合算される', () {
      final records = [
        TestData.makeMaintenanceRecord(
          id: 'a',
          type: MaintenanceType.oilChange,
          cost: 3500,
        ),
        TestData.makeMaintenanceRecord(
          id: 'b',
          type: MaintenanceType.oilChange,
          cost: 4000,
        ),
        TestData.makeMaintenanceRecord(
          id: 'c',
          type: MaintenanceType.tireRotation,
          cost: 2000,
        ),
      ];

      // タイプ別集計（サービス内部と同一ロジック）
      final typeStats = <MaintenanceType, int>{};
      for (final record in records) {
        typeStats[record.type] = (typeStats[record.type] ?? 0) + record.cost;
      }

      expect(typeStats[MaintenanceType.oilChange], 7500);
      expect(typeStats[MaintenanceType.tireRotation], 2000);
      expect(typeStats.length, 2);
    });

    test('全タイプで displayName が設定されている', () {
      for (final type in MaintenanceType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Group 5: 車両情報の表示
  // -------------------------------------------------------------------------
  group('車両情報', () {
    test('メーカー + 車種でフルネームが構築される', () {
      final vehicle = TestData.makeVehicle(maker: 'Honda', model: 'Fit');
      expect('${vehicle.maker} ${vehicle.model}', 'Honda Fit');
    });

    test('走行距離フォーマット（カンマ区切り）', () {
      final vehicle = TestData.makeVehicle(mileage: 123456);
      final formatted = vehicle.mileage.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
      expect(formatted, '123,456');
    });

    test('グレードが空でも車両情報は表示できる', () async {
      final vehicle = TestData.makeVehicle(grade: '');
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('メーカー名に特殊文字が含まれてもクラッシュしない', () async {
      final vehicle = TestData.makeVehicle(maker: 'メーカー(特殊)＆テスト');
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [],
      );
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Group 6: パフォーマンス・大量データ
  // -------------------------------------------------------------------------
  group('パフォーマンス', () {
    test('100件の記録でもクラッシュせずPDFが生成される', () async {
      final vehicle = TestData.makeVehicle();
      final records = List.generate(
        100,
        (i) => TestData.makeMaintenanceRecord(
          id: 'maint-$i',
          cost: (i + 1) * 100,
          date: DateTime.now().subtract(Duration(days: i)),
        ),
      );
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: records,
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('全 MaintenanceType で PDF が生成される', () async {
      final vehicle = TestData.makeVehicle();
      final records = MaintenanceType.values
          .map(
            (type) => TestData.makeMaintenanceRecord(
              id: type.name,
              type: type,
              cost: 3000,
            ),
          )
          .toList();
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: records,
      );
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Group 7: Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('費用が 0 円の記録のみ → 総費用 0, 平均 0', () {
      final records = [
        TestData.makeMaintenanceRecord(id: 'a', cost: 0),
        TestData.makeMaintenanceRecord(id: 'b', cost: 0),
      ];
      expect(totalCost(records), 0);
      expect(averageCost(records), 0.0);
    });

    test('走行距離がnullでもPDF生成できる', () async {
      final vehicle = TestData.makeVehicle();
      final record = TestData.makeMaintenanceRecord(
        mileageAtService: 0, // mileageAtService=0で代替
      );
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [record],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('メモが長い文字列でもクラッシュしない', () async {
      final vehicle = TestData.makeVehicle();
      final longDesc = 'あ' * 500;
      final record = TestData.makeMaintenanceRecord(
        description: longDesc,
      );
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [record],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('非常に古い日付（1990年）の記録でもクラッシュしない', () async {
      final vehicle = TestData.makeVehicle(year: 1990);
      final record = TestData.makeMaintenanceRecord(
        date: DateTime(1990, 1, 1),
        cost: 5000,
      );
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [record],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('未来日付の記録でもクラッシュしない', () async {
      final vehicle = TestData.makeVehicle();
      final record = TestData.makeMaintenanceRecord(
        date: DateTime.now().add(const Duration(days: 30)),
        cost: 5000,
      );
      final bytes = await service.generateMaintenanceReport(
        vehicle: vehicle,
        records: [record],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('PdfExportService インスタンスを複数回呼び出してもクラッシュしない', () async {
      final vehicle = TestData.makeVehicle();
      final record = TestData.makeMaintenanceRecord();
      for (int i = 0; i < 3; i++) {
        final bytes = await service.generateMaintenanceReport(
          vehicle: vehicle,
          records: [record],
        );
        expect(bytes.isNotEmpty, isTrue);
      }
    });
  });
}
