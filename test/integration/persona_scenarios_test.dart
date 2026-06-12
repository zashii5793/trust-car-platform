// ペルソナ別総合シナリオテスト
//
// 実際のユーザー像に基づいた end-to-end シナリオを検証する:
//   Persona A: 個人オーナー — 4台所有（うち1台は貨物車、1台はリース）
//   Persona B: 中小企業 — 20台フリート。総務担当が車検・点検を一括管理
//   Persona C: 近所に3つの整備工場 — 特徴の違いを比較して問い合わせ
//
// Firebase は FakeCloudFirestore で代替（emulator 不要）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/faq.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/community_trend_service.dart';
import 'package:trust_car_platform/services/faq_service.dart';
import 'package:trust_car_platform/services/fleet_csv_export_service.dart';
import 'package:trust_car_platform/services/fleet_inquiry_composer.dart';
import 'package:trust_car_platform/services/fleet_service.dart';
import 'package:trust_car_platform/services/maintenance_trend_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _vehicle({
  String id = 'v1',
  String userId = 'user-a',
  String maker = 'Toyota',
  String model = 'Prius',
  String? licensePlate,
  DateTime? inspectionExpiryDate,
  VehicleUseCategory? useCategory,
  LeaseInfo? leaseInfo,
  String? companyId,
  String? assigneeName,
}) {
  return Vehicle(
    id: id,
    userId: userId,
    maker: maker,
    model: model,
    year: 2022,
    grade: 'S',
    mileage: 30000,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    licensePlate: licensePlate,
    inspectionExpiryDate: inspectionExpiryDate,
    useCategory: useCategory,
    leaseInfo: leaseInfo,
    companyId: companyId,
    assigneeName: assigneeName,
  );
}

Future<void> _seedVehicle(
    FakeFirebaseFirestore firestore, Vehicle vehicle) async {
  await firestore.collection('vehicles').doc(vehicle.id).set(vehicle.toMap());
}

