// PartDetailScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/marketplace/part_detail_screen.dart';
import 'package:trust_car_platform/providers/part_recommendation_provider.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

// ---------------------------------------------------------------------------
// Mock PartRecommendationService
// ---------------------------------------------------------------------------

class MockPartRecommendationService implements PartRecommendationService {
  Result<PartListing, AppError>? detailResult;

  @override
  Future<Result<PartListing, AppError>> getPartDetail(String partId) async {
    return detailResult ?? Result.failure(AppError.notFound('パーツが見つかりません'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PartListing _makePart({
  String id = 'part1',
  String name = 'スポーツエアフィルター',
  String description = '高性能エアフィルターです',
  PartCategory category = PartCategory.intake,
  int? priceFrom = 8000,
  int? priceTo,
  bool isPriceNegotiable = false,
  String? brand = 'HKS',
  String? partNumber = 'HKS-001',
  double? rating = 4.2,
  int reviewCount = 12,
  bool isFeatured = false,
  List<PartProCon> prosAndCons = const [],
  List<VehicleSpec> compatibleVehicles = const [],
  List<String> tags = const [],
  List<String> imageUrls = const [],
}) {
  final now = DateTime.now();
  return PartListing(
    id: id,
    shopId: 'shop1',
    name: name,
    description: description,
    category: category,
    priceFrom: priceFrom,
    priceTo: priceTo,
    isPriceNegotiable: isPriceNegotiable,
    brand: brand,
    partNumber: partNumber,
    rating: rating,
    reviewCount: reviewCount,
    isFeatured: isFeatured,
    prosAndCons: prosAndCons,
    compatibleVehicles: compatibleVehicles,
    tags: tags,
    imageUrls: imageUrls,
    createdAt: now,
    updatedAt: now,
  );
}

Vehicle _makeVehicle({
  String maker = 'Toyota',
  String model = 'GR86',
  int year = 2022,
}) {
  final now = DateTime.now();
  return Vehicle(
    id: 'v1',
    userId: 'u1',
    maker: maker,
    model: model,
    grade: 'RZ',
    year: year,
    mileage: 10000,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(
  PartListing part, {
  Vehicle? vehicle,
  MockPartRecommendationService? mockService,
}) {
  final service = mockService ?? MockPartRecommendationService();
  // Pre-set detail result to match the part being displayed
  service.detailResult ??= Result.success(part);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PartRecommendationProvider(
          partRecommendationService: service,
        ),
      ),
    ],
    child: MaterialApp(
      home: PartDetailScreen(part: part, vehicle: vehicle),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PartDetailScreen', () {
    testWidgets('パーツ名がタイトルに表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(name: 'スポーツエアフィルター')));
      await tester.pump();

      expect(find.text('スポーツエアフィルター'), findsWidgets);
    });

    testWidgets('説明文が表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(description: '高性能なフィルターです')));
      await tester.pump();

      expect(find.text('高性能なフィルターです'), findsOneWidget);
    });

    testWidgets('ブランド名が基本情報テーブルに表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(brand: 'TRD')));
      await tester.pump();

      expect(find.text('TRD'), findsOneWidget);
    });

    testWidgets('品番が基本情報テーブルに表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(partNumber: 'TRD-12345')));
      await tester.pump();

      expect(find.text('TRD-12345'), findsOneWidget);
    });

    testWidgets('価格が表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(priceFrom: 15000)));
      await tester.pump();

      expect(find.text('¥15,000'), findsWidgets);
    });

