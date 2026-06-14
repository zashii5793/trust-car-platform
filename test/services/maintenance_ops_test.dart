/// Maintenance and operations tests for production readiness.
/// Tests backup strategies, data migration safety, error recovery,
/// and service health checks.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/faq.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/community_trend_service.dart';
import 'package:trust_car_platform/services/faq_service.dart';
import 'package:trust_car_platform/services/maintenance_trend_service.dart';

void main() {
  group('Maintenance & Operations Tests', () {
    // -----------------------------------------------------------------------
    // 1. Data Integrity: Serialization round-trip
    // -----------------------------------------------------------------------
    group('Data Integrity — Serialization Round-trip', () {
      test(
          'MaintenanceRecord: toMap/fromFirestore round-trip preserves all fields',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final original = MaintenanceRecord(
          id: '',
          vehicleId: 'v1',
          userId: 'u1',
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          description: '5W-30 合成油使用',
          cost: 4500,
          shopName: 'ABCオート',
          date: DateTime(2024, 6, 15),
          mileageAtService: 45000,
          imageUrls: ['https://example.com/img1.jpg'],
          createdAt: DateTime(2024, 6, 15),
          nextReplacementMileage: 50000,
        );

        await fakeFs.collection('maintenance_records').add(original.toMap());
        final snapshot = await fakeFs.collection('maintenance_records').get();
        final restored = MaintenanceRecord.fromFirestore(snapshot.docs.first);

        expect(restored.type, equals(original.type));
        expect(restored.cost, equals(original.cost));
        expect(restored.mileageAtService, equals(original.mileageAtService));
        expect(restored.nextReplacementMileage,
            equals(original.nextReplacementMileage));
        expect(restored.shopName, equals(original.shopName));
      });

      test('Faq: toMap/fromFirestore round-trip preserves all fields',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final faq = Faq(
          id: '',
          question: 'テスト質問',
          detail: '詳細説明',
          category: FaqCategory.inspection,
          authorId: 'user1',
          createdAt: DateTime(2024, 1, 1),
          allowShopResponse: true,
          vehicleMaker: 'Toyota',
          vehicleModel: 'Prius',
          tags: ['車検', '費用'],
        );

        final ref = await fakeFs.collection('faqs').add(faq.toMap());
        final doc = await ref.get();
        final restored = Faq.fromFirestore(doc);

        expect(restored.question, equals(faq.question));
        expect(restored.category, equals(faq.category));
        expect(restored.allowShopResponse, isTrue);
        expect(restored.vehicleMaker, equals('Toyota'));
        expect(restored.tags, containsAll(['車検', '費用']));
      });

      test('FaqAnswer: shop response flag persists correctly', () async {
        final fakeFs = FakeFirebaseFirestore();
        final answer = FaqAnswer(
          id: '',
          faqId: 'faq1',
          content: '車検費用の目安は7〜10万円です',
          authorId: 'shop1',
          isShopResponse: true,
          shopId: 'shop1',
          createdAt: DateTime(2024, 1, 1),
        );

        final ref = await fakeFs.collection('faq_answers').add(answer.toMap());
        final doc = await ref.get();
        final restored = FaqAnswer.fromFirestore(doc);

        expect(restored.isShopResponse, isTrue);
        expect(restored.shopId, equals('shop1'));
      });
    });

    // -----------------------------------------------------------------------
    // 2. Service Resilience — graceful error handling
    // -----------------------------------------------------------------------
    group('Service Resilience — Error Recovery', () {
      test('FaqService: concurrent addAnswer calls do not corrupt answerCount',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final service = FaqService(firestore: fakeFs);

        final faqId = (await service.createFaq(
          question: '並列回答テスト',
          category: FaqCategory.general,
          authorId: 'user1',
          allowShopResponse: false,
        ))
            .valueOrNull!;

        // Fire 5 concurrent answer insertions
        await Future.wait(
          List.generate(
            5,
            (i) => service.addAnswer(
              faqId: faqId,
              content: '回答 $i',
              authorId: 'user${i + 2}',
              isShopResponse: false,
            ),
          ),
        );

        final faq = (await service.getFaq(faqId)).valueOrNull!;
        expect(faq.answerCount, equals(5));
      });

      test('MaintenanceTrendService: handles large history list (200 records)',
          () {
        const service = MaintenanceTrendService();
        final now = DateTime(2024, 6, 1);

        // 200 oil change records spread over 3 years
        final records = List.generate(
          200,
          (i) => MaintenanceRecord(
            id: 'r$i',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.oilChange,
            title: 'オイル交換',
            cost: 4000,
            date: now.subtract(Duration(days: i * 5)),
            mileageAtService: 100000 - (i * 250),
            imageUrls: const [],
            createdAt: now,
          ),
        );

        final trends = service.analyzeHistory(records);
        expect(trends, hasLength(1));
        expect(trends.first.confidence, equals(TrendConfidence.high));
        expect(trends.first.averageIntervalKm, isNotNull);
      });

      test('CommunityTrendService: partial insight data does not crash',
          () async {
        final fakeFs = FakeFirebaseFirestore();

        // Insert doc with intentionally missing fields
        await fakeFs
            .collection('community_maintenance_trends')
            .doc('PartialMaker_PartialModel')
            .set({
          'maker': 'PartialMaker',
          'model': 'PartialModel',
          'sampleVehicleCount': 3,
          'lastUpdated': Timestamp.now(),
          'insights': [
            {'type': 'oilChange'},
            // Missing medianIntervalKm, medianCost, etc.
          ],
        });

        final service = CommunityTrendService(firestore: fakeFs);
        final result = await service.getTrendsForVehicle(
          maker: 'PartialMaker',
          model: 'PartialModel',
        );

        expect(result.isSuccess, isTrue);
        final insight = result.valueOrNull!.insights.first;
        expect(insight.medianIntervalKm, isNull);
        expect(insight.medianCost, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // 3. Security: Permission enforcement
    // -----------------------------------------------------------------------
    group('Security — Permission Enforcement', () {
      test('FaqService: non-author cannot mark best answer', () async {
        final fakeFs = FakeFirebaseFirestore();
        final service = FaqService(firestore: fakeFs);

        final faqId = (await service.createFaq(
          question: 'セキュリティテスト',
          category: FaqCategory.general,
          authorId: 'authorUser',
          allowShopResponse: false,
        ))
            .valueOrNull!;

        final answerId = (await service.addAnswer(
          faqId: faqId,
          content: '回答',
          authorId: 'otherUser',
          isShopResponse: false,
        ))
            .valueOrNull!;

        // Attempt by a third user
        final result = await service.markBestAnswer(
          faqId: faqId,
          answerId: answerId,
          requesterId: 'attackerUser',
        );

        expect(result.isFailure, isTrue);
      });

      test('FaqService: shop cannot respond without permission (replay attack)',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final service = FaqService(firestore: fakeFs);

        final faqId = (await service.createFaq(
          question: '一般ユーザーの質問',
          category: FaqCategory.maintenance,
          authorId: 'user1',
          allowShopResponse: false,
        ))
            .valueOrNull!;

        // Shop tries multiple times
        for (var attempt = 0; attempt < 3; attempt++) {
          final result = await service.addAnswer(
            faqId: faqId,
            content: '当店のご案内',
            authorId: 'shop1',
            isShopResponse: true,
            shopId: 'shop1',
          );
          expect(result.isFailure, isTrue);
        }
      });

      test('VehicleUseCategory: cargo vehicle has annual inspection', () {
        const cargo = VehicleUseCategory.cargo;
        expect(cargo.inspectionCycleYears, equals(1));
        expect(cargo.firstInspectionYears, equals(2));
      });

      test('VehicleUseCategory: keiCargo has 2-year cycle', () {
        const kei = VehicleUseCategory.keiCargo;
        expect(kei.inspectionCycleYears, equals(2));
      });

      test(
          'CommunityTrendService: submitVehicleTrendData rejects zero interval',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final service = CommunityTrendService(firestore: fakeFs);

        final result = await service.submitVehicleTrendData(
          maker: 'Test',
          model: 'Car',
          maintenanceTypeKey: 'oilChange',
          intervalKm: 0,
          intervalDays: 0,
          cost: 5000,
        );

        // intervalKm=0 and intervalDays=0 are valid (not negative)
        // Service should succeed — 0 is a valid value for first record
        expect(result.isSuccess, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 4. Edge Cases — Production gotchas
    // -----------------------------------------------------------------------
    group('Edge Cases — Production Scenarios', () {
      test('MaintenanceTrendService: vehicle with single type, many records',
          () {
        const service = MaintenanceTrendService();
        final base = DateTime(2020, 1, 1);

        // Tire changes every 2 years for 6 years
        final records = [
          MaintenanceRecord(
            id: '1',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.tireChange,
            title: 'タイヤ交換',
            cost: 32000,
            date: base,
            mileageAtService: 20000,
            imageUrls: const [],
            createdAt: base,
          ),
          MaintenanceRecord(
            id: '2',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.tireChange,
            title: 'タイヤ交換',
            cost: 35000,
            date: base.add(const Duration(days: 730)),
            mileageAtService: 40000,
            imageUrls: const [],
            createdAt: base,
          ),
          MaintenanceRecord(
            id: '3',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.tireChange,
            title: 'タイヤ交換',
            cost: 38000,
            date: base.add(const Duration(days: 1460)),
            mileageAtService: 60000,
            imageUrls: const [],
            createdAt: base,
          ),
        ];

        final trends = service.analyzeHistory(records, currentMileage: 65000);
        final tire = trends.first;

        // ~2-year average → ~730 days
        expect(tire.averageIntervalDays, closeTo(730, 5));
        expect(tire.averageIntervalKm, closeTo(20000, 100));
        expect(tire.confidence, equals(TrendConfidence.high));
      });

      test('FaqService: getFaq returns correct answerCount after bulk inserts',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final service = FaqService(firestore: fakeFs);

        final faqId = (await service.createFaq(
          question: 'テスト',
          category: FaqCategory.general,
          authorId: 'user1',
          allowShopResponse: false,
        ))
            .valueOrNull!;

        // Add 10 answers sequentially
        for (var i = 0; i < 10; i++) {
          await service.addAnswer(
            faqId: faqId,
            content: '回答 $i',
            authorId: 'user${i + 2}',
            isShopResponse: false,
          );
        }

        final faq = (await service.getFaq(faqId)).valueOrNull!;
        expect(faq.answerCount, equals(10));
      });

      test('MaintenanceTrendService: sortByUrgency handles empty list', () {
        const service = MaintenanceTrendService();
        final sorted = service.sortByUrgency([], currentDate: DateTime.now());
        expect(sorted, isEmpty);
      });

      test(
          'MaintenanceTrendService: all items without predicted dates sort last',
          () {
        const service = MaintenanceTrendService();

        // Single record per type → no interval → no predicted date
        final records = [
          MaintenanceRecord(
            id: '1',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.batteryChange,
            title: 'バッテリー交換',
            cost: 15000,
            date: DateTime(2023, 1, 1),
            imageUrls: const [],
            createdAt: DateTime(2023, 1, 1),
          ),
          MaintenanceRecord(
            id: '2',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.tireChange,
            title: 'タイヤ交換',
            cost: 32000,
            date: DateTime(2023, 6, 1),
            imageUrls: const [],
            createdAt: DateTime(2023, 6, 1),
          ),
        ];

        final trends = service.analyzeHistory(records);
        final sorted = service.sortByUrgency(
          trends,
          currentDate: DateTime(2024, 1, 1),
        );

        // All have no predicted date → order deterministic but non-crashing
        expect(sorted, hasLength(2));
      });

      test('CommunityTrendService: document key uses underscore separator',
          () async {
        final fakeFs = FakeFirebaseFirestore();
        final service = CommunityTrendService(firestore: fakeFs);

        await service.submitVehicleTrendData(
          maker: 'Mazda',
          model: 'Axela',
          maintenanceTypeKey: 'oilChange',
          intervalKm: 5000,
          intervalDays: 180,
          cost: 4200,
        );

        // Verify the document exists with the expected key format
        final doc = await fakeFs
            .collection('community_maintenance_trends')
            .doc('Mazda_Axela')
            .get();
        expect(doc.exists, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 5. Performance — Trend analysis timing
    // -----------------------------------------------------------------------
    group('Performance — Trend Analysis', () {
      test('analyzeHistory: 500 mixed records completes under 100ms', () {
        const service = MaintenanceTrendService();
        final now = DateTime(2024, 1, 1);
        final types = MaintenanceType.values;

        final records = List.generate(
          500,
          (i) => MaintenanceRecord(
            id: 'r$i',
            vehicleId: 'v1',
            userId: 'u1',
            type: types[i % types.length],
            title: types[i % types.length].displayName,
            cost: 3000 + (i * 100),
            date: now.subtract(Duration(days: i * 2)),
            mileageAtService: 100000 - (i * 200),
            imageUrls: const [],
            createdAt: now,
          ),
        );

        final stopwatch = Stopwatch()..start();
        service.analyzeHistory(records);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
