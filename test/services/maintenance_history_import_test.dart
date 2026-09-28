import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/maintenance_history_import.dart';
import 'package:trust_car_platform/services/maintenance_history_import_service.dart';

/// 車両登録時に、過去の整備記録をまとめて移す。
void main() {
  final today = DateTime(2026, 9, 28);

  HistoryImportPlan planOf(String csv) {
    final table = parseCsv(csv);
    return buildHistoryImportPlan(
      table.sublist(1),
      guessHistoryImportColumns(table.first),
      today: today,
    );
  }

  group('記入用フォーマット', () {
    test('配ったフォーマットを、何も書かずに戻しても0件（記入例は取り込まない）', () {
      final plan = planOf(historyTemplateCsv());
      expect(plan.rows, isEmpty);
      expect(plan.problems, isEmpty);
    });

    test('Excel で開けるよう BOM 付き。見出しは全部自動で当たる', () {
      final csv = historyTemplateCsv();
      expect(csv.startsWith('﻿'), isTrue);
      final cols = guessHistoryImportColumns(parseCsv(csv).first);
      expect(cols.keys.toSet(), HistoryField.values.toSet());
    });

    test('記入したものが取り込める', () {
      final plan = planOf('${historyTemplateCsv()}'
          '2023/4/10,車検,24か月点検・車検,"128,000",42000,タカヤモーター,\r\n'
          'R5.10.2,オイル交換,,8800円,45500km,,\r\n');
      expect(plan.rows, hasLength(2));
      final first = plan.rows.first;
      expect(first.type, MaintenanceType.carInspection);
      expect(first.title, '24か月点検・車検');
      expect(first.cost, 128000);
      expect(first.mileage, 42000);
      expect(first.shopName, 'タカヤモーター');
      // 内容が空なら、種類を内容にする
      expect(plan.rows.last.title, 'オイル交換');
      expect(plan.rows.last.cost, 8800);
      expect(plan.rows.last.mileage, 45500);
      expect(plan.totalCost, 136800);
      expect(plan.from, DateTime(2023, 4, 10));
    });
  });

  group('guessMaintenanceType', () {
    test('書き方が揺れても種類を当てる', () {
      expect(guessMaintenanceType('24ヶ月点検と車検'), MaintenanceType.carInspection);
      expect(guessMaintenanceType('12か月点検'), MaintenanceType.legalInspection12);
      expect(guessMaintenanceType('ｵｲﾙ交換'), MaintenanceType.oilChange);
      expect(
          guessMaintenanceType('オイル・エレメント交換'), MaintenanceType.oilFilterChange);
      expect(guessMaintenanceType('スタッドレスタイヤ'), MaintenanceType.tireChange);
      expect(
          guessMaintenanceType('ブレーキフルード'), MaintenanceType.brakeFluidChange);
      expect(guessMaintenanceType('バッテリー'), MaintenanceType.batteryChange);
    });

    group('Edge Cases', () {
      test('分からなければ「その他」（修理扱いにしない）', () {
        expect(guessMaintenanceType('よく分からない作業'), MaintenanceType.other);
        expect(guessMaintenanceType(''), MaintenanceType.other);
        expect(guessMaintenanceType(null), MaintenanceType.other);
      });
    });
  });

  group('buildHistoryImportPlan — Edge Cases', () {
    test('日付が読めない・未来・金額が読めない行は、理由つきで外す', () {
      final plan = planOf('実施日,内容,金額\n'
          ',車検,1000\n'
          '2026/2/30,車検,1000\n'
          '2027/1/1,車検予定,1000\n'
          '2026/1/1,車検,サービス\n');
      expect(plan.rows, isEmpty);
      expect(plan.problems.map((p) => p.line), [2, 3, 4, 5]);
      expect(plan.problems[2].message, contains('未来'));
    });

    test('金額が空なら0円として入れる（無料点検など）', () {
      final plan = planOf('実施日,内容,金額\n2026/1/1,無料点検,\n');
      expect(plan.rows.single.cost, 0);
    });

    test('空の行は飛ばす', () {
      final plan = planOf('実施日,内容,金額\n,,\n2026/1/1,点検,0\n');
      expect(plan.rows, hasLength(1));
      expect(plan.problems, isEmpty);
    });
  });

  group('MaintenanceHistoryImportService', () {
    late FakeFirebaseFirestore fs;
    late MaintenanceHistoryImportService service;

    setUp(() {
      fs = FakeFirebaseFirestore();
      service =
          MaintenanceHistoryImportService(firestore: fs, now: () => today);
    });

    List<HistoryImportRow> rows() => planOf('実施日,種類,金額\n'
            '2023/4/10,車検,128000\n'
            '2024/4/1,オイル交換,8800\n')
        .rows;

    test('本人の、この車の自己申告の記録として入る', () async {
      final r = (await service.importRows(
        userId: 'u1',
        vehicleId: 'v1',
        rows: rows(),
      ))
          .valueOrNull!;
      expect(r.added, 2);
      final docs = await fs.collection('maintenance_records').get();
      expect(docs.docs, hasLength(2));
      final d = docs.docs.first.data();
      expect(d['userId'], 'u1');
      expect(d['vehicleId'], 'v1');
      expect(d['verificationSource'], 'selfReported');
    });

    test('同じファイルを2回取り込んでも二重にならない', () async {
      await service.importRows(userId: 'u1', vehicleId: 'v1', rows: rows());
      final second = (await service.importRows(
        userId: 'u1',
        vehicleId: 'v1',
        rows: rows(),
      ))
          .valueOrNull!;
      expect(second.added, 0);
      expect(second.skipped, 2);
      expect((await fs.collection('maintenance_records').get()).docs,
          hasLength(2));
    });

    test('取り込んだあとに本人が直した記録を、取り直しで上書きしない', () async {
      await service.importRows(userId: 'u1', vehicleId: 'v1', rows: rows());
      final id = MaintenanceHistoryImportService.idFor('v1', rows().first);
      await fs
          .collection('maintenance_records')
          .doc(id)
          .update({'description': '本人のメモ'});
      await service.importRows(userId: 'u1', vehicleId: 'v1', rows: rows());
      final d =
          (await fs.collection('maintenance_records').doc(id).get()).data()!;
      expect(d['description'], '本人のメモ');
    });

    test('別の車に取り込めば、別の記録になる', () async {
      await service.importRows(userId: 'u1', vehicleId: 'v1', rows: rows());
      final r = (await service.importRows(
        userId: 'u1',
        vehicleId: 'v2',
        rows: rows(),
      ))
          .valueOrNull!;
      expect(r.added, 2);
    });

    group('Edge Cases', () {
      test('車が決まっていなければ取り込まない', () async {
        final r = await service.importRows(
          userId: 'u1',
          vehicleId: '',
          rows: rows(),
        );
        expect(r.isFailure, isTrue);
      });

      test('行が無ければ何もしない', () async {
        final r = (await service.importRows(
          userId: 'u1',
          vehicleId: 'v1',
          rows: const [],
        ))
            .valueOrNull!;
        expect(r.added, 0);
      });
    });
  });
}
