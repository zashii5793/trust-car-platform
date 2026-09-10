// PartRecommendationService / Part Model Unit Tests
//
// Since PartRecommendationService requires FirebaseFirestore, we test:
//   1. Model-level pure business logic (PartListing, VehicleSpec)
//   2. generateProsAndCons() — public method with no Firebase dependency
//   3. Enum behavior (PartCategory, CompatibilityLevel)
//   4. AppError patterns for service error scenarios

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

/// Fake Firestore that can be passed to service constructors.
/// Prevents FirebaseFirestore.instance access in unit tests.
/// generateProsAndCons() never calls _firestore so no methods need implementing.
class _FakeFirestore extends Fake implements FirebaseFirestore {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PartListing _makePart({
  String id = 'part1',
  PartCategory category = PartCategory.aero,
  int? priceFrom,
  int? priceTo,
  double? rating,
  String? brand,
  List<PartProCon> prosAndCons = const [],
  List<VehicleSpec> compatibleVehicles = const [],
  CompatibilityLevel defaultCompatibility = CompatibilityLevel.compatible,
}) {
  final now = DateTime.now();
  return PartListing(
    id: id,
    shopId: 'shop1',
    name: 'テストパーツ $id',
    description: '説明',
    category: category,
    priceFrom: priceFrom,
    priceTo: priceTo,
    rating: rating,
    brand: brand,
    prosAndCons: prosAndCons,
    compatibleVehicles: compatibleVehicles,
    defaultCompatibility: defaultCompatibility,
    createdAt: now,
    updatedAt: now,
  );
}

Vehicle _makeVehicle({
  String makerId = 'toyota',
  String modelId = 'prius',
  int year = 2020,
}) {
  final now = DateTime.now();
  return Vehicle(
    id: 'v1',
    userId: 'user1',
    maker: makerId,
    model: modelId,
    year: year,
    grade: 'Standard',
    mileage: 10000,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PartCategory enum', () {
    test('全カテゴリの displayName が空でない', () {
      for (final cat in PartCategory.values) {
        expect(cat.displayName, isNotEmpty);
        expect(cat.displayNameEn, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(PartCategory.fromString('aero'), PartCategory.aero);
      expect(PartCategory.fromString('wheel'), PartCategory.wheel);
      expect(PartCategory.fromString('audio'), PartCategory.audio);
      expect(PartCategory.fromString('other'), PartCategory.other);
    });

    test('fromString が null を返す（不明な値）', () {
      expect(PartCategory.fromString(null), isNull);
      expect(PartCategory.fromString(''), isNull);
      expect(PartCategory.fromString('unknown'), isNull);
    });
  });

  group('CompatibilityLevel enum', () {
    test('全レベルの displayName と description が空でない', () {
      for (final level in CompatibilityLevel.values) {
        expect(level.displayName, isNotEmpty);
        expect(level.description, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(
          CompatibilityLevel.fromString('perfect'), CompatibilityLevel.perfect);
      expect(CompatibilityLevel.fromString('compatible'),
          CompatibilityLevel.compatible);
      expect(CompatibilityLevel.fromString('conditional'),
          CompatibilityLevel.conditional);
      expect(CompatibilityLevel.fromString('incompatible'),
          CompatibilityLevel.incompatible);
    });

    test('fromString が null を返す（不明な値）', () {
      expect(CompatibilityLevel.fromString(null), isNull);
      expect(CompatibilityLevel.fromString('invalid'), isNull);
    });
  });

  // ── PartListing.priceDisplay ───────────────────────────────────────────────

  group('PartListing.priceDisplay', () {
    test('priceFrom が null のとき「要問合せ」', () {
      final part = _makePart(priceFrom: null);
      expect(part.priceDisplay, '要問合せ');
    });

    test('priceTo が null のとき単一価格表示', () {
      final part = _makePart(priceFrom: 50000);
      expect(part.priceDisplay, '¥50,000');
    });

    test('priceFrom と priceTo が同じとき単一価格表示', () {
      final part = _makePart(priceFrom: 30000, priceTo: 30000);
      expect(part.priceDisplay, '¥30,000');
    });

    test('価格範囲がある場合「¥X〜¥Y」形式', () {
      final part = _makePart(priceFrom: 20000, priceTo: 50000);
      expect(part.priceDisplay, '¥20,000〜¥50,000');
    });

    test('100万円超の価格も正しくフォーマット', () {
      final part = _makePart(priceFrom: 1200000);
      expect(part.priceDisplay, '¥1,200,000');
    });

    test('999円のような小額は区切りなし', () {
      final part = _makePart(priceFrom: 999);
      expect(part.priceDisplay, '¥999');
    });
  });

  // ── PartListing pros / cons ───────────────────────────────────────────────

  group('PartListing pros / cons getters', () {
    final proAndCons = [
      const PartProCon(text: 'メリット1', isPro: true),
      const PartProCon(text: 'メリット2', isPro: true),
      const PartProCon(text: 'デメリット1', isPro: false),
    ];

    test('pros は isPro=true のみ返す', () {
      final part = _makePart(prosAndCons: proAndCons);
      expect(part.pros.length, 2);
      expect(part.pros.every((p) => p.isPro), true);
    });

    test('cons は isPro=false のみ返す', () {
      final part = _makePart(prosAndCons: proAndCons);
      expect(part.cons.length, 1);
      expect(part.cons.every((p) => !p.isPro), true);
    });

    test('prosAndCons が空のとき pros/cons ともに空', () {
      final part = _makePart();
      expect(part.pros, isEmpty);
      expect(part.cons, isEmpty);
    });
  });

  // ── VehicleSpec.matchesVehicle ────────────────────────────────────────────

  group('VehicleSpec.matchesVehicle', () {
    test('全フィールド null のとき任意の車両にマッチする', () {
      const spec = VehicleSpec();
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('makerId が一致すればマッチする', () {
      const spec = VehicleSpec(makerId: 'toyota');
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('makerId が不一致のときマッチしない', () {
      const spec = VehicleSpec(makerId: 'honda');
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        false,
      );
    });

    test('modelId が一致すればマッチする', () {
      const spec = VehicleSpec(makerId: 'toyota', modelId: 'prius');
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('modelId が不一致のときマッチしない', () {
      const spec = VehicleSpec(makerId: 'toyota', modelId: 'aqua');
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        false,
      );
    });

    test('yearFrom 以上ならマッチする', () {
      const spec = VehicleSpec(yearFrom: 2018);
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('yearFrom より前はマッチしない', () {
      const spec = VehicleSpec(yearFrom: 2021);
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        false,
      );
    });

    test('yearTo 以下ならマッチする', () {
      const spec = VehicleSpec(yearTo: 2022);
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('yearTo より後はマッチしない', () {
      const spec = VehicleSpec(yearTo: 2019);
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        false,
      );
    });

    test('yearFrom〜yearTo の範囲内ならマッチする', () {
      const spec = VehicleSpec(yearFrom: 2018, yearTo: 2022);
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('gradePattern が grade を含む場合にマッチする（大文字小文字無視）', () {
      const spec = VehicleSpec(gradePattern: 'sport');
      expect(
        spec.matchesVehicle(
            makerId: 'toyota', modelId: 'prius', year: 2020, grade: 'GR Sport'),
        true,
      );
    });

    test('gradePattern が grade を含まない場合にマッチしない', () {
      const spec = VehicleSpec(gradePattern: 'premium');
      expect(
        spec.matchesVehicle(
            makerId: 'toyota', modelId: 'prius', year: 2020, grade: 'Standard'),
        false,
      );
    });

    test('gradePattern があっても grade が null のとき条件はスキップ', () {
      const spec = VehicleSpec(gradePattern: 'sport');
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'prius', year: 2020),
        true,
      );
    });

    test('bodyType が一致するとマッチする', () {
      const spec = VehicleSpec(bodyType: 'sedan');
      expect(
        spec.matchesVehicle(
            makerId: 'toyota', modelId: 'camry', year: 2020, bodyType: 'sedan'),
        true,
      );
    });

    test('bodyType が不一致のときマッチしない', () {
      const spec = VehicleSpec(bodyType: 'suv');
      expect(
        spec.matchesVehicle(
            makerId: 'toyota', modelId: 'camry', year: 2020, bodyType: 'sedan'),
        false,
      );
    });

    test('bodyType があっても vehicle の bodyType が null のとき条件はスキップ', () {
      const spec = VehicleSpec(bodyType: 'sedan');
      expect(
        spec.matchesVehicle(makerId: 'toyota', modelId: 'camry', year: 2020),
        true,
      );
    });
  });

  // ── PartListing.getCompatibilityFor ──────────────────────────────────────

  group('PartListing.getCompatibilityFor', () {
    test('対応車種リストが空のとき defaultCompatibility を返す', () {
      final part = _makePart(
        defaultCompatibility: CompatibilityLevel.incompatible,
      );
      expect(
        part.getCompatibilityFor(
            makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.incompatible,
      );
    });

    test('車両スペックが完全一致のとき perfect を返す', () {
      const spec = VehicleSpec(makerId: 'toyota', modelId: 'prius');
      final part = _makePart(compatibleVehicles: [spec]);
      expect(
        part.getCompatibilityFor(
            makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.perfect,
      );
    });

    test('makerIdのみ一致のとき conditional を返す', () {
      const spec = VehicleSpec(makerId: 'toyota', modelId: 'aqua');
      final part = _makePart(compatibleVehicles: [spec]);
      expect(
        part.getCompatibilityFor(
            makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.conditional,
      );
    });
  });

  // ── generateProsAndCons ───────────────────────────────────────────────────

  group('PartRecommendationService.generateProsAndCons', () {
    late PartRecommendationService service;
    late Vehicle vehicle;

    setUp(() {
      // _FakeFirestore を渡してFirebase初期化なしでサービスを生成
      // generateProsAndCons は Firestore を一切使わないため問題なし
      service = PartRecommendationService(firestore: _FakeFirestore());
      vehicle = _makeVehicle();
    });

    test('aero カテゴリ: pros 2件 cons 1件が含まれる', () {
      final part = _makePart(category: PartCategory.aero);
      final result = service.generateProsAndCons(part, vehicle);

      final pros = result.where((p) => p.isPro).toList();
      final cons = result.where((p) => !p.isPro).toList();
      expect(pros.length, greaterThanOrEqualTo(2));
      expect(cons.length, greaterThanOrEqualTo(1));
    });

    test('wheel カテゴリ: pros 2件 cons 1件が含まれる', () {
      final part = _makePart(category: PartCategory.wheel);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.where((p) => p.isPro).length, greaterThanOrEqualTo(2));
      expect(result.where((p) => !p.isPro).length, greaterThanOrEqualTo(1));
    });

    test('suspension カテゴリ: pros 2件 cons 1件が含まれる', () {
      final part = _makePart(category: PartCategory.suspension);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.where((p) => p.isPro).length, greaterThanOrEqualTo(2));
      expect(result.where((p) => !p.isPro).length, greaterThanOrEqualTo(1));
    });

    test('exhaust カテゴリ: 車検対応のデメリットが含まれる', () {
      final part = _makePart(category: PartCategory.exhaust);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => !p.isPro && p.text.contains('車検')), true);
    });

    test('audio カテゴリ: 取付工賃のデメリットが含まれる', () {
      final part = _makePart(category: PartCategory.audio);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => !p.isPro && p.text.contains('工賃')), true);
    });

    test('other カテゴリ: デフォルトの pro が含まれる', () {
      final part = _makePart(category: PartCategory.other);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.isPro), true);
    });

    test('priceFrom < 30000 のとき「リーズナブル」の pro が追加される', () {
      final part = _makePart(category: PartCategory.tire, priceFrom: 29999);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.isPro && p.text.contains('リーズナブル')), true);
    });

    test('priceFrom == 30000 のとき「リーズナブル」の pro は追加されない', () {
      final part = _makePart(category: PartCategory.tire, priceFrom: 30000);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.text.contains('リーズナブル')), false);
    });

    test('priceFrom > 100000 のとき「高価格帯」の con が追加される', () {
      final part = _makePart(category: PartCategory.wheel, priceFrom: 100001);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => !p.isPro && p.text.contains('高価格帯')), true);
    });

    test('priceFrom == 100000 のとき「高価格帯」の con は追加されない', () {
      final part = _makePart(category: PartCategory.wheel, priceFrom: 100000);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.text.contains('高価格帯')), false);
    });

    test('rating >= 4.5 のとき高評価の pro が追加される', () {
      final part = _makePart(category: PartCategory.aero, rating: 4.5);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.isPro && p.text.contains('評価')), true);
    });

    test('rating < 4.5 のとき高評価の pro は追加されない', () {
      final part = _makePart(category: PartCategory.aero, rating: 4.4);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.text.contains('評価が非常に高い')), false);
    });

    test('rating が null のとき高評価 pro は追加されない', () {
      final part = _makePart(category: PartCategory.aero, rating: null);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.text.contains('評価が非常に高い')), false);
    });

    test('brand が設定されているとき brand 信頼性 pro が追加される', () {
      final part = _makePart(category: PartCategory.aero, brand: 'TRD');
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.isPro && p.text.contains('TRD')), true);
    });

    test('brand が null のとき brand pro は追加されない', () {
      final part = _makePart(category: PartCategory.aero, brand: null);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result.any((p) => p.text.contains('ブランドの信頼性')), false);
    });

    test('空リストを返さない（少なくとも1件の pro がある）', () {
      final part = _makePart(category: PartCategory.intake);
      final result = service.generateProsAndCons(part, vehicle);

      expect(result, isNotEmpty);
    });

    test('複数条件が重なる場合も結果はリスト型で返る', () {
      final part = _makePart(
        category: PartCategory.aero,
        priceFrom: 20000, // < 30000 → リーズナブル pro
        rating: 4.8, // >= 4.5 → 高評価 pro
        brand: 'STI',
      );
      final result = service.generateProsAndCons(part, vehicle);

      expect(result, isA<List<PartProCon>>());
      expect(result.length, greaterThan(3));
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（サービスエラーシナリオ）', () {
    test('network error が isRetryable = true', () {
      const error = AppError.network('connection failed');
      expect(error.isRetryable, true);
    });

    test('server error が isRetryable = true', () {
      const error = AppError.server('server error');
      expect(error.isRetryable, true);
    });

    test('notFound error が isRetryable = false', () {
      const error = AppError.notFound('パーツが見つかりません');
      expect(error.isRetryable, false);
    });

    test('permission error が isRetryable = false', () {
      const error = AppError.permission('アクセス拒否');
      expect(error.isRetryable, false);
    });

    test('Result.failure に AppError を格納できる', () {
      const result = Result<List<PartListing>, AppError>.failure(
        AppError.network('failed'),
      );
      expect(result.isFailure, true);
    });

    test('Result.success に PartListing リストを格納できる', () {
      const result = Result<List<PartListing>, AppError>.success([]);
      expect(result.isSuccess, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('VehicleSpec: yearFrom == yearTo のとき境界年にマッチする', () {
      const spec = VehicleSpec(yearFrom: 2020, yearTo: 2020);
      expect(
        spec.matchesVehicle(makerId: 'any', modelId: 'any', year: 2020),
        true,
      );
    });

    test('VehicleSpec: yearFrom > yearTo のような矛盾状態でも例外にならない', () {
      const spec = VehicleSpec(yearFrom: 2025, yearTo: 2020);
      expect(
        () => spec.matchesVehicle(makerId: 'any', modelId: 'any', year: 2022),
        returnsNormally,
      );
    });

    test('PartListing: priceFrom=0 のとき「¥0」と表示される', () {
      final part = _makePart(priceFrom: 0);
      expect(part.priceDisplay, '¥0');
    });

    test('PartCategory.fromString: 全 enum 値を往復変換できる', () {
      for (final cat in PartCategory.values) {
        expect(PartCategory.fromString(cat.name), cat);
      }
    });

    test('CompatibilityLevel.fromString: 全 enum 値を往復変換できる', () {
      for (final level in CompatibilityLevel.values) {
        expect(CompatibilityLevel.fromString(level.name), level);
      }
    });
  });

  // ── buildReasons / buildCautions ─────────────────────────────────────────
  //
  // 企画（docs/FEATURE_SPEC.md）は「理由を複数、注意点をセットで、ベスト1を
  // 押し付けない」。ここでは提案 1 件に付く理由と注意点の中身を固定する。

  group('PartRecommendationService.buildReasons', () {
    late PartRecommendationService service;
    late Vehicle vehicle;

    PartListing makePart({
      PartCategory category = PartCategory.wheel,
      double? rating,
      int reviewCount = 0,
      bool isFeatured = false,
      int? priceFrom,
      String? brand,
    }) {
      final now = DateTime.now();
      return PartListing(
        id: 'p1',
        shopId: 'shop1',
        name: 'ホイール',
        description: '説明',
        category: category,
        rating: rating,
        reviewCount: reviewCount,
        isFeatured: isFeatured,
        priceFrom: priceFrom,
        brand: brand,
        createdAt: now,
        updatedAt: now,
      );
    }

    setUp(() {
      service = PartRecommendationService(firestore: _FakeFirestore());
      vehicle = _makeVehicle();
    });

    test('完全対応なら、車種名入りの対応理由が先頭に来る', () {
      final reasons =
          service.buildReasons(makePart(), vehicle, CompatibilityLevel.perfect);
      expect(reasons, isNotEmpty);
      expect(reasons.first, contains('完全対応'));
      expect(reasons.first, contains(vehicle.displayName));
    });

    test('対応なら「に対応」、条件付きなら対応の理由は付かない', () {
      final compatible = service.buildReasons(
          makePart(), vehicle, CompatibilityLevel.compatible);
      expect(compatible.first, endsWith('に対応'));

      final conditional = service.buildReasons(
          makePart(), vehicle, CompatibilityLevel.conditional);
      expect(conditional.where((r) => r.contains('対応')), isEmpty);
    });

    test('理由は必ず複数になる（対応 + カテゴリの利点）', () {
      final reasons = service.buildReasons(
          makePart(category: PartCategory.wheel),
          vehicle,
          CompatibilityLevel.compatible);
      expect(reasons.length, greaterThanOrEqualTo(2));
      expect(reasons, contains('足元の印象を大きく変えられる'));
    });

    test('レビューが多く評価が高ければ、件数と点数を理由に出す', () {
      final reasons = service.buildReasons(
          makePart(rating: 4.6, reviewCount: 42),
          vehicle,
          CompatibilityLevel.compatible);
      expect(
          reasons.any((r) => r.contains('42件') && r.contains('4.6')), isTrue);
    });

    test('レビューが少なければ点数は理由にしない', () {
      final reasons = service.buildReasons(
          makePart(rating: 4.6, reviewCount: 2),
          vehicle,
          CompatibilityLevel.compatible);
      expect(reasons.any((r) => r.contains('2件')), isFalse);
    });

    test('広告枠（isFeatured）は理由にならない', () {
      final reasons = service.buildReasons(
          makePart(isFeatured: true), vehicle, CompatibilityLevel.compatible);
      expect(reasons.any((r) => r.contains('広告') || r.contains('掲載')), isFalse);
    });

    test('同じ文言は重複しない', () {
      final reasons = service.buildReasons(
          makePart(brand: 'RAYS'), vehicle, CompatibilityLevel.compatible);
      expect(reasons.toSet().length, reasons.length);
    });
  });

  group('PartRecommendationService.buildCautions', () {
    late PartRecommendationService service;
    late Vehicle vehicle;

    PartListing makePart({
      PartCategory category = PartCategory.wheel,
      double? rating,
      int reviewCount = 0,
      bool isFeatured = false,
      int? priceFrom,
    }) {
      final now = DateTime.now();
      return PartListing(
        id: 'p1',
        shopId: 'shop1',
        name: 'ホイール',
        description: '説明',
        category: category,
        rating: rating,
        reviewCount: reviewCount,
        isFeatured: isFeatured,
        priceFrom: priceFrom,
        createdAt: now,
        updatedAt: now,
      );
    }

    setUp(() {
      service = PartRecommendationService(firestore: _FakeFirestore());
      vehicle = _makeVehicle();
    });

    test('条件付き対応なら、確認を促す注意が先頭に来る', () {
      final cautions = service.buildCautions(
          makePart(), vehicle, CompatibilityLevel.conditional);
      expect(cautions.first, contains('加工が必要'));
    });

    test('広告枠は注意点として明示する（順位に使っていないことも書く）', () {
      final cautions = service.buildCautions(
          makePart(isFeatured: true), vehicle, CompatibilityLevel.perfect);
      expect(cautions.any((c) => c.contains('広告')), isTrue);
      expect(cautions.any((c) => c.contains('順位')), isTrue);
    });

    test('評価があってもレビューが 3 件未満なら参考程度と書く', () {
      final cautions = service.buildCautions(
          makePart(rating: 5.0, reviewCount: 1),
          vehicle,
          CompatibilityLevel.perfect);
      expect(cautions.any((c) => c.contains('レビューが少なく')), isTrue);
    });

    test('カテゴリのデメリットと高価格帯の注意も入る', () {
      final cautions = service.buildCautions(
          makePart(category: PartCategory.exhaust, priceFrom: 150000),
          vehicle,
          CompatibilityLevel.compatible);
      expect(cautions, contains('車検対応の確認が必要'));
      expect(cautions, contains('高価格帯の製品'));
    });

    test('完全対応・非広告・レビューなしの一般カテゴリでは注意が空になりうる', () {
      final cautions = service.buildCautions(
          makePart(category: PartCategory.other),
          vehicle,
          CompatibilityLevel.perfect);
      expect(cautions, isEmpty);
    });

    group('Edge Cases', () {
      test('非対応なら車種名入りの非対応が注意に入る', () {
        final cautions = service.buildCautions(
            makePart(), vehicle, CompatibilityLevel.incompatible);
        expect(cautions.first, contains('非対応'));
        expect(cautions.first, contains(vehicle.displayName));
      });

      test('同じ文言は重複しない', () {
        final cautions = service.buildCautions(
            makePart(category: PartCategory.exhaust, isFeatured: true),
            vehicle,
            CompatibilityLevel.conditional);
        expect(cautions.toSet().length, cautions.length);
      });
    });
  });
}
