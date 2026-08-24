import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/community_trend_service.dart';

void main() {
  group('CommunityTrendService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CommunityTrendService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = CommunityTrendService(firestore: fakeFirestore);
    });

    Future<void> seedTrendData({
      String maker = 'Toyota',
      String model = 'Prius',
      int sampleCount = 45,
      List<Map<String, dynamic>>? insights,
    }) async {
      final defaultInsights = insights ??
          [
            {
              'type': 'oilChange',
              'medianIntervalKm': 5000.0,
              'medianIntervalDays': 180.0,
              'medianCost': 4500.0,
              'sampleCount': 42,
              'popularityPercent': 93.0,
            },
            {
              'type': 'tireChange',
              'medianIntervalKm': 30000.0,
              'medianIntervalDays': 730.0,
              'medianCost': 35000.0,
              'sampleCount': 38,
              'popularityPercent': 84.0,
            },
          ];

      await fakeFirestore
          .collection('community_maintenance_trends')
          .doc('${maker}_$model')
          .set({
        'maker': maker,
        'model': model,
        'sampleVehicleCount': sampleCount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
        'insights': defaultInsights,
      });
    }

    group('getTrendsForVehicle', () {
      test('正常系: 同車種のコミュニティトレンドを取得する', () async {
        await seedTrendData();

        final result = await service.getTrendsForVehicle(
          maker: 'Toyota',
          model: 'Prius',
        );

        expect(result.isSuccess, isTrue);
        final data = result.valueOrNull!;
        expect(data.maker, equals('Toyota'));
        expect(data.model, equals('Prius'));
        expect(data.sampleVehicleCount, equals(45));
        expect(data.insights, hasLength(2));
      });

      test('正常系: オイル交換トレンドの詳細を確認する', () async {
        await seedTrendData();

        final result = await service.getTrendsForVehicle(
          maker: 'Toyota',
          model: 'Prius',
        );

        final data = result.valueOrNull!;
        final oilInsight = data.insights.firstWhere(
          (i) => i.typeKey == 'oilChange',
        );

        expect(oilInsight.medianIntervalKm, equals(5000.0));
        expect(oilInsight.medianCost, equals(4500.0));
        expect(oilInsight.popularityPercent, equals(93.0));
      });

      test('正常系: descriptionが日本語で生成される', () async {
        await seedTrendData();

        final result = await service.getTrendsForVehicle(
          maker: 'Toyota',
          model: 'Prius',
        );

        final data = result.valueOrNull!;
        final oilInsight = data.insights.firstWhere(
          (i) => i.typeKey == 'oilChange',
        );

        expect(oilInsight.description, contains('Prius'));
        expect(oilInsight.description, isNotEmpty);
      });

      test('異常系: データなしは insufficientData エラーを返す', () async {
        final result = await service.getTrendsForVehicle(
          maker: 'Unknown',
          model: 'Model',
        );

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull!.message, contains('insufficient'));
      });

      test('正常系: 複数メーカーのデータが独立している', () async {
        await seedTrendData(maker: 'Toyota', model: 'Prius');
        await seedTrendData(
          maker: 'Honda',
          model: 'Fit',
          sampleCount: 30,
        );

        final toyota = await service.getTrendsForVehicle(
          maker: 'Toyota',
          model: 'Prius',
        );
        final honda = await service.getTrendsForVehicle(
          maker: 'Honda',
          model: 'Fit',
        );

        expect(toyota.valueOrNull!.sampleVehicleCount, equals(45));
        expect(honda.valueOrNull!.sampleVehicleCount, equals(30));
      });

      group('Edge Cases', () {
        test('空文字のmaker/modelはエラーを返す', () async {
          final result = await service.getTrendsForVehicle(
            maker: '',
            model: '',
          );
          expect(result.isFailure, isTrue);
        });

        test('insightsが空配列でも成功する', () async {
          await seedTrendData(insights: []);

          final result = await service.getTrendsForVehicle(
            maker: 'Toyota',
            model: 'Prius',
          );

          expect(result.isSuccess, isTrue);
          expect(result.valueOrNull!.insights, isEmpty);
        });

        test('sampleVehicleCount が 0 でも成功する（将来のデータ蓄積用）', () async {
          await fakeFirestore
              .collection('community_maintenance_trends')
              .doc('Suzuki_Alto')
              .set({
            'maker': 'Suzuki',
            'model': 'Alto',
            'sampleVehicleCount': 0,
            'lastUpdated': Timestamp.now(),
            'insights': [],
          });

          final result = await service.getTrendsForVehicle(
            maker: 'Suzuki',
            model: 'Alto',
          );

          expect(result.isSuccess, isTrue);
          expect(result.valueOrNull!.sampleVehicleCount, equals(0));
        });
      });
    });

    group('submitVehicleTrendData', () {
      test('正常系: 新規データを登録できる', () async {
        final result = await service.submitVehicleTrendData(
          maker: 'Nissan',
          model: 'Note',
          maintenanceTypeKey: 'oilChange',
          intervalKm: 5000,
          intervalDays: 180,
          cost: 3800,
        );

        expect(result.isSuccess, isTrue);
      });

      test('正常系: 既存データに新しいサンプルが加算される', () async {
        await seedTrendData(maker: 'Nissan', model: 'Note', sampleCount: 10);

        await service.submitVehicleTrendData(
          maker: 'Nissan',
          model: 'Note',
          maintenanceTypeKey: 'oilChange',
          intervalKm: 5000,
          intervalDays: 180,
          cost: 3800,
        );

        final result = await service.getTrendsForVehicle(
          maker: 'Nissan',
          model: 'Note',
        );

        // Sample count should have incremented
        expect(result.valueOrNull!.sampleVehicleCount, greaterThan(10));
      });

      group('Edge Cases', () {
        test('空文字のmakerはバリデーションエラー', () async {
          final result = await service.submitVehicleTrendData(
            maker: '',
            model: 'Note',
            maintenanceTypeKey: 'oilChange',
            intervalKm: 5000,
            intervalDays: 180,
            cost: 3800,
          );
          expect(result.isFailure, isTrue);
        });

        test('負のintervalKmはバリデーションエラー', () async {
          final result = await service.submitVehicleTrendData(
            maker: 'Nissan',
            model: 'Note',
            maintenanceTypeKey: 'oilChange',
            intervalKm: -100,
            intervalDays: 180,
            cost: 3800,
          );
          expect(result.isFailure, isTrue);
        });
      });
    });
  });

  // 「あなたのクルマの1年」で、同じ車種の人の年間費用と比べるために使う
  // （docs/HABIT_DESIGN.md 打ち手2）。**自分の数字だけでは良し悪しが
  // 分からない。** 比べて初めて見たくなる。
  //
  // トレンドは「この整備を中央値で何日ごとに、いくらで」しか持っていないので、
  // 1年あたりに割り戻して足し合わせる。
  group('CommunityTrendData.estimatedAnnualCost', () {
    CommunityTrendInsight insight({
      required String typeKey,
      double? cost,
      double? intervalDays,
      int sampleCount = 10,
    }) {
      return CommunityTrendInsight(
        typeKey: typeKey,
        medianCost: cost,
        medianIntervalDays: intervalDays,
        sampleCount: sampleCount,
      );
    }

    CommunityTrendData data(List<CommunityTrendInsight> insights) {
      return CommunityTrendData(
        maker: 'トヨタ',
        model: 'プリウス',
        sampleVehicleCount: 42,
        lastUpdated: DateTime(2026, 8, 1),
        insights: insights,
      );
    }

    test('半年ごとの整備は年2回分として数える', () {
      final result = data([
        insight(typeKey: 'oilChange', cost: 5000, intervalDays: 182.5),
      ]).estimatedAnnualCost;

      expect(result, 10000);
    });

    test('2年ごとの整備は年半分として数える', () {
      final result = data([
        insight(typeKey: 'legalInspection24', cost: 80000, intervalDays: 730),
      ]).estimatedAnnualCost;

      expect(result, 40000);
    });

    test('複数の整備を足し合わせる', () {
      final result = data([
        insight(typeKey: 'oilChange', cost: 5000, intervalDays: 182.5),
        insight(typeKey: 'legalInspection24', cost: 80000, intervalDays: 730),
      ]).estimatedAnnualCost;

      expect(result, 50000);
    });

    group('Edge Cases', () {
      test('金額が無い項目は飛ばす', () {
        final result = data([
          insight(typeKey: 'oilChange', cost: null, intervalDays: 182.5),
          insight(typeKey: 'tire', cost: 40000, intervalDays: 365),
        ]).estimatedAnnualCost;

        expect(result, 40000);
      });

      test('周期が無い項目は飛ばす（何回分か分からない）', () {
        final result = data([
          insight(typeKey: 'oilChange', cost: 5000, intervalDays: null),
        ]).estimatedAnnualCost;

        expect(result, isNull);
      });

      test('周期が0以下なら飛ばす（0除算になる）', () {
        final result = data([
          insight(typeKey: 'oilChange', cost: 5000, intervalDays: 0),
        ]).estimatedAnnualCost;

        expect(result, isNull);
      });

      test('使える項目が1つも無ければ null', () {
        expect(data([]).estimatedAnnualCost, isNull);
      });

      test('件数が少なすぎる項目は使わない（1台の実績を平均と呼ばない）', () {
        final result = data([
          insight(
            typeKey: 'oilChange',
            cost: 5000,
            intervalDays: 182.5,
            sampleCount: 1,
          ),
        ]).estimatedAnnualCost;

        expect(result, isNull);
      });
    });
  });
}
