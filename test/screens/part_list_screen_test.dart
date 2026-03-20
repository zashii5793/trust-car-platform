// PartListScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/marketplace/part_list_screen.dart';
import 'package:trust_car_platform/providers/part_recommendation_provider.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock PartRecommendationService
// ---------------------------------------------------------------------------

class MockPartRecommendationService implements PartRecommendationService {
  Result<List<PartListing>, AppError> featuredResult =
      const Result.success([]);
  Result<List<PartListing>, AppError> categoryResult =
      const Result.success([]);
  Result<List<PartListing>, AppError> searchResult =
      const Result.success([]);

  PartCategory? lastCategory;
  String? lastKeyword;
  int getFeaturedCallCount = 0;

  @override
  Future<Result<List<PartListing>, AppError>> getFeaturedParts(
      {int limit = 5}) async {
    getFeaturedCallCount++;
    return featuredResult;
  }

  @override
  Future<Result<List<PartListing>, AppError>> getPartsByCategory(
      PartCategory category, {int limit = 20, dynamic startAfter}) async {
    lastCategory = category;
    return categoryResult;
  }

  @override
  Future<Result<List<PartListing>, AppError>> searchParts(
      String keyword, {PartCategory? category, int limit = 20}) async {
    lastKeyword = keyword;
    lastCategory = category;
    return searchResult;
  }

  @override
  Future<Result<PartListing, AppError>> getPartDetail(String partId) async =>
      Result.failure(AppError.notFound('not found'));

  @override
  Future<Result<List<PartRecommendation>, AppError>>
      getRecommendationsForVehicle(dynamic vehicle,
          {PartCategory? category, int limit = 10}) async =>
      const Result.success([]);

  @override
  List<PartProCon> generateProsAndCons(dynamic part, dynamic vehicle) => [];
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

PartListing _makePart({
  String id = 'part1',
  String name = 'テストパーツ',
  PartCategory category = PartCategory.maintenance,
  bool isFeatured = false,
  bool isActive = true,
  int? priceFrom = 5000,
  int? priceTo = 8000,
  double? rating,
  String? brand,
}) {
  final now = DateTime.now();
  return PartListing(
    id: id,
    shopId: 'shop1',
    name: name,
    description: '$name の説明',
    category: category,
    isActive: isActive,
    isFeatured: isFeatured,
    isPriceNegotiable: false,
    priceFrom: priceFrom,
    priceTo: priceTo,
    compatibleVehicles: [],
    prosAndCons: [],
    tags: [],
    reviewCount: 0,
    imageUrls: [],
    brand: brand,
    rating: rating,
    createdAt: now,
    updatedAt: now,
  );
}

Vehicle _makeVehicle({
  String maker = 'Toyota',
  String model = 'RAV4',
  int year = 2022,
}) {
  final now = DateTime.now();
  return Vehicle(
    id: 'v1',
    userId: 'u1',
    maker: maker,
    model: model,
    year: year,
    grade: 'G',
    mileage: 20000,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(
  PartRecommendationProvider provider, {
  Vehicle? vehicle,
}) {
  return ChangeNotifierProvider<PartRecommendationProvider>.value(
    value: provider,
    child: MaterialApp(
      home: PartListScreen(vehicle: vehicle),
    ),
  );
}

PartRecommendationProvider _makeProvider(
    MockPartRecommendationService service) {
  return PartRecommendationProvider(
    partRecommendationService: service,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PartListScreen', () {
    late MockPartRecommendationService mockService;
    late PartRecommendationProvider provider;

    setUp(() {
      mockService = MockPartRecommendationService();
      provider = _makeProvider(mockService);
    });

    testWidgets('パーツが0件のとき空状態が表示される', (tester) async {
      mockService.featuredResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('現在パーツは掲載されていません'), findsOneWidget);
    });

    testWidgets('おすすめパーツが正常に表示される', (tester) async {
      mockService.featuredResult = Result.success([
        _makePart(id: 'p1', name: 'HKSマフラー'),
        _makePart(id: 'p2', name: 'TRDエアフィルター'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('HKSマフラー'), findsOneWidget);
      expect(find.text('TRDエアフィルター'), findsOneWidget);
    });

    testWidgets('件数テキスト「X件のおすすめパーツ」が表示される', (tester) async {
      mockService.featuredResult = Result.success([
        _makePart(id: 'p1'),
        _makePart(id: 'p2'),
        _makePart(id: 'p3'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('おすすめパーツ'), findsOneWidget);
    });

    testWidgets('注目パーツに「広告」ラベルが表示される', (tester) async {
      mockService.featuredResult = Result.success([
        _makePart(name: 'スポンサーパーツ', isFeatured: true),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('広告'), findsOneWidget);
    });

    testWidgets('カテゴリフィルタ行が表示される', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // 「すべて」チップが存在する
      expect(find.text('すべて'), findsOneWidget);
      // ChoiceChip が複数存在する
      expect(find.byType(ChoiceChip).evaluate().length,
          greaterThanOrEqualTo(2));
    });

    testWidgets('検索バーが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('エラー時にエラーUIが表示される', (tester) async {
      mockService.featuredResult =
          Result.failure(AppError.network('connection failed'));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // エラー状態 UI（リフレッシュアイコンなど）
      expect(find.byIcon(Icons.refresh), findsWidgets);
    });

    testWidgets('価格が表示される', (tester) async {
      mockService.featuredResult = Result.success([
        _makePart(name: 'オイルフィルター', priceFrom: 3000, priceTo: 5000),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('3,000'), findsWidgets);
    });

    testWidgets('ブランド名が表示される', (tester) async {
      mockService.featuredResult = Result.success([
        _makePart(name: 'オイル', brand: 'Mobil 1'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('Mobil 1'), findsOneWidget);
    });

    testWidgets('検索テキスト入力でclearアイコンが出現する', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'マフラー');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clearアイコンタップで検索テキストがクリアされる', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'テスト');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    // --- Vehicle 指定あり ---

    testWidgets('vehicle 指定時に互換性バナーが表示される', (tester) async {
      final vehicle = _makeVehicle(maker: 'Toyota', model: 'RAV4');
      mockService.featuredResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(provider, vehicle: vehicle));
      await tester.pumpAndSettle();

      // 車両情報を含むバナー（「RAV4」や「Toyota」など）
      expect(
        find.textContaining('Toyota').evaluate().isNotEmpty ||
            find.textContaining('RAV4').evaluate().isNotEmpty ||
            find.textContaining('互換性').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('vehicle なしでもクラッシュしない', (tester) async {
      mockService.featuredResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(provider, vehicle: null));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    group('Edge Cases', () {
      testWidgets('パーツ名が非常に長くてもクラッシュしない', (tester) async {
        mockService.featuredResult = Result.success([
          _makePart(name: 'テストパーツ' * 10),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('価格なし（priceFrom: null）でもクラッシュしない', (tester) async {
        mockService.featuredResult = Result.success([
          _makePart(priceFrom: null, priceTo: null),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('評価なし（rating: null）でもクラッシュしない', (tester) async {
        mockService.featuredResult = Result.success([
          _makePart(rating: null),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('多数のパーツ（20件）でもスクロール可能', (tester) async {
        mockService.featuredResult = Result.success(
          List.generate(
            20,
            (i) => _makePart(id: 'p$i', name: 'パーツ$i'),
          ),
        );

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ブランドなし（brand: null）でもクラッシュしない', (tester) async {
        mockService.featuredResult = Result.success([
          _makePart(brand: null),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
