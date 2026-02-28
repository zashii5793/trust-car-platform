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

  Vehicle? lastVehicle;
  PartCategory? lastCategory;

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
    return partsByCategoryResult ?? const Result.success([]);
  }

  // Unused
  @override
  Future<Result<List<PartListing>, AppError>> searchParts(
    String keyword, {
    PartCategory? category,
    int limit = 20,
  }) async => const Result.success([]);

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
      test('resets all state', () async {
        mockService.recommendationsResult = Result.success([
          _makeRecommendation(),
        ]);
        await provider.loadRecommendations(vehicle);
        provider.selectCategory(PartCategory.wheel);

        provider.clear();

        expect(provider.recommendations, isEmpty);
        expect(provider.featuredParts, isEmpty);
        expect(provider.selectedCategory, isNull);
        expect(provider.error, isNull);
        expect(provider.isLoading, isFalse);
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
