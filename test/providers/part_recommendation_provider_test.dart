import 'package:flutter_test/flutter_test.dart';
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
  Result<List<PartRecommendation>, AppError>? recommendationsResult;
  Result<List<PartListing>, AppError>? featuredPartsResult;
  Result<List<PartListing>, AppError>? partsByCategoryResult;
  Result<List<PartListing>, AppError>? searchPartsResult;

  Vehicle? lastVehicle;
  PartCategory? lastCategory;
  String? lastSearchKeyword;
  PartCategory? lastSearchCategory;

  @override
  Future<Result<List<PartRecommendation>, AppError>> getRecommendationsForVehicle(
    Vehicle vehicle, {
    PartCategory? category,
    int limit = 10,
  }) async {
    lastVehicle = vehicle;
    lastCategory = category;
    return recommendationsResult ?? const Result.success([]);
  }

  @override
  Future<Result<List<PartListing>, AppError>> getFeaturedParts({int limit = 5}) async {
    return featuredPartsResult ?? const Result.success([]);
  }

  @override
  Future<Result<List<PartListing>, AppError>> getPartsByCategory(
    PartCategory category, {
    int limit = 20,
    dynamic startAfter,
  }) async {
    lastCategory = category;
    return partsByCategoryResult ?? const Result.success([]);
  }

  @override
  Future<Result<List<PartListing>, AppError>> searchParts(
    String keyword, {
    PartCategory? category,
    int limit = 20,
  }) async {
    lastSearchKeyword = keyword;
    lastSearchCategory = category;
    return searchPartsResult ?? const Result.success([]);
  }

  @override
  Future<Result<PartListing, AppError>> getPartDetail(String partId) async =>
      Result.failure(AppError.notFound('not found'));

  @override
  List<PartProCon> generateProsAndCons(PartListing part, Vehicle vehicle) => [];
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({String id = 'v1'}) => Vehicle(
      id: id,
      userId: 'user1',
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2022,
      grade: 'Z',
      mileage: 15000,
      createdAt: DateTime(2022, 1, 1),
      updatedAt: DateTime(2022, 1, 1),
    );

