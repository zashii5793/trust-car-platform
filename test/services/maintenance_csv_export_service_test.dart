// 整備記録を CSV で持ち出す。
//
// なぜ要るか:
//   売るときに記録を渡せることが、このアプリの値打ちの1つ。PDF は
//   「読むもの」で、買い手や次のオーナーが**自分で扱う**には表形式が要る。
//
//   個人向けの出力は PDF（愛車カルテ・整備履歴レポート）だけで、CSV は
//   法人のフリート用しか無かった（2026-09-22 実測）。しかもフリート版は
//   車両1台1行で、**整備の明細は出ない**（集計2列だけ）。
//
// 工場が発行した記録かどうかも列に入れる。**自己申告と区別できない
// 表を渡しても、査定では使えない。**

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/maintenance_csv_export_service.dart';

Vehicle _vehicle() => Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'Toyota',
      model: 'Hiace',
      year: 2022,
      grade: 'DX',
      mileage: 96000,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

MaintenanceRecord _record({
  String id = 'r1',
  String title = 'エンジンオイル交換',
  int cost = 6000,
  DateTime? date,
  int? mileage,
  String? shopName,
  String? inquiryId,
}) =>
    MaintenanceRecord(
      id: id,
      vehicleId: 'v1',
      userId: 'u1',
      type: MaintenanceType.oilChange,
      title: title,
      cost: cost,
      date: date ?? DateTime(2026, 3, 1),
      createdAt: date ?? DateTime(2026, 3, 1),
      mileageAtService: mileage,
      shopName: shopName,
      inquiryId: inquiryId,
    );

void main() {
  const service = MaintenanceCsvExportService();

  group('buildCsv', () {
    test('見出しと1行が出る', () {
      final csv = service.buildCsv(
        vehicle: _vehicle(),
        records: [_record(mileage: 90000, shopName: 'タカヤモーター')],
      ).valueOrNull!;

      expect(csv, contains('実施日'));
      expect(csv, contains('エンジンオイル交換'));
      expect(csv, contains('90000'));
      expect(csv, contains('タカヤモーター'));
    });

    test('新しい順に並ぶ', () {
      final csv = service.buildCsv(
        vehicle: _vehicle(),
        records: [
          _record(id: 'r1', title: '古い整備', date: DateTime(2025, 1, 1)),
          _record(id: 'r2', title: '新しい整備', date: DateTime(2026, 8, 1)),
        ],
      ).valueOrNull!;

      expect(csv.indexOf('新しい整備'), lessThan(csv.indexOf('古い整備')));
    });

    // 自己申告と工場発行を区別できない表は、査定に使えない。
    test('工場を通った記録かどうかが分かる', () {
      final csv = service.buildCsv(
        vehicle: _vehicle(),
        records: [
          _record(id: 'r1', title: '自分でやった', inquiryId: null),
          _record(id: 'r2', title: '工場でやった', inquiryId: 'inq_1'),
        ],
      ).valueOrNull!;

      expect(csv, contains('出所'));
      expect(csv, contains('工場'));
      expect(csv, contains('自己申告'));
    });

    test('Excel で文字化けしないよう BOM が付く', () {
      final csv = service.buildCsv(
        vehicle: _vehicle(),
        records: [_record()],
      ).valueOrNull!;

      expect(csv.codeUnitAt(0), 0xFEFF);
    });

    // フリート版と同じ用心。= で始まる値は数式として実行されうる。
    test('数式として実行されうる値を無害化する', () {
      final csv = service.buildCsv(
        vehicle: _vehicle(),
        records: [_record(title: '=SUM(A1:A9)')],
      ).valueOrNull!;

      expect(csv, contains("'=SUM(A1:A9)"));
    });

    test('カンマを含む値はクォートされる', () {
      final csv = service.buildCsv(
        vehicle: _vehicle(),
        records: [_record(title: 'オイル,エレメント交換')],
      ).valueOrNull!;

      expect(csv, contains('"オイル,エレメント交換"'));
    });

    group('Edge Cases', () {
      test('記録が0件でも見出しだけは出る', () {
        final csv = service.buildCsv(
          vehicle: _vehicle(),
          records: const [],
        ).valueOrNull!;

        expect(csv, contains('実施日'));
      });

      test('走行距離や工場名が無くても落ちない', () {
        final result = service.buildCsv(
          vehicle: _vehicle(),
          records: [_record(mileage: null, shopName: null)],
        );

        expect(result.isSuccess, isTrue);
      });
    });
  });
}
