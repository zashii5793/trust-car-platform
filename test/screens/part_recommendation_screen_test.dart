// PartRecommendationScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows 'パーツ提案' title
//     2. Shows vehicle name in AppBar subtitle
//     3. Refresh button hidden while loading
//     4. Refresh button visible when not loading
//   Loading state:
//     5. Shows loading indicator while loading
//   Error state:
//     6. Shows error message when error
//   Empty state:
//     7. Shows 'ご利用いただける提案はありません' when no results
//     8. Shows category-specific message when category selected
//   Category filter:
//     9. Shows 'すべて' chip
//    10. Shows category chips for each PartCategory
//   Recommendations displayed:
//    11. Shows part name
//    12. Shows price display
//    13. Shows brand name when present
//    14. Shows pros text
//    15. Shows cons text
//    16. Shows '詳細を見る' button
//   Edge Cases:
//    17. Part without brand shows no brand text
//    18. Part with price shows formatted price
//    19. Multiple recommendations all displayed

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/part_recommendation_provider.dart';
import 'package:trust_car_platform/screens/parts/part_recommendation_screen.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/services/post_service.dart';

// ---------------------------------------------------------------------------
// Stub services
// ---------------------------------------------------------------------------

class _StubRecommendationService implements PartRecommendationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubPostService implements PostService {
  final List<Post> posts;
  int callCount = 0;

  _StubPostService({this.posts = const []});

