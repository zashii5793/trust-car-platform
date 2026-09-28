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
          'maintenanceAnnual': 'broken',
          'byAge': [1, 2],
        });
        final r = (await service.forVehicle(maker: 'MINI', model: 'クーパー'))
            .valueOrNull!;
        expect(r.maintenanceAnnual, isNull);
        expect(r.byAge, isEmpty);
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
  });
}