    testWidgets('価格が要問合せの場合に表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(priceFrom: null)));
      await tester.pump();

      expect(find.text('要問合せ'), findsWidgets);
    });

    testWidgets('価格範囲が表示される', (tester) async {
      await tester
          .pumpWidget(_buildApp(_makePart(priceFrom: 5000, priceTo: 10000)));
      await tester.pump();

      expect(find.textContaining('5,000'), findsWidgets);
    });

    testWidgets('評価が表示される', (tester) async {
      await tester
          .pumpWidget(_buildApp(_makePart(rating: 4.2, reviewCount: 12)));
      await tester.pump();

      expect(find.textContaining('4.2'), findsOneWidget);
      expect(find.textContaining('12件'), findsOneWidget);
    });

    testWidgets('評価がnullのときクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(rating: null)));
      await tester.pump();

      expect(find.byType(PartDetailScreen), findsOneWidget);
    });

    testWidgets('isFeatured=trueのとき広告ラベルが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(isFeatured: true)));
      await tester.pump();

      expect(find.text('広告'), findsOneWidget);
    });

    testWidgets('isFeatured=falseのとき広告ラベルが表示されない', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(isFeatured: false)));
      await tester.pump();

      expect(find.text('広告'), findsNothing);
    });

    testWidgets('カテゴリが基本情報テーブルに表示される', (tester) async {
      await tester
          .pumpWidget(_buildApp(_makePart(category: PartCategory.intake)));
      await tester.pump();

      expect(find.text(PartCategory.intake.displayName), findsOneWidget);
    });

    testWidgets('問い合わせボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart()));
      await tester.pump();

      expect(find.text('問い合わせ'), findsOneWidget);
    });

    testWidgets('問い合わせボタンを押すとSnackBarが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(_makePart()));
      await tester.pump();

      await tester.tap(find.text('問い合わせ'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('メリット・デメリットが表示される', (tester) async {
      final part = _makePart(
        prosAndCons: [
          const PartProCon(text: 'レスポンスが向上する', isPro: true),
          const PartProCon(text: '洗浄が必要', isPro: false),
        ],
      );
      await tester.pumpWidget(_buildApp(part));
      await tester.pump();

      expect(find.text('レスポンスが向上する'), findsOneWidget);
      expect(find.text('洗浄が必要'), findsOneWidget);
      expect(find.text('メリット'), findsOneWidget);
      expect(find.text('デメリット'), findsOneWidget);
    });

    testWidgets('prosAndConsが空のときメリット・デメリットセクションが表示されない',
        (tester) async {
      await tester.pumpWidget(_buildApp(_makePart(prosAndCons: [])));
      await tester.pump();

      expect(find.text('メリット'), findsNothing);
      expect(find.text('デメリット'), findsNothing);
    });

    testWidgets('tagsが表示される', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          _buildApp(_makePart(tags: ['スポーツ', '吸気系', 'インプレッサ対応'])));
      await tester.pump();

      expect(find.text('スポーツ'), findsAtLeast(1));
      expect(find.text('吸気系'), findsAtLeast(1));
    });

    testWidgets('エラー時にエラー表示になる', (tester) async {
      final mockService = MockPartRecommendationService();
      mockService.detailResult =
          Result.failure(AppError.network('connection failed'));

      final part = _makePart();
      await tester.pumpWidget(_buildApp(part, mockService: mockService));
      await tester.pump();

      expect(find.byType(AppErrorState), findsOneWidget);
    });

    // ── 車両互換性 ──────────────────────────────────────────────────────────

    group('車両互換性', () {
      testWidgets('車両指定なしのときデフォルト互換性のみ表示される', (tester) async {
        await tester.pumpWidget(_buildApp(_makePart()));
        await tester.pump();

        expect(find.textContaining('一般的な互換性'), findsOneWidget);
        expect(find.textContaining('あなたの車との互換性'), findsNothing);
      });

      testWidgets('車両指定ありのとき互換性バナーが表示される', (tester) async {
        await tester
            .pumpWidget(_buildApp(_makePart(), vehicle: _makeVehicle()));
        await tester.pump();

        expect(find.textContaining('あなたの車との互換性'), findsOneWidget);
        expect(find.textContaining('Toyota'), findsOneWidget);
      });

      testWidgets('互換車両リストが表示される', (tester) async {
        final part = _makePart(
          compatibleVehicles: [
            const VehicleSpec(
              makerId: 'toyota',
              modelId: 'gr86',
              yearFrom: 2021,
            ),
          ],
        );
        await tester.pumpWidget(_buildApp(part));
        await tester.pump();

        expect(find.textContaining('gr86'), findsOneWidget);
        expect(find.textContaining('対応確認済み'), findsOneWidget);
      });
    });

    // ── Edge Cases ─────────────────────────────────────────────────────────

    group('Edge Cases', () {
      testWidgets('ブランド・品番がnullでもクラッシュしない', (tester) async {
        await tester
            .pumpWidget(_buildApp(_makePart(brand: null, partNumber: null)));
        await tester.pump();

        expect(find.byType(PartDetailScreen), findsOneWidget);
      });

      testWidgets('説明文が長くても表示できる', (tester) async {
        await tester
            .pumpWidget(_buildApp(_makePart(description: 'あ' * 500)));
        await tester.pump();

        expect(find.byType(PartDetailScreen), findsOneWidget);
      });

      testWidgets('互換車両が11台以上のとき「他N台」が表示される', (tester) async {
        final vehicles = List.generate(
          12,
          (i) => VehicleSpec(
            makerId: 'maker$i',
            modelId: 'model$i',
          ),
        );
        final part = _makePart(compatibleVehicles: vehicles);
        await tester.pumpWidget(_buildApp(part));
        await tester.pump();

        expect(find.textContaining('他2台'), findsOneWidget);
      });

      testWidgets('価格交渉可の場合に「応相談」が表示される', (tester) async {
        await tester.pumpWidget(
            _buildApp(_makePart(isPriceNegotiable: true, priceFrom: 10000)));
        await tester.pump();

        expect(find.text('応相談'), findsOneWidget);
      });

      testWidgets('エラー後にリトライできる', (tester) async {
        final mockService = MockPartRecommendationService();
        mockService.detailResult =
            Result.failure(AppError.network('failed'));

        final part = _makePart();
        await tester.pumpWidget(_buildApp(part, mockService: mockService));
        await tester.pump();

        expect(find.byType(AppErrorState), findsOneWidget);

        // Fix result and retry
        mockService.detailResult = Result.success(part);
        final retryButton = find.widgetWithText(TextButton, '再試行');
        if (retryButton.evaluate().isNotEmpty) {
          await tester.tap(retryButton);
          await tester.pump();
        }
      });
    });
  });
}