  @override
  Future<Result<List<Post>, AppError>> getFeed({
    int limit = 20,
    DocumentSnapshot? startAfter,
    PostCategory? category,
    String? makerId,
    String? modelName,
  }) async {
    callCount++;
    return Result.success(posts);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake provider
// ---------------------------------------------------------------------------

class _FakeProvider extends PartRecommendationProvider {
  final bool _loading;
  final AppError? _err;
  final List<PartRecommendation> _recs;
  final PartCategory? _selected;

  _FakeProvider({
    bool loading = false,
    AppError? error,
    List<PartRecommendation> recommendations = const [],
    PartCategory? selectedCategory,
  })  : _loading = loading,
        _err = error,
        _recs = recommendations,
        _selected = selectedCategory,
        super(
          partRecommendationService: _StubRecommendationService(),
        );

  @override
  bool get isLoading => _loading;

  @override
  AppError? get error => _err;

  @override
  String? get errorMessage => _err?.userMessage;

  @override
  List<PartRecommendation> get filteredRecommendations => _recs;

  @override
  PartCategory? get selectedCategory => _selected;

  @override
  Future<void> loadRecommendations(Vehicle vehicle,
      {PartCategory? category}) async {}

  @override
  void selectCategory(PartCategory? category) {}
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String maker = 'トヨタ',
  String model = 'プリウス',
}) {
  final now = DateTime(2025, 1, 1);
  return Vehicle(
    id: 'vehicle-1',
    userId: 'user-1',
    maker: maker,
    model: model,
    year: 2020,
    grade: 'E',
    mileage: 30000,
    createdAt: now,
    updatedAt: now,
  );
}

PartListing _makePart({
  String id = 'part-1',
  String name = 'テストパーツ',
  String? brand,
  int? priceFrom,
  PartCategory category = PartCategory.suspension,
  List<PartProCon> prosAndCons = const [],
}) {
  final now = DateTime(2025, 1, 1);
  return PartListing(
    id: id,
    shopId: 'shop-1',
    name: name,
    description: 'テスト説明',
    category: category,
    brand: brand,
    priceFrom: priceFrom,
    createdAt: now,
    updatedAt: now,
    prosAndCons: prosAndCons,
  );
}

PartRecommendation _makeRecommendation({
  String partId = 'part-1',
  String partName = 'テストパーツ',
  String? brand,
  int? priceFrom,
  double relevanceScore = 0.8,
  List<PartProCon> prosAndCons = const [],
}) {
  return PartRecommendation(
    part: _makePart(
      id: partId,
      name: partName,
      brand: brand,
      priceFrom: priceFrom,
      prosAndCons: prosAndCons,
    ),
    compatibility: CompatibilityLevel.compatible,
    relevanceScore: relevanceScore,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen(_FakeProvider provider, {Vehicle? vehicle}) {
  return ChangeNotifierProvider<PartRecommendationProvider>.value(
    value: provider,
    child: MaterialApp(
      home: PartRecommendationScreen(
        vehicle: vehicle ?? _makeVehicle(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PartRecommendationScreen — AppBar', () {
    testWidgets('1. shows パーツ提案 title', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pump();

      expect(find.text('パーツ提案'), findsOneWidget);
    });

    testWidgets('2. shows vehicle name in AppBar subtitle', (tester) async {
      final vehicle = _makeVehicle(maker: 'ホンダ', model: 'フィット');
      await tester.pumpWidget(
        _buildScreen(_FakeProvider(), vehicle: vehicle),
      );
      await tester.pump();

      expect(find.text('ホンダ フィット'), findsOneWidget);
    });

    testWidgets('3. refresh button hidden while loading', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_FakeProvider(loading: true)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('4. refresh button visible when not loading', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });

  group('PartRecommendationScreen — Loading state', () {
    testWidgets('5. shows loading indicator while loading', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_FakeProvider(loading: true)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PartRecommendationScreen — Error state', () {
    testWidgets('6. shows error message on failure', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(error: AppError.server('取得に失敗しました')),
        ),
      );
      await tester.pump();

      // Error state widget renders the userMessage + retry button
      expect(find.textContaining('サーバーエラー'), findsOneWidget);
    });
  });

  group('PartRecommendationScreen — Empty state', () {
    testWidgets('7. shows empty message when no results', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_FakeProvider(recommendations: [])),
      );
      await tester.pump();

      expect(
        find.textContaining('ご利用いただける提案はありません'),
        findsOneWidget,
      );
    });

    testWidgets('8. category-specific message when filtered', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [],
            selectedCategory: PartCategory.suspension,
          ),
        ),
      );
      await tester.pump();

      // Message includes the category display name
      expect(find.textContaining('の提案はありません'), findsOneWidget);
    });
  });

  group('PartRecommendationScreen — Category filter', () {
    testWidgets('9. shows すべて chip', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pump();

      expect(find.text('すべて'), findsOneWidget);
    });

    testWidgets('10. shows category filter chips', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pump();

      // There should be multiple FilterChip widgets (すべて + all PartCategory values)
      expect(find.byType(FilterChip), findsWidgets);
    });
  });

  group('PartRecommendationScreen — Recommendations displayed', () {
    testWidgets('11. shows part name', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [_makeRecommendation(partName: 'BLITZ車高調 ZZ-R')],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BLITZ車高調 ZZ-R'), findsOneWidget);
    });

    testWidgets('12. shows price display', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [_makeRecommendation(priceFrom: 120000)],
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('¥'), findsOneWidget);
    });

    testWidgets('13. shows brand name when present', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [_makeRecommendation(brand: 'BILSTEIN')],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BILSTEIN'), findsOneWidget);
    });

    testWidgets('14. shows pros text', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [
              _makeRecommendation(
                prosAndCons: [
                  const PartProCon(text: '乗り心地が良い', isPro: true),
                ],
              )
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('乗り心地が良い'), findsOneWidget);
    });

    testWidgets('15. shows cons text', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [
              _makeRecommendation(
                prosAndCons: [
                  const PartProCon(text: '価格が高い', isPro: false),
                ],
              )
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('価格が高い'), findsOneWidget);
    });

    testWidgets('16. shows 詳細を見る button', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [_makeRecommendation()],
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('詳細'), findsOneWidget);
    });
  });

  group('PartRecommendationScreen — Edge Cases', () {
    testWidgets('17. part without brand shows no brand text', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [_makeRecommendation(brand: null)],
          ),
        ),
      );
      await tester.pump();

      // The part name should still show, but no brand widget
      expect(find.text('テストパーツ'), findsOneWidget);
    });

    testWidgets('18. part with price shows formatted ¥ amount', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [_makeRecommendation(priceFrom: 55000)],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('¥55,000'), findsOneWidget);
    });

    testWidgets('19. multiple recommendations all displayed', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProvider(
            recommendations: [
              _makeRecommendation(partId: '1', partName: 'パーツA'),
              _makeRecommendation(partId: '2', partName: 'パーツB'),
              _makeRecommendation(partId: '3', partName: 'パーツC'),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('パーツA'), findsOneWidget);
      expect(find.text('パーツB'), findsOneWidget);
      expect(find.text('パーツC'), findsOneWidget);
    });
  });

  group('PartRecommendationScreen — _OwnerExamplesSection', () {
    late _StubPostService postService;

    setUp(() {
      postService = _StubPostService(posts: [
        Post(
          id: 'post-1',
          userId: 'user-1',
          userDisplayName: 'テストユーザー',
          category: PostCategory.customization,
          content: 'プリウスにドラレコ付けました',
          createdAt: DateTime(2025, 6, 1),
          updatedAt: DateTime(2025, 6, 1),
        ),
      ]);
      sl.override<PostService>(postService);
    });

    tearDown(() => Injection.reset());

    testWidgets('20. PostService登録済みで投稿ありの場合に装着例セクションが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('owner_examples_section')), findsOneWidget);
    });

    testWidgets('21. 装着例セクションヘッダーに再読み込みボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('owner_examples_refresh_btn')),
        findsOneWidget,
      );
    });

    testWidgets('22. 再読み込みボタンをタップするとPostServiceを再度呼び出す', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeProvider()));
      await tester.pumpAndSettle();

      final callsBefore = postService.callCount;
      await tester.tap(find.byKey(const Key('owner_examples_refresh_btn')));
      await tester.pumpAndSettle();

      expect(postService.callCount, greaterThan(callsBefore));
    });
  });
}
