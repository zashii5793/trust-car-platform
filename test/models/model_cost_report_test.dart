import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/model_cost_report.dart';
import 'package:trust_car_platform/services/model_cost_report_service.dart';

void main() {
  group('modelCostKey', () {
    // サーバー側（functions/__tests__/modelCostReport.test.ts）も同じ表を読む。
    // ずれると、アプリが引くIDとサーバーが書くIDが食い違う。
    final vectors = (jsonDecode(
      File('test/fixtures/model_cost_key_vectors.json').readAsStringSync(),
    ) as List)
        .cast<List>();

    test('サーバーと同じ表が2か所にあり、中身が同じ', () {
      final server = File('functions/__tests__/model_cost_key_vectors.json')
          .readAsStringSync();
      final app =
          File('test/fixtures/model_cost_key_vectors.json').readAsStringSync();
      expect(app, server);
    });

    for (final v in vectors) {
      test('${jsonEncode(v[0])} → ${jsonEncode(v[1])}', () {
        expect(modelCostKey(v[0] as String), v[1]);
      });
    }

    test('車種のIDは メーカー__車種', () {
      expect(modelCostReportId('MINI', 'クーパー'), 'mini__くーぱー');
    });
  });

  group('ModelCostReportService.forVehicle', () {
    late FakeFirebaseFirestore fs;
    late ModelCostReportService service;

    setUp(() {
      fs = FakeFirebaseFirestore();
      service = ModelCostReportService(firestore: fs);
    });

    Future<void> put(String id, Map<String, dynamic> data) =>
        fs.collection('model_cost_reports').doc(id).set(data);

    test('表記が違っても、車種のレポートを引ける', () async {
      await put('mini__くーぱー', {
        'level': 'model',
        'maker': 'MINI',
        'model': 'クーパー',
        'ownerCount': 12,
        'annualEstimate': 180000,
        'maintenanceAnnual': {
          'median': 60000,
          'p25': 40000,
          'p75': 90000,
          'n': 12
        },
        'sources': {'app': 7, 'shop': 5},
      });
      final r = (await service.forVehicle(maker: 'ＭＩＮＩ', model: 'ｸｰﾊﾟｰ'))
          .valueOrNull!;
      expect(r.title, 'MINI クーパー');
      expect(r.isMakerLevel, isFalse);
      expect(r.annualEstimate, 180000);
      expect(r.maintenanceAnnual!.p75, 90000);
      expect(r.shopOwners, 5);
    });

    test('車種が無ければ、メーカー全体を返す', () async {
      await put('mini', {
        'level': 'maker',
        'maker': 'MINI',
        'model': null,
        'ownerCount': 8,
      });
      final r = (await service.forVehicle(maker: 'MINI', model: 'クラブマン'))
          .valueOrNull!;
      expect(r.isMakerLevel, isTrue);
      expect(r.title, 'MINI（メーカー全体）');
    });

    group('Edge Cases', () {
      test('どちらも無ければ null（推定で埋めない）', () async {
        final r = await service.forVehicle(maker: 'MINI', model: 'クーパー');
        expect(r.isSuccess, isTrue);
        expect(r.valueOrNull, isNull);
      });

      test('メーカーが空なら null', () async {
        final r = await service.forVehicle(maker: ' ', model: 'クーパー');
        expect(r.valueOrNull, isNull);
      });

      test('壊れた値が入っていても落ちない', () async {
        await put('mini__くーぱー', {
          'level': 'model',
          'maker': 'MINI',
          'model': 'クーパー',
          'ownerCount': 12,
          'maintenanceAnnual': 'broken',
          'byAge': [1, 2],
        });
        final r = (await service.forVehicle(maker: 'MINI', model: 'クーパー'))
            .valueOrNull!;
        expect(r.maintenanceAnnual, isNull);
        expect(r.byAge, isEmpty);
      });

      test('車種のレポートが持ち主4人なら使わず、メーカー全体へ回る', () async {
        await put('mini__くーぱー', {
          'level': 'model',
          'maker': 'MINI',
          'model': 'クーパー',
          'ownerCount': 4,
          'annualEstimate': 999999,
        });
        await put('mini', {
          'level': 'maker',
          'maker': 'MINI',
          'model': null,
          'ownerCount': 20,
        });
        final r = (await service.forVehicle(maker: 'MINI', model: 'クーパー'))
            .valueOrNull!;
        expect(r.isMakerLevel, isTrue);
      });

      test('メーカー全体も持ち主4人なら null', () async {
        await put('mini', {
          'level': 'maker',
          'maker': 'MINI',
          'model': null,
          'ownerCount': 4,
        });
        final r = await service.forVehicle(maker: 'MINI', model: 'クーパー');
        expect(r.isSuccess, isTrue);
        expect(r.valueOrNull, isNull);
      });

      test('持ち主の人数が無いレポートは出さない（5人以上か確かめられない）', () async {
        await put('mini__くーぱー', {
          'level': 'model',
          'maker': 'MINI',
          'model': 'クーパー',
          'annualEstimate': 180000,
        });
        final r = await service.forVehicle(maker: 'MINI', model: 'クーパー');
        expect(r.valueOrNull, isNull);
      });
    });
  });

  // 持ち主が5人に満たない数字は出さない（functions の MIN_OWNERS と同じ）。
  // サーバーは書かない決まりだが、古い集計や手で入れた値が残っていても
  // アプリで出さないことを確かめる。
  group('5人に満たない数字は出さない', () {
    Map<String, dynamic> stat(int n, int median) =>
        {'median': median, 'p25': median, 'p75': median, 'n': n};

    test('下限はサーバーと同じ5人', () {
      expect(modelCostMinOwners, 5);
      final server =
          File('functions/src/modelCostReport.ts').readAsStringSync();
      expect(server, contains('export const MIN_OWNERS = 5;'));
    });

    test('持ち主5人のレポートは出せる・4人は出せない', () {
      expect(ModelCostReport.fromMap('a', {'ownerCount': 5}).isPublishable,
          isTrue);
      expect(ModelCostReport.fromMap('a', {'ownerCount': 4}).isPublishable,
          isFalse);
    });

    test('内訳は5人なら出し、4人なら出さない', () {
      final r = ModelCostReport.fromMap('a', {
        'ownerCount': 12,
        'maintenanceAnnual': stat(5, 60000),
        'inspectionPerEvent': stat(4, 120000),
      });
      expect(r.maintenanceAnnual!.median, 60000);
      expect(r.inspectionPerEvent, isNull);
    });

    test('内訳を落としたら、年の目安は残った内訳から作り直す', () {
      final r = ModelCostReport.fromMap('a', {
        'ownerCount': 12,
        'maintenanceAnnual': stat(12, 60000),
        'inspectionPerEvent': stat(9, 120000),
        'fuelAnnual': stat(4, 62000),
        // サーバーが燃料も足した値（燃料は4人しかいないので出してはいけない）
        'annualEstimate': 182000,
      });
      expect(r.fuelAnnual, isNull);
      expect(r.annualEstimate, 60000 + 60000);
    });

    test('落とした内訳が無ければ、サーバーの年の目安をそのまま使う', () {
      final r = ModelCostReport.fromMap('a', {
        'ownerCount': 12,
        'maintenanceAnnual': stat(12, 60000),
        'inspectionPerEvent': stat(9, 120000),
        'annualEstimate': 120000,
      });
      expect(r.annualEstimate, 120000);
    });

    test('整備が出せなければ、年の目安も出さない', () {
      final r = ModelCostReport.fromMap('a', {
        'ownerCount': 12,
        'maintenanceAnnual': stat(4, 60000),
        'fuelAnnual': stat(12, 62000),
        'annualEstimate': 122000,
      });
      expect(r.maintenanceAnnual, isNull);
      expect(r.annualEstimate, isNull);
    });

    test('年数ごと・よくある整備も、5人に満たないものは出さない', () {
      final r = ModelCostReport.fromMap('a', {
        'ownerCount': 12,
        'byAge': [
          {'label': '1〜3年目', 'median': 50000, 'n': 5},
          {'label': '4〜6年目', 'median': 90000, 'n': 4},
        ],
        'topItems': [
          {'type': 'オイル交換', 'owners': 5, 'medianCost': 8800},
          {'type': 'タイヤ交換', 'owners': 4, 'medianCost': 80000},
        ],
      });
      expect(r.byAge.map((e) => e.label), ['1〜3年目']);
      expect(r.topItems.map((e) => e.type), ['オイル交換']);
    });

    group('Edge Cases', () {
      test('人数が無い内訳は出さない', () {
        final r = ModelCostReport.fromMap('a', {
          'ownerCount': 12,
          'maintenanceAnnual': {'median': 60000, 'p25': 1, 'p75': 2},
          'annualEstimate': 60000,
        });
        expect(r.maintenanceAnnual, isNull);
        expect(r.annualEstimate, isNull);
      });

      test('人数が負の数でも出さない', () {
        expect(ModelCostReport.fromMap('a', {'ownerCount': -1}).isPublishable,
            isFalse);
        expect(CostStat.fromMap(stat(-1, 100)), isNull);
      });
    });
  });

  group('listAvailable', () {
    test('持ち主の多い順', () async {
      final fs = FakeFirebaseFirestore();
      final service = ModelCostReportService(firestore: fs);
      await fs.collection('model_cost_reports').doc('a').set({
        'maker': 'A',
        'model': 'a',
        'ownerCount': 5,
      });
      await fs.collection('model_cost_reports').doc('b').set({
        'maker': 'B',
        'model': 'b',
        'ownerCount': 50,
      });
      final list = (await service.listAvailable()).valueOrNull!;
      expect(list.map((r) => r.id), ['b', 'a']);
    });

    group('Edge Cases', () {
      test('持ち主4人のレポートは一覧に出さない（5人は出す）', () async {
        final fs = FakeFirebaseFirestore();
        final service = ModelCostReportService(firestore: fs);
        await fs.collection('model_cost_reports').doc('four').set({
          'maker': 'A',
          'model': 'four',
          'ownerCount': 4,
        });
        await fs.collection('model_cost_reports').doc('five').set({
          'maker': 'A',
          'model': 'five',
          'ownerCount': 5,
        });
        final list = (await service.listAvailable()).valueOrNull!;
        expect(list.map((r) => r.id), ['five']);
      });

      test('レポートが1件も無ければ空', () async {
        final service =
            ModelCostReportService(firestore: FakeFirebaseFirestore());
        final r = await service.listAvailable();
        expect(r.isSuccess, isTrue);
        expect(r.valueOrNull, isEmpty);
      });
    });
  });
}