void main() {
  // ===========================================================================
  // Persona A: 個人オーナー（4台所有・貨物車1台・リース1台）
  // ===========================================================================
  group('Persona A — 個人4台所有（貨物・リース含む）', () {
    late List<Vehicle> garage;

    setUp(() {
      garage = [
        // 1. ファミリーカー（乗用車・車検は2年ごと）
        _vehicle(
          id: 'family-car',
          model: 'Alphard',
          licensePlate: '品川 300 あ 11-11',
          inspectionExpiryDate: DateTime.now().add(const Duration(days: 200)),
          useCategory: VehicleUseCategory.privatePassenger,
        ),
        // 2. 貨物車（4ナンバー・毎年車検）— 車検が近い
        _vehicle(
          id: 'cargo-van',
          model: 'Hiace',
          licensePlate: '品川 400 か 22-22',
          inspectionExpiryDate: DateTime.now().add(const Duration(days: 20)),
          useCategory: VehicleUseCategory.cargo,
        ),
        // 3. リース車（リース満了が近い）
        _vehicle(
          id: 'leased-car',
          model: 'Note',
          maker: 'Nissan',
          inspectionExpiryDate: DateTime.now().add(const Duration(days: 400)),
          leaseInfo: LeaseInfo(
            lessorName: 'オリックスカーリース',
            monthlyFee: 35000,
            contractEndDate: DateTime.now().add(const Duration(days: 45)),
          ),
        ),
        // 4. 趣味のスポーツカー（車検日未登録）
        _vehicle(
          id: 'sports-car',
          maker: 'Mazda',
          model: 'Roadster',
          inspectionExpiryDate: null,
        ),
      ];
    });

    test('貨物車は毎年車検サイクル、乗用車は2年サイクルとして区別される', () {
      final cargo = garage[1];
      final family = garage[0];

      expect(cargo.effectiveUseCategory.inspectionCycleYears, 1);
      expect(family.effectiveUseCategory.inspectionCycleYears, 2);
    });

    test('貨物車の次回車検推奨日は今回満了の1年後', () {
      final cargo = garage[1];
      final next = cargo.suggestedNextInspectionDate!;
      final expected = cargo.inspectionExpiryDate!;
      expect(next.year, expected.year + 1);
    });

    test('リース車の満了日数が計算できる（45日後）', () {
      final leased = garage[2];
      expect(leased.daysUntilLeaseExpiry, inInclusiveRange(43, 45));
    });

    test('車検日未登録のスポーツカーは daysUntilInspection が null', () {
      expect(garage[3].daysUntilInspection, isNull);
    });

    test('4台のうち車検60日以内は貨物車1台のみ抽出される', () {
      final targets = FleetInquiryComposer.vehiclesNeedingInspection(garage);
      expect(targets.map((v) => v.id), ['cargo-van']);
    });

    test('問い合わせ文面に貨物車の区分が明記される（工場側が毎年車検と分かる）', () {
      final targets = FleetInquiryComposer.vehiclesNeedingInspection(garage);
      final draft = FleetInquiryComposer.compose(targets);
      expect(draft.message, contains('貨物車'));
      expect(draft.message, contains('品川 400 か 22-22'));
    });

    group('Edge Cases', () {
      test('全車両の車検日が未登録でも問い合わせ対象は空（クラッシュしない）', () {
        final noDates = garage
            .map((v) => Vehicle(
                  id: v.id,
                  userId: v.userId,
                  maker: v.maker,
                  model: v.model,
                  year: v.year,
                  grade: v.grade,
                  mileage: v.mileage,
                  createdAt: v.createdAt,
                  updatedAt: v.updatedAt,
                ))
            .toList();
        expect(
            FleetInquiryComposer.vehiclesNeedingInspection(noDates), isEmpty);
      });

      test('リース情報のみで車検日なしの車両も安全に処理される', () {
        final v = _vehicle(
          leaseInfo: LeaseInfo(lessorName: 'テストリース'),
          inspectionExpiryDate: null,
        );
        expect(v.daysUntilLeaseExpiry, isNull); // 契約満了日なし
        expect(v.suggestedNextInspectionDate, isNull);
      });
    });
  });

  // ===========================================================================
  // Persona B: 中小企業（20台フリート・総務担当が一括管理）
  // ===========================================================================
  group('Persona B — 中小企業20台フリート', () {
    late FakeFirebaseFirestore firestore;
    late FleetService fleetService;
    const companyId = 'president-uid';

    /// 20台: 内訳 = 車検切れ2台 / 7日以内1台 / 30日以内3台 / 正常14台
    List<Vehicle> buildFleet() {
      final fleet = <Vehicle>[];
      for (var i = 0; i < 20; i++) {
        final DateTime? expiry;
        if (i < 2) {
          expiry = DateTime.now().subtract(const Duration(days: 5)); // 期限切れ
        } else if (i == 2) {
          expiry = DateTime.now().add(const Duration(days: 5)); // critical
        } else if (i < 6) {
          expiry = DateTime.now().add(const Duration(days: 20)); // warning
        } else {
          expiry = DateTime.now().add(const Duration(days: 300)); // normal
        }
        fleet.add(_vehicle(
          id: 'fleet-$i',
          userId: 'driver-$i',
          companyId: companyId,
          licensePlate: '足立 100 あ ${i.toString().padLeft(2, '0')}-00',
          inspectionExpiryDate: expiry,
          useCategory:
              i < 10 ? VehicleUseCategory.cargo : null, // 半分は貨物車
          assigneeName: i.isEven ? '総務 花子' : null,
        ));
      }
      return fleet;
    }

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      fleetService = FleetService(firestore: firestore);
      for (final v in buildFleet()) {
        await _seedVehicle(firestore, v);
      }
    });

    test('フリート統計: 全20台が critical/warning/normal に正しく分類される', () async {
      final result = await fleetService.getFleetStats(companyId);
      final stats = result.getOrThrow();

      expect(stats.total, 20);
      expect(stats.critical, 3); // 期限切れ2 + 7日以内1
      expect(stats.warning, 3); // 8〜30日
      expect(stats.normal, 14);
    });

    test('総務担当視点: 車検一括問い合わせは緊急度の高い6台が近い順に並ぶ', () async {
      final snap = await firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId)
          .get();
      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();

      final targets = FleetInquiryComposer.vehiclesNeedingInspection(vehicles);

      expect(targets, hasLength(6));
      // 先頭は期限切れ（最も古い満了日）
      expect(targets.first.daysUntilInspection!, lessThan(0));
      // ソート確認: 満了日昇順
      for (var i = 0; i < targets.length - 1; i++) {
        expect(
          targets[i]
              .inspectionExpiryDate!
              .isBefore(targets[i + 1].inspectionExpiryDate!.add(
                  const Duration(seconds: 1))),
          isTrue,
        );
      }
    });

    test('一括問い合わせ文面: 6台分の情報と件名の台数が一致する', () async {
      final snap = await firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId)
          .get();
      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();
      final targets = FleetInquiryComposer.vehiclesNeedingInspection(vehicles);

      final draft = FleetInquiryComposer.compose(targets);

      expect(draft.subject, contains('6台'));
      // 貨物車は区分が明記される（毎年車検の伝達）
      expect(draft.message, contains('貨物車'));
    });

    test('CSVエクスポート: 20台全車のナンバー・担当者・車検日が出力される', () async {
      final snap = await firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId)
          .get();
      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();

      final result = FleetCsvExportService().buildCsv(vehicles);
      final csv = result.getOrThrow();

      // ヘッダー + 20行
      expect(csv.trim().split('\n'), hasLength(21));
      expect(csv, contains('足立 100 あ 00-00'));
      expect(csv, contains('足立 100 あ 19-00'));
      expect(csv, contains('総務 花子'));
    });

    test('権限違反: 他人の車両を勝手にフリートへ追加できない', () async {
      final result = await fleetService.linkVehicleToCompany(
        'fleet-0', // owner is driver-0
        companyId,
        'malicious-user', // not the owner
      );
      expect(result.isFailure, isTrue);
    });

    test('権限違反: フリートオーナー以外は担当者をアサインできない', () async {
      final result = await fleetService.assignVehicle(
        'fleet-0',
        'staff-1',
        '総務 花子',
        'not-the-president', // companyId と一致しない
      );
      expect(result.isFailure, isTrue);
    });

    group('Edge Cases', () {
      test('空のフリートコードで参加するとバリデーションエラー', () async {
        final result =
            await fleetService.joinFleetByCode('', 'fleet-0', 'driver-0');
        expect(result.isFailure, isTrue);
      });

      test('空白のみのフリートコードもエラー', () async {
        final result =
            await fleetService.joinFleetByCode('   ', 'fleet-0', 'driver-0');
        expect(result.isFailure, isTrue);
      });

      test('存在しない車両IDでフリート追加するとnotFound', () async {
        final result = await fleetService.linkVehicleToCompany(
            'does-not-exist', companyId, 'driver-0');
        expect(result.isFailure, isTrue);
      });

      test('companyId 空文字のフリート統計は0台', () async {
        final result = await fleetService.getFleetStats('');
        expect(result.getOrThrow().total, 0);
      });
    });
  });

  // ===========================================================================
  // Persona C: 近所の3整備工場 — 特徴の違いが分かる
  // ===========================================================================
  group('Persona C — 近所の3整備工場の比較', () {
    // Aユーザーの自宅: 世田谷区（35.646, 139.653）
    const homeLat = 35.646;
    const homeLng = 139.653;

    Shop makeShop({
      required String id,
      required String name,
      required List<ServiceCategory> services,
      double? rating,
      int reviewCount = 0,
      GeoPoint? location,
      ShopType type = ShopType.maintenanceShop,
    }) {
      return Shop(
        id: id,
        name: name,
        type: type,
        services: services,
        rating: rating,
        reviewCount: reviewCount,
        location: location,
        prefecture: '東京都',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    }

    late List<Shop> nearbyShops;

    setUp(() {
      nearbyShops = [
        // 工場1: 車検専門・最寄り（1km）・高評価
        makeShop(
          id: 'inspection-pro',
          name: '車検のスピード太郎 世田谷店',
          services: [ServiceCategory.inspection, ServiceCategory.maintenance],
          rating: 4.8,
          reviewCount: 120,
          location: const GeoPoint(35.655, 139.653),
        ),
        // 工場2: カスタム・板金が得意（3km）・中評価
        makeShop(
          id: 'custom-garage',
          name: 'ガレージ ワークス',
          services: [
            ServiceCategory.customization,
            ServiceCategory.bodyWork,
            ServiceCategory.partsInstall,
          ],
          rating: 4.2,
          reviewCount: 45,
          location: const GeoPoint(35.672, 139.660),
          type: ShopType.customShop,
        ),
        // 工場3: ディーラー系・タイヤ/コーティング（5km）・レビュー少
        makeShop(
          id: 'dealer-service',
          name: 'トヨタモビリティ サービス',
          services: [
            ServiceCategory.inspection,
            ServiceCategory.tire,
            ServiceCategory.coating,
          ],
          rating: 4.0,
          reviewCount: 8,
          location: const GeoPoint(35.690, 139.670),
          type: ShopType.dealer,
        ),
      ];
    });

    test('3工場それぞれの特徴（得意サービス）が異なることが識別できる', () {
      final inspectionShops = nearbyShops
          .where((s) => s.services.contains(ServiceCategory.inspection))
          .toList();
      final customShops = nearbyShops
          .where((s) => s.services.contains(ServiceCategory.customization))
          .toList();

      // 車検なら2択、カスタムなら1択 — 用途で絞り込める
      expect(inspectionShops.map((s) => s.id),
          containsAll(['inspection-pro', 'dealer-service']));
      expect(customShops.map((s) => s.id), ['custom-garage']);
    });

    test('評価とレビュー件数で信頼度を比較できる', () {
      final byRating = List<Shop>.of(nearbyShops)
        ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      expect(byRating.first.id, 'inspection-pro');
      // レビュー8件のディーラーは評価は4.0だが件数が少ないことが分かる
      final dealer = nearbyShops.firstWhere((s) => s.id == 'dealer-service');
      expect(dealer.reviewCount, lessThan(10));
    });

    test('自宅からの距離順は 車検専門 → カスタム → ディーラー', () {
      double haversine(GeoPoint p) {
        // ShopProvider 内部と同じ計算式の簡易検証（直線距離の大小関係のみ確認）
        final dLat = (p.latitude - homeLat).abs();
        final dLng = (p.longitude - homeLng).abs();
        return dLat * dLat + dLng * dLng;
      }

      final sorted = List<Shop>.of(nearbyShops)
        ..sort((a, b) =>
            haversine(a.location!).compareTo(haversine(b.location!)));
      expect(sorted.map((s) => s.id),
          ['inspection-pro', 'custom-garage', 'dealer-service']);
    });

    group('Edge Cases', () {
      test('位置情報がない工場が混ざっていてもソート対象から安全に除外できる', () {
        final shopsWithMissing = [
          ...nearbyShops,
          makeShop(
            id: 'no-location',
            name: '位置未登録工場',
            services: [ServiceCategory.maintenance],
            location: null,
          ),
        ];
        final withLocation =
            shopsWithMissing.where((s) => s.location != null).toList();
        expect(withLocation, hasLength(3));
      });

      test('評価なし（rating=null）の新規工場も比較リストに表示できる', () {
        final newShop = makeShop(
          id: 'new-shop',
          name: '新規オープン工場',
          services: [ServiceCategory.maintenance],
          rating: null,
        );
        expect(newShop.rating, isNull);
        expect(newShop.reviewCount, 0);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Persona D: 整備履歴トレンド分析 + コミュニティQ&A
  //   「4年間マイカーを乗り続けているプリウスオーナー。
  //    過去の整備履歴から次のオイル交換のタイミングを確認したい。
  //    また、同じ車種のオーナーがどんな整備をしているか知りたい。
  //    整備工場の許可を得て車検費用についてQ&Aで聞きたい。」
  // ---------------------------------------------------------------------------
  group('Persona D: プリウスオーナーのトレンド分析とQ&A', () {
    late MaintenanceTrendService trendService;
    late CommunityTrendService communityService;
    late FaqService faqService;
    late FakeFirebaseFirestore fakeFirestore;

    // Prius owner maintenance records over 4 years
    late List<MaintenanceRecord> priusHistory;

    setUp(() async {
      trendService = const MaintenanceTrendService();
      fakeFirestore = FakeFirebaseFirestore();
      communityService = CommunityTrendService(firestore: fakeFirestore);
      faqService = FaqService(firestore: fakeFirestore);

      final base = DateTime(2020, 6, 1);
      priusHistory = [
        // Oil changes every ~5000km / 6 months
        _maintenanceRecord(type: MaintenanceType.oilChange, date: base, mileage: 10000, cost: 4200),
        _maintenanceRecord(type: MaintenanceType.oilChange, date: base.add(const Duration(days: 180)), mileage: 15000, cost: 4400),
        _maintenanceRecord(type: MaintenanceType.oilChange, date: base.add(const Duration(days: 360)), mileage: 20000, cost: 4100),
        _maintenanceRecord(type: MaintenanceType.oilChange, date: base.add(const Duration(days: 540)), mileage: 25000, cost: 4300),
        // Tire change every ~2 years
        _maintenanceRecord(type: MaintenanceType.tireChange, date: base.add(const Duration(days: 365)), mileage: 18000, cost: 32000),
        _maintenanceRecord(type: MaintenanceType.tireChange, date: base.add(const Duration(days: 730)), mileage: 28000, cost: 34000),
        // Battery change once
        _maintenanceRecord(type: MaintenanceType.batteryChange, date: base.add(const Duration(days: 1200)), mileage: 40000, cost: 15000),
      ];

      // Seed community trend data for Prius
      await fakeFirestore
          .collection('community_maintenance_trends')
          .doc('Toyota_Prius')
          .set({
        'maker': 'Toyota',
        'model': 'Prius',
        'sampleVehicleCount': 156,
        'lastUpdated': Timestamp.now(),
        'insights': [
          {
            'type': 'oilChange',
            'medianIntervalKm': 5000.0,
            'medianIntervalDays': 183.0,
            'medianCost': 4200.0,
            'sampleCount': 152,
            'popularityPercent': 97.4,
          },
          {
            'type': 'tireChange',
            'medianIntervalKm': 25000.0,
            'medianIntervalDays': 730.0,
            'medianCost': 33000.0,
            'sampleCount': 138,
            'popularityPercent': 88.5,
          },
        ],
      });
    });

    test('オイル交換の平均間隔（km・日数）が計算される', () {
      final trends = trendService.analyzeHistory(
        priusHistory.where((r) => r.type == MaintenanceType.oilChange).toList(),
        currentMileage: 28000,
      );
      final oilTrend = trends.first;

      expect(oilTrend.averageIntervalKm, closeTo(5000, 50));
      expect(oilTrend.averageIntervalDays, closeTo(180, 5));
      expect(oilTrend.confidence, equals(TrendConfidence.high));
    });

    test('次回オイル交換の予測走行距離が計算される', () {
      final trends = trendService.analyzeHistory(
        priusHistory.where((r) => r.type == MaintenanceType.oilChange).toList(),
        currentMileage: 28000,
      );
      final oilTrend = trends.first;

      // Last oil at 25000, avg interval ~5000 → next at ~30000
      expect(oilTrend.predictedNextMileage, closeTo(30000, 200));
    });

    test('タイヤ交換は2年毎のパターンが信頼度mediumで認識される', () {
      final trends = trendService.analyzeHistory(
        priusHistory.where((r) => r.type == MaintenanceType.tireChange).toList(),
      );
      final tireTrend = trends.first;

      expect(tireTrend.averageIntervalDays, closeTo(365, 5));
      expect(tireTrend.confidence, equals(TrendConfidence.medium));
    });

    test('バッテリー交換は1件のみで confidence=low', () {
      final trends = trendService.analyzeHistory(
        priusHistory.where((r) => r.type == MaintenanceType.batteryChange).toList(),
      );
      expect(trends.first.confidence, equals(TrendConfidence.low));
      expect(trends.first.averageIntervalKm, isNull);
    });

    test('sortByUrgency: オイル交換が最も緊急として上位に来る', () {
      final now = DateTime(2021, 7, 1); // last oil at day 540 → ~22 days overdue
      final trends = trendService.analyzeHistory(priusHistory, currentMileage: 28000, currentDate: now);
      final sorted = trendService.sortByUrgency(trends, currentDate: now);

      expect(sorted.first.type, equals(MaintenanceType.oilChange));
    });

    test('同車種コミュニティのプリウストレンドを取得できる', () async {
      final result = await communityService.getTrendsForVehicle(
        maker: 'Toyota',
        model: 'Prius',
      );

      expect(result.isSuccess, isTrue);
      final data = result.valueOrNull!;
      expect(data.sampleVehicleCount, equals(156));
      expect(data.insights.any((i) => i.typeKey == 'oilChange'), isTrue);
    });

    test('コミュニティトレンドのdescriptionにPriusが含まれる', () async {
      final result = await communityService.getTrendsForVehicle(
        maker: 'Toyota',
        model: 'Prius',
      );
      final oilInsight = result.valueOrNull!.insights
          .firstWhere((i) => i.typeKey == 'oilChange');
      expect(oilInsight.description, contains('Prius'));
    });

    test('ユーザーが車検費用についてFAQを作成できる（店舗回答許可あり）', () async {
      final result = await faqService.createFaq(
        question: 'プリウスの車検費用の相場を教えてください',
        category: FaqCategory.inspection,
        authorId: 'persona-d-user',
        allowShopResponse: true,
        vehicleMaker: 'Toyota',
        vehicleModel: 'Prius',
        tags: ['車検', '費用', 'プリウス'],
      );

      expect(result.isSuccess, isTrue);
    });

    test('他のプリウスオーナーがFAQに回答できる', () async {
      final faqId = (await faqService.createFaq(
        question: 'プリウスの車検費用は？',
        category: FaqCategory.inspection,
        authorId: 'persona-d-user',
        allowShopResponse: true,
      )).valueOrNull!;

      final answer = await faqService.addAnswer(
        faqId: faqId,
        content: '私のプリウス（5年前の型）は先日7万5千円でした。',
        authorId: 'other-prius-owner',
        isShopResponse: false,
      );

      expect(answer.isSuccess, isTrue);

      final faq = (await faqService.getFaq(faqId)).valueOrNull!;
      expect(faq.answerCount, equals(1));
    });

    test('整備工場が許可制で回答できる（非セールス）', () async {
      final faqId = (await faqService.createFaq(
        question: '車検費用の内訳を教えてください',
        category: FaqCategory.inspection,
        authorId: 'persona-d-user',
        allowShopResponse: true,
      )).valueOrNull!;

      final shopAnswer = await faqService.addAnswer(
        faqId: faqId,
        content: '法定費用（自賠責・重量税・印紙代）と整備代に分かれます。法定費用は車種共通で約3.6万円です。',
        authorId: 'shop-staff-1',
        isShopResponse: true,
        shopId: 'inspection-pro-shop',
      );

      expect(shopAnswer.isSuccess, isTrue);

      final answers = (await faqService.getAnswers(faqId)).valueOrNull!;
      final shopAns = answers.firstWhere((a) => a.isShopResponse);
      expect(shopAns.shopId, equals('inspection-pro-shop'));
    });

    test('allowShopResponse=false のFAQに店舗は回答できない', () async {
      final faqId = (await faqService.createFaq(
        question: '個人的な質問です',
        category: FaqCategory.general,
        authorId: 'persona-d-user',
        allowShopResponse: false,
      )).valueOrNull!;

      final result = await faqService.addAnswer(
        faqId: faqId,
        content: '当店ではお得なコースをご用意しています',
        authorId: 'salesy-shop',
        isShopResponse: true,
        shopId: 'salesy-shop',
      );

      expect(result.isFailure, isTrue);
    });

    test('ベスト回答を質問者が設定できる', () async {
      final faqId = (await faqService.createFaq(
        question: 'ベスト回答テスト',
        category: FaqCategory.maintenance,
        authorId: 'persona-d-user',
        allowShopResponse: false,
      )).valueOrNull!;

      final answerId = (await faqService.addAnswer(
        faqId: faqId,
        content: '最も的確な回答です',
        authorId: 'expert-user',
        isShopResponse: false,
      )).valueOrNull!;

      final best = await faqService.markBestAnswer(
        faqId: faqId,
        answerId: answerId,
        requesterId: 'persona-d-user',
      );
      expect(best.isSuccess, isTrue);

      final answers = (await faqService.getAnswers(faqId)).valueOrNull!;
      expect(answers.first.isBestAnswer, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Local helper for persona D maintenance records
// ---------------------------------------------------------------------------
MaintenanceRecord _maintenanceRecord({
  required MaintenanceType type,
  required DateTime date,
  int? mileage,
  int cost = 5000,
}) =>
    MaintenanceRecord(
      id: '${type.name}_${date.millisecondsSinceEpoch}',
      vehicleId: 'prius-v1',
      userId: 'persona-d-user',
      type: type,
      title: type.displayName,
      cost: cost,
      date: date,
      mileageAtService: mileage,
      imageUrls: const [],
      createdAt: date,
    );