PartListing _makePart({
  String id = 'p1',
  PartCategory category = PartCategory.wheel,
  double? rating,
  bool isFeatured = false,
}) =>
    PartListing(
      id: id,
      shopId: 'shop1',
      name: 'テストパーツ $id',
      description: '説明',
      category: category,
      priceFrom: 20000,
      priceTo: 30000,
      rating: rating,
      isFeatured: isFeatured,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

PartRecommendation _makeRecommendation({
  String partId = 'p1',
  CompatibilityLevel compatibility = CompatibilityLevel.compatible,
  double relevanceScore = 0.7,
  PartCategory category = PartCategory.wheel,
}) =>
    PartRecommendation(
      part: _makePart(id: partId, category: category),
      compatibility: compatibility,
      compatibilityNote: '対応',
      relevanceScore: relevanceScore,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PartRecommendationProvider', () {
    late MockPartRecommendationService mockService;
    late PartRecommendationProvider provider;
    final vehicle = _makeVehicle();

    setUp(() {
      mockService = MockPartRecommendationService();
      provider = PartRecommendationProvider(
        partRecommendationService: mockService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    // -----------------------------------------------------------------------
    // Initial state
    // -----------------------------------------------------------------------

    group('Initial State', () {
      test('recommendations is empty on init', () {
        expect(provider.recommendations, isEmpty);
      });

      test('featuredParts is empty on init', () {
        expect(provider.featuredParts, isEmpty);
      });

      test('browseParts is empty on init', () {
        expect(provider.browseParts, isEmpty);
      });

      test('searchQuery is empty string on init', () {
        expect(provider.searchQuery, '');
      });

      test('isLoading is false on init', () {
        expect(provider.isLoading, isFalse);
      });

      test('error is null on init', () {
        expect(provider.error, isNull);
      });

      test('selectedCategory is null on init', () {
        expect(provider.selectedCategory, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // loadRecommendations
    // -----------------------------------------------------------------------

    group('loadRecommendations', () {
      test('sets isLoading=true then false after completion', () async {
        final loading = <bool>[];
        provider.addListener(() => loading.add(provider.isLoading));

        await provider.loadRecommendations(vehicle);

        expect(loading, contains(true));
        expect(provider.isLoading, isFalse);
      });

      test('populates recommendations on success', () async {
        mockService.recommendationsResult = Result.success([
          _makeRecommendation(partId: 'p1'),
          _makeRecommendation(partId: 'p2'),
        ]);

        await provider.loadRecommendations(vehicle);

        expect(provider.recommendations.length, 2);
        expect(provider.error, isNull);
      });

      test('sets error on failure', () async {
        mockService.recommendationsResult =
            Result.failure(AppError.server('接続エラー'));

        await provider.loadRecommendations(vehicle);

        expect(provider.error, isNotNull);
        expect(provider.recommendations, isEmpty);
      });

      test('passes selected category to service', () async {
        await provider.loadRecommendations(vehicle, category: PartCategory.wheel);

        expect(mockService.lastCategory, PartCategory.wheel);
      });

      test('clears error on subsequent successful load', () async {
        mockService.recommendationsResult = Result.failure(AppError.server('err'));
        await provider.loadRecommendations(vehicle);
        expect(provider.error, isNotNull);

        mockService.recommendationsResult = const Result.success([]);
        await provider.loadRecommendations(vehicle);
        expect(provider.error, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // loadFeaturedParts
    // -----------------------------------------------------------------------

    group('loadFeaturedParts', () {
      test('populates featuredParts on success', () async {
        mockService.featuredPartsResult = Result.success([
          _makePart(id: 'fp1', isFeatured: true),
          _makePart(id: 'fp2', isFeatured: true),
        ]);

        await provider.loadFeaturedParts();

        expect(provider.featuredParts.length, 2);
        expect(provider.error, isNull);
      });

      test('sets error on failure', () async {
        mockService.featuredPartsResult =
            Result.failure(AppError.server('接続エラー'));

        await provider.loadFeaturedParts();

        expect(provider.error, isNotNull);
        expect(provider.featuredParts, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // selectCategory
    // -----------------------------------------------------------------------

    group('selectCategory', () {
      test('updates selectedCategory', () {
        provider.selectCategory(PartCategory.wheel);
        expect(provider.selectedCategory, PartCategory.wheel);
      });

      test('setting null clears category', () {
        provider.selectCategory(PartCategory.wheel);
        provider.selectCategory(null);
        expect(provider.selectedCategory, isNull);
      });

      test('selectCategory notifies listeners', () {
        bool notified = false;
        provider.addListener(() => notified = true);

        provider.selectCategory(PartCategory.aero);

        expect(notified, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // filteredRecommendations
    // -----------------------------------------------------------------------

    group('filteredRecommendations', () {
      setUp(() async {
        mockService.recommendationsResult = Result.success([
          _makeRecommendation(partId: 'p1', category: PartCategory.wheel),
          _makeRecommendation(partId: 'p2', category: PartCategory.aero),
          _makeRecommendation(partId: 'p3', category: PartCategory.wheel),
        ]);
        await provider.loadRecommendations(vehicle);
      });

      test('returns all when no category selected', () {
        expect(provider.filteredRecommendations.length, 3);
      });

      test('filters by selected category', () {
        provider.selectCategory(PartCategory.wheel);
        expect(provider.filteredRecommendations.length, 2);
        expect(
          provider.filteredRecommendations
              .every((r) => r.part.category == PartCategory.wheel),
          isTrue,
        );
      });

      test('returns empty if no parts match category', () {
        provider.selectCategory(PartCategory.exhaust);
        expect(provider.filteredRecommendations, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // clear
    // -----------------------------------------------------------------------

    group('clear', () {
      test('resets all state including browseParts and searchQuery', () async {
        mockService.recommendationsResult = Result.success([
          _makeRecommendation(),
        ]);
        mockService.searchPartsResult = Result.success([
          _makePart(id: 'bp1'),
        ]);
        await provider.loadRecommendations(vehicle);
        await provider.loadBrowseParts(query: 'タイヤ');
        provider.selectCategory(PartCategory.wheel);

        provider.clear();

        expect(provider.recommendations, isEmpty);
        expect(provider.featuredParts, isEmpty);
        expect(provider.browseParts, isEmpty);
        expect(provider.searchQuery, '');
        expect(provider.selectedCategory, isNull);
        expect(provider.error, isNull);
        expect(provider.isLoading, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // loadBrowseParts
    // -----------------------------------------------------------------------

    group('loadBrowseParts', () {
      test('calls getFeaturedParts when no query and no category', () async {
        mockService.featuredPartsResult = Result.success([
          _makePart(id: 'fp1', isFeatured: true),
          _makePart(id: 'fp2', isFeatured: true),
        ]);

        await provider.loadBrowseParts();

        expect(provider.browseParts.length, 2);
        expect(provider.error, isNull);
        expect(mockService.lastSearchKeyword, isNull);
        expect(mockService.lastCategory, isNull);
      });

      test('calls getPartsByCategory when category specified and no query', () async {
        mockService.partsByCategoryResult = Result.success([
          _makePart(id: 'c1', category: PartCategory.tire),
          _makePart(id: 'c2', category: PartCategory.tire),
        ]);

        await provider.loadBrowseParts(category: PartCategory.tire);

        expect(provider.browseParts.length, 2);
        expect(mockService.lastCategory, PartCategory.tire);
        expect(provider.error, isNull);
      });

      test('calls searchParts when query is specified', () async {
        mockService.searchPartsResult = Result.success([
          _makePart(id: 's1'),
        ]);

        await provider.loadBrowseParts(query: 'ブレーキ');

        expect(provider.browseParts.length, 1);
        expect(mockService.lastSearchKeyword, 'ブレーキ');
        expect(provider.searchQuery, 'ブレーキ');
      });

      test('passes category to searchParts when both query and category specified', () async {
        mockService.searchPartsResult = Result.success([_makePart()]);

        await provider.loadBrowseParts(
          query: 'ホイール',
          category: PartCategory.wheel,
        );

        expect(mockService.lastSearchKeyword, 'ホイール');
        expect(mockService.lastSearchCategory, PartCategory.wheel);
      });

      test('sets isLoading=true then false around async operation', () async {
        final loadingStates = <bool>[];
        provider.addListener(() => loadingStates.add(provider.isLoading));

        await provider.loadBrowseParts();

        expect(loadingStates, contains(true));
        expect(provider.isLoading, isFalse);
      });

      test('sets error and clears browseParts on failure', () async {
        mockService.featuredPartsResult =
            Result.failure(AppError.server('サーバーエラー'));

        await provider.loadBrowseParts();

        expect(provider.error, isNotNull);
        expect(provider.browseParts, isEmpty);
      });

      test('clears error on subsequent successful load', () async {
        mockService.featuredPartsResult =
            Result.failure(AppError.server('一時的なエラー'));
        await provider.loadBrowseParts();
        expect(provider.error, isNotNull);

        mockService.featuredPartsResult = const Result.success([]);
        await provider.loadBrowseParts();
        expect(provider.error, isNull);
      });

      test('whitespace-only query is treated as empty (calls getFeaturedParts)', () async {
        mockService.featuredPartsResult = Result.success([_makePart()]);

        await provider.loadBrowseParts(query: '   ');

        // trim()後が空文字なのでgetFeaturedPartsが呼ばれる
        expect(provider.browseParts.length, 1);
        expect(mockService.lastSearchKeyword, isNull);
      });

      test('searchQuery is updated with the provided query', () async {
        await provider.loadBrowseParts(query: 'マフラー');
        expect(provider.searchQuery, 'マフラー');

        // queryなしで再ロードするとsearchQueryがリセットされる
        await provider.loadBrowseParts();
        expect(provider.searchQuery, '');
      });
    });

    // -----------------------------------------------------------------------
    // Edge Cases
    // -----------------------------------------------------------------------

    group('Edge Cases', () {
      test('concurrent loadRecommendations calls do not corrupt state', () async {
        mockService.recommendationsResult = Result.success([
          _makeRecommendation(partId: 'p1'),
        ]);

        // Fire two loads without awaiting the first
        final f1 = provider.loadRecommendations(vehicle);
        final f2 = provider.loadRecommendations(vehicle);
        await Future.wait([f1, f2]);

        // Should not throw and state should be consistent
        expect(provider.isLoading, isFalse);
      });

      test('loadRecommendations with empty vehicle maker still calls service', () async {
        final emptyVehicle = Vehicle(
          id: 'v-empty',
          userId: 'u1',
          maker: '',
          model: '',
          year: 0,
          grade: '',
          mileage: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await provider.loadRecommendations(emptyVehicle);

        expect(mockService.lastVehicle, isNotNull);
        expect(mockService.lastVehicle!.id, 'v-empty');
      });

      test('high relevance score recommendations are accessible', () async {
        mockService.recommendationsResult = Result.success([
          _makeRecommendation(partId: 'p1', relevanceScore: 0.9),
          _makeRecommendation(partId: 'p2', relevanceScore: 0.3),
        ]);

        await provider.loadRecommendations(vehicle);

        expect(
          provider.recommendations.any((r) => r.relevanceScore >= 0.9),
          isTrue,
        );
      });
    });
  });
}
