// FleetCsvExportService Unit Tests
//
// Tests CSV generation for fleet vehicle lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/fleet_csv_export_service.dart';
import 'package:trust_car_platform/services/fleet_service.dart';

Vehicle _makeVehicle({
  String id = 'v1',
  String maker = 'トヨタ',
  String model = 'プリウス',
  int year = 2022,
  String grade = 'S',
  int mileage = 30000,
  String? licensePlate,
  DateTime? inspectionExpiryDate,
  String? assigneeName,
  DateTime? leaseContractEndDate,
}) =>
    Vehicle(
      id: id,
      userId: 'u1',
      maker: maker,
      model: model,
      year: year,
      grade: grade,
      mileage: mileage,
      licensePlate: licensePlate,
      inspectionExpiryDate: inspectionExpiryDate,
      assigneeName: assigneeName,
      leaseInfo: leaseContractEndDate != null
          ? LeaseInfo(contractEndDate: leaseContractEndDate)
          : null,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  const service = FleetCsvExportService();

  group('buildCsv', () {
    test('ヘッダー行が含まれる', () {
      final result = service.buildCsv([]);
      expect(result.isSuccess, isTrue);
      final csv = result.valueOrNull!;
      expect(csv, contains('メーカー'));
      expect(csv, contains('車種'));
      expect(csv, contains('年式'));
      expect(csv, contains('走行距離'));
      expect(csv, contains('車検満了日'));
      expect(csv, contains('担当者'));
    });

    test('車両データが行として出力される', () {
      final result = service.buildCsv([
        _makeVehicle(
          maker: 'トヨタ',
          model: 'プリウス',
          year: 2022,
          grade: 'S',
          mileage: 30000,
          licensePlate: '品川 300 あ 12-34',
          inspectionExpiryDate: DateTime(2026, 9, 15),
          assigneeName: '田中太郎',
        ),
      ]);

      final csv = result.valueOrNull!;
      expect(csv, contains('トヨタ'));
      expect(csv, contains('プリウス'));
      expect(csv, contains('2022'));
      expect(csv, contains('30000'));
      expect(csv, contains('品川 300 あ 12-34'));
      expect(csv, contains('2026-09-15'));
      expect(csv, contains('田中太郎'));
    });

    test('複数車両 → ヘッダー + 台数分の行', () {
      final result = service.buildCsv([
        _makeVehicle(id: 'v1'),
        _makeVehicle(id: 'v2'),
        _makeVehicle(id: 'v3'),
      ]);

      final lines = result.valueOrNull!
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 4); // header + 3 rows
    });

    test('Excel互換: UTF-8 BOM で始まる', () {
      final result = service.buildCsv([_makeVehicle()]);
      expect(result.valueOrNull!.startsWith('﻿'), isTrue);
    });

    test('カンマを含む値はダブルクォートで囲まれる', () {
      final result = service.buildCsv([
        _makeVehicle(assigneeName: '田中,太郎'),
      ]);
      expect(result.valueOrNull!, contains('"田中,太郎"'));
    });

    test('ダブルクォートを含む値はエスケープされる', () {
      final result = service.buildCsv([
        _makeVehicle(assigneeName: '田中"太郎"'),
      ]);
      expect(result.valueOrNull!, contains('"田中""太郎"""'));
    });

    group('Edge Cases', () {
      test('空リスト → ヘッダーのみ', () {
        final result = service.buildCsv([]);
        final lines = result.valueOrNull!
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(lines.length, 1);
      });

      test('null フィールド → 空文字として出力（クラッシュしない）', () {
        final result = service.buildCsv([
          _makeVehicle(
            licensePlate: null,
            inspectionExpiryDate: null,
            assigneeName: null,
          ),
        ]);
        expect(result.isSuccess, isTrue);
      });

      test('リース満了日あり → 出力される', () {
        final result = service.buildCsv([
          _makeVehicle(leaseContractEndDate: DateTime(2027, 3, 31)),
        ]);
        expect(result.valueOrNull!, contains('2027-03-31'));
      });

      test('走行距離 0 → 0 と出力', () {
        final result = service.buildCsv([_makeVehicle(mileage: 0)]);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, contains('0'));
      });
    });

    group('Security: CSV数式インジェクション対策', () {
      test('= で始まる値 → シングルクォートで無害化される', () {
        final result = service.buildCsv([
          _makeVehicle(assigneeName: '=SUM(A1:A9)'),
        ]);
        final csv = result.valueOrNull!;
        expect(csv, isNot(contains(',=SUM')));
        expect(csv, contains("'=SUM(A1:A9)"));
      });

      test('+ - @ で始まる値も無害化される', () {
        for (final payload in ['+1+2', '-1-2', '@cmd']) {
          final result = service.buildCsv([
            _makeVehicle(assigneeName: payload),
          ]);
          final csv = result.valueOrNull!;
          expect(csv, contains("'$payload"),
              reason: 'payload: $payload should be prefixed');
        }
      });

      test('通常の日本語値は変更されない', () {
        final result = service.buildCsv([
          _makeVehicle(assigneeName: '田中太郎'),
        ]);
        expect(result.valueOrNull!, contains('田中太郎'));
        expect(result.valueOrNull!, isNot(contains("'田中太郎")));
      });
    });

    group('整備サマリー列', () {
      test('サマリーあり → 直近整備日と累計費用が出力される', () {
        final result = service.buildCsv(
          [_makeVehicle(id: 'v1')],
          maintenanceSummaries: {
            'v1': MaintenanceSummary(
              lastMaintenanceDate: DateTime(2026, 5, 20),
              totalCost: 123456,
              recordCount: 8,
            ),
          },
        );
        final csv = result.valueOrNull!;
        expect(csv, contains('直近整備日'));
        expect(csv, contains('累計整備費用'));
        expect(csv, contains('2026-05-20'));
        expect(csv, contains('123456'));
      });

      test('サマリーなしの車両 → 空欄（クラッシュしない）', () {
        final result = service.buildCsv(
          [_makeVehicle(id: 'v1'), _makeVehicle(id: 'v2')],
          maintenanceSummaries: {
            'v1': MaintenanceSummary(
              lastMaintenanceDate: DateTime(2026, 1, 1),
              totalCost: 5000,
              recordCount: 1,
            ),
          },
        );
        expect(result.isSuccess, isTrue);
        final lines = result.valueOrNull!
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(lines.length, 3);
      });

      test('整備0件のサマリー → 費用0・日付空欄', () {
        final result = service.buildCsv(
          [_makeVehicle(id: 'v1')],
          maintenanceSummaries: {
            'v1': const MaintenanceSummary(
              lastMaintenanceDate: null,
              totalCost: 0,
              recordCount: 0,
            ),
          },
        );
        expect(result.isSuccess, isTrue);
      });
    });
  });
}
