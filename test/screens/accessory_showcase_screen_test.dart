// AccessoryShowcaseScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows 'みんなのアクセサリー' title
//     2. Shows category tabs
//     3. Shows '投稿する' FAB
//   Empty state:
//     4. Shows '登録されたアクセサリーはありません' when list is empty
//   List state:
//     5. Shows accessory item names when trends exist
//     6. Shows rank badges
//   Error state:
//     7. Shows '再読み込み' button on error

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/accessory_showcase.dart';
import 'package:trust_car_platform/screens/accessories/accessory_showcase_screen.dart';
import 'package:trust_car_platform/services/popular_accessories_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockPopularAccessoriesService implements PopularAccessoriesService {
  final List<AccessoryTrend> topTrends;
  final AppError? loadError;

  _MockPopularAccessoriesService({
    this.topTrends = const [],
    this.loadError,
  });

  @override
  Future<Result<List<AccessoryTrend>, AppError>> getTopAccessories({
    int limit = 20,
  }) async {
    if (loadError != null) return Result.failure(loadError!);
    return Result.success(topTrends);
  }

  @override
  Future<Result<List<AccessoryTrend>, AppError>> getPopularTrends({
    AccessoryCategory? category,
    int limit = 10,
  }) async {
    if (loadError != null) return Result.failure(loadError!);
    return const Result.success([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AccessoryTrend _makeTrend({
  String itemName = 'ドライブレコーダー',
  String? brand = 'VANTRUE',
  AccessoryCategory category = AccessoryCategory.electronics,
  int showcaseCount = 15,
  double averageRating = 4.2,
}) {
  return AccessoryTrend(
    itemName: itemName,
    brand: brand,
    category: category,
    showcaseCount: showcaseCount,
    averageRating: averageRating,
  );
}

Widget _buildScreen(_MockPopularAccessoriesService mock) {
  sl.override<PopularAccessoriesService>(mock);
  return const MaterialApp(home: AccessoryShowcaseScreen());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('AccessoryShowcaseScreen — AppBar', () {
    testWidgets('1. タイトル「みんなのアクセサリー」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockPopularAccessoriesService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('みんなのアクセサリー'), findsOneWidget);
    });

    testWidgets('2. カテゴリタブ「すべて」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockPopularAccessoriesService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('すべて'), findsOneWidget);
    });

    testWidgets('3. 「投稿する」FABが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockPopularAccessoriesService()));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('submit_showcase_fab')), findsOneWidget);
    });
  });

  // =========================================================================
  group('AccessoryShowcaseScreen — Empty state', () {
    testWidgets('4. トレンドがない場合は空メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockPopularAccessoriesService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('まだ投稿がありません'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AccessoryShowcaseScreen — List state', () {
    testWidgets('5. アクセサリー名が表示される', (tester) async {
      final trends = [
        _makeTrend(itemName: 'ドライブレコーダー'),
        _makeTrend(itemName: 'カーナビ', showcaseCount: 10),
      ];
      await tester.pumpWidget(
        _buildScreen(_MockPopularAccessoriesService(topTrends: trends)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('ドライブレコーダー'), findsOneWidget);
      expect(find.text('カーナビ'), findsOneWidget);
    });

    testWidgets('6. ランクバッジが表示される', (tester) async {
      final trends = [
        _makeTrend(itemName: 'ドライブレコーダー'),
        _makeTrend(itemName: 'カーナビ'),
      ];
      await tester.pumpWidget(
        _buildScreen(_MockPopularAccessoriesService(topTrends: trends)),
      );
      await tester.pump();
      await tester.pump();

      // Rank 1 and 2 badges
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  // =========================================================================
  group('AccessoryShowcaseScreen — Error state', () {
    testWidgets('7. エラー時は「再読み込み」ボタンが表示される', (tester) async {
      final mock = _MockPopularAccessoriesService(
        loadError: AppError.server('load failed'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.text('再読み込み'), findsOneWidget);
    });
  });
}
