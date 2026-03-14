// ServiceMenuProvider Unit Tests

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/service_menu_provider.dart';
import 'package:trust_car_platform/services/service_menu_service.dart';
import 'package:trust_car_platform/models/service_menu.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock ServiceMenuService
// ---------------------------------------------------------------------------

class MockServiceMenuService implements ServiceMenuService {
  final _streamController = StreamController<List<ServiceMenu>>.broadcast();

  Result<List<ServiceMenu>, AppError> popularResult = const Result.success([]);
  Result<List<ServiceMenu>, AppError> recommendedResult =
      const Result.success([]);
  Result<Map<ServiceCategory, List<ServiceMenu>>, AppError> groupedResult =
      const Result.success({});
  Result<List<ServiceMenu>, AppError> searchResult = const Result.success([]);
  Result<List<ServiceMenu>, AppError> byCategoryResult =
      const Result.success([]);
  Result<String, AppError> createResult = const Result.success('menu_new');
  Result<void, AppError> updateResult = const Result.success(null);
  Result<void, AppError> deactivateResult = const Result.success(null);
  Result<void, AppError> activateResult = const Result.success(null);
  Result<void, AppError> deleteResult = const Result.success(null);

  // Call tracking
  int createCallCount = 0;
  int deleteCallCount = 0;
  String? lastSearchQuery;
  String? lastDeletedId;

  void emitMenus(List<ServiceMenu> menus) => _streamController.add(menus);
  void emitError(Object error) => _streamController.addError(error);

  @override
  Stream<List<ServiceMenu>> getActiveServiceMenus({String? shopId}) =>
      _streamController.stream;

  @override
  Future<Result<List<ServiceMenu>, AppError>> getPopularMenus({
    String? shopId,
    int limit = 10,
  }) async => popularResult;

  @override
  Future<Result<List<ServiceMenu>, AppError>> getRecommendedMenus({
    String? shopId,
    int limit = 10,
  }) async => recommendedResult;

  @override
  Future<Result<Map<ServiceCategory, List<ServiceMenu>>, AppError>>
      getGroupedServiceMenus({String? shopId}) async => groupedResult;

  @override
  Future<Result<List<ServiceMenu>, AppError>> searchServiceMenus({
    required String query,
    String? shopId,
  }) async {
    lastSearchQuery = query;
    return searchResult;
  }

  @override
  Future<Result<List<ServiceMenu>, AppError>> getServiceMenusByCategory(
    ServiceCategory category, {
    String? shopId,
  }) async => byCategoryResult;

  @override
  Future<Result<String, AppError>> createServiceMenu(ServiceMenu menu) async {
    createCallCount++;
    return createResult;
  }

  @override
  Future<Result<void, AppError>> updateServiceMenu(
      String menuId, ServiceMenu menu) async => updateResult;

  @override
  Future<Result<void, AppError>> deactivateServiceMenu(String menuId) async =>
      deactivateResult;

  @override
  Future<Result<void, AppError>> activateServiceMenu(String menuId) async =>
      activateResult;

  @override
  Future<Result<void, AppError>> deleteServiceMenu(String menuId) async {
    deleteCallCount++;
    lastDeletedId = menuId;
    return deleteResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  void dispose() => _streamController.close();
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ServiceMenu _makeMenu({
  String id = 'menu1',
  ServiceCategory category = ServiceCategory.oilChange,
  String name = 'オイル交換',
  int? basePrice = 3000,
  bool isActive = true,
  bool isPopular = false,
  bool isRecommended = false,
}) {
  final now = DateTime.now();
  return ServiceMenu(
    id: id,
    category: category,
    name: name,
    basePrice: basePrice,
    isActive: isActive,
    isPopular: isPopular,
    isRecommended: isRecommended,
    createdAt: now,
    updatedAt: now,
  );
}

ServiceMenuProvider _makeProvider(MockServiceMenuService service) {
  return ServiceMenuProvider(serviceMenuService: service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ServiceMenuProvider', () {
    late MockServiceMenuService mockService;
    late ServiceMenuProvider provider;

    setUp(() {
      mockService = MockServiceMenuService();
      provider = _makeProvider(mockService);
    });

    tearDown(() {
      provider.stopListening();
      mockService.dispose();
    });

    // ── 初期状態 ──────────────────────────────────────────────────────────────

    group('初期状態', () {
      test('初期状態は空でエラーなし', () {
        expect(provider.menus, isEmpty);
        expect(provider.popularMenus, isEmpty);
        expect(provider.recommendedMenus, isEmpty);
        expect(provider.groupedMenus, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });
    });

    // ── listenToMenus ─────────────────────────────────────────────────────────

    group('listenToMenus (Stream)', () {
      test('Stream からメニューを受け取ると menus が更新される', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu(id: 'm1'), _makeMenu(id: 'm2')]);
        await Future.microtask(() {});

        expect(provider.menus.length, 2);
        expect(provider.error, isNull);
      });

      test('Stream 受信後に groupedMenus がカテゴリ別にグループ化される', () async {
        provider.listenToMenus();
        mockService.emitMenus([
          _makeMenu(id: 'm1', category: ServiceCategory.oilChange),
          _makeMenu(id: 'm2', category: ServiceCategory.tire),
          _makeMenu(id: 'm3', category: ServiceCategory.oilChange),
        ]);
        await Future.microtask(() {});

        expect(provider.groupedMenus[ServiceCategory.oilChange]?.length, 2);
        expect(provider.groupedMenus[ServiceCategory.tire]?.length, 1);
      });

      test('Stream エラーで error が設定される', () async {
        provider.listenToMenus();
        mockService.emitError(
            Exception('[cloud_firestore/permission-denied] Access denied'));
        await Future.microtask(() {});

        expect(provider.error, isNotNull);
      });

      test('stopListening で購読が解除される', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu()]);
        await Future.microtask(() {});

        provider.stopListening();
        mockService.emitMenus([_makeMenu(id: 'after_stop')]);
        await Future.microtask(() {});

        expect(provider.menus.length, 1);
      });
    });

    // ── loadPopularMenus ──────────────────────────────────────────────────────

    group('loadPopularMenus', () {
      test('人気メニューを読み込める', () async {
        mockService.popularResult = Result.success([
          _makeMenu(id: 'p1', isPopular: true),
          _makeMenu(id: 'p2', isPopular: true),
        ]);

        await provider.loadPopularMenus();

        expect(provider.popularMenus.length, 2);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('失敗時にエラーが設定される', () async {
        mockService.popularResult =
            Result.failure(AppError.network('failed'));

        await provider.loadPopularMenus();

        expect(provider.error, isNotNull);
        expect(provider.popularMenus, isEmpty);
      });
    });

    // ── loadRecommendedMenus ──────────────────────────────────────────────────

    group('loadRecommendedMenus', () {
      test('おすすめメニューを読み込める', () async {
        mockService.recommendedResult = Result.success([
          _makeMenu(id: 'r1', isRecommended: true),
        ]);

        await provider.loadRecommendedMenus();

        expect(provider.recommendedMenus.length, 1);
        expect(provider.error, isNull);
      });

      test('失敗時にエラーが設定される', () async {
        mockService.recommendedResult =
            Result.failure(AppError.network('failed'));

        await provider.loadRecommendedMenus();

        expect(provider.error, isNotNull);
      });
    });

    // ── loadGroupedMenus ──────────────────────────────────────────────────────

    group('loadGroupedMenus', () {
      test('グループ化されたメニューを読み込める', () async {
        mockService.groupedResult = Result.success({
          ServiceCategory.oilChange: [_makeMenu(id: 'm1')],
          ServiceCategory.tire: [_makeMenu(id: 'm2')],
        });

        await provider.loadGroupedMenus();

        expect(provider.groupedMenus.length, 2);
        expect(provider.error, isNull);
      });

      test('失敗時にエラーが設定される', () async {
        mockService.groupedResult =
            Result.failure(AppError.network('failed'));

        await provider.loadGroupedMenus();

        expect(provider.error, isNotNull);
      });
    });

    // ── searchMenus ───────────────────────────────────────────────────────────

    group('searchMenus', () {
      test('検索結果を返す', () async {
        mockService.searchResult = Result.success([
          _makeMenu(id: 's1', name: 'タイヤ交換'),
        ]);

        final results = await provider.searchMenus('タイヤ');

        expect(results.length, 1);
        expect(provider.error, isNull);
      });

      test('正しいクエリを渡してサービスを呼び出す', () async {
        await provider.searchMenus('オイル交換');
        expect(mockService.lastSearchQuery, 'オイル交換');
      });

      test('失敗時は空リストで返る', () async {
        mockService.searchResult =
            Result.failure(AppError.network('failed'));

        final results = await provider.searchMenus('検索語');

        expect(results, isEmpty);
        expect(provider.error, isNotNull);
      });

      test('一致なしのときは空リストを返す', () async {
        mockService.searchResult = const Result.success([]);

        final results = await provider.searchMenus('存在しないメニュー');

        expect(results, isEmpty);
        expect(provider.error, isNull);
      });
    });

    // ── createMenu ────────────────────────────────────────────────────────────

    group('createMenu', () {
      test('作成成功で menuId を返す', () async {
        mockService.createResult = const Result.success('new_menu_id');

        final id = await provider.createMenu(_makeMenu());

        expect(id, 'new_menu_id');
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('作成失敗で null を返しエラーが設定される', () async {
        mockService.createResult =
            Result.failure(AppError.permission('Permission denied'));

        final id = await provider.createMenu(_makeMenu());

        expect(id, isNull);
        expect(provider.error, isNotNull);
      });
    });

    // ── updateMenu ────────────────────────────────────────────────────────────

    group('updateMenu', () {
      test('更新成功で true を返す', () async {
        final success = await provider.updateMenu('menu1', _makeMenu());
        expect(success, true);
        expect(provider.error, isNull);
      });

      test('更新失敗で false を返す', () async {
        mockService.updateResult =
            Result.failure(AppError.permission('Permission denied'));

        final success = await provider.updateMenu('menu1', _makeMenu());

        expect(success, false);
        expect(provider.error, isNotNull);
      });
    });

    // ── deactivateMenu ────────────────────────────────────────────────────────

    group('deactivateMenu', () {
      test('無効化成功で menus から除去される', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu(id: 'm1'), _makeMenu(id: 'm2')]);
        await Future.microtask(() {});

        final success = await provider.deactivateMenu('m1');

        expect(success, true);
        expect(provider.menus.length, 1);
        expect(provider.menus.first.id, 'm2');
      });

      test('無効化失敗では menus が変わらない', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu(id: 'm1')]);
        await Future.microtask(() {});

        mockService.deactivateResult =
            Result.failure(AppError.permission('Permission denied'));
        final success = await provider.deactivateMenu('m1');

        expect(success, false);
        expect(provider.menus.length, 1);
      });
    });

    // ── activateMenu ──────────────────────────────────────────────────────────

    group('activateMenu', () {
      test('有効化成功で true を返す', () async {
        final success = await provider.activateMenu('menu1');
        expect(success, true);
        expect(provider.error, isNull);
      });

      test('有効化失敗で false を返す', () async {
        mockService.activateResult =
            Result.failure(AppError.permission('Permission denied'));

        final success = await provider.activateMenu('menu1');

        expect(success, false);
        expect(provider.error, isNotNull);
      });
    });

    // ── deleteMenu ────────────────────────────────────────────────────────────

    group('deleteMenu', () {
      test('削除成功で menus から除去される', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu(id: 'm1'), _makeMenu(id: 'm2')]);
        await Future.microtask(() {});

        final success = await provider.deleteMenu('m1');

        expect(success, true);
        expect(provider.menus.length, 1);
        expect(provider.menus.first.id, 'm2');
      });

      test('削除失敗では menus が変わらない', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu(id: 'm1')]);
        await Future.microtask(() {});

        mockService.deleteResult =
            Result.failure(AppError.network('failed'));
        final success = await provider.deleteMenu('m1');

        expect(success, false);
        expect(provider.menus.length, 1);
      });

      test('正しい menuId でサービスを呼び出す', () async {
        await provider.deleteMenu('target_menu');
        expect(mockService.lastDeletedId, 'target_menu');
      });
    });

    // ── filterByCategory ──────────────────────────────────────────────────────

    group('filterByCategory', () {
      test('指定カテゴリのメニューのみ返す', () async {
        provider.listenToMenus();
        mockService.emitMenus([
          _makeMenu(id: 'm1', category: ServiceCategory.oilChange),
          _makeMenu(id: 'm2', category: ServiceCategory.tire),
          _makeMenu(id: 'm3', category: ServiceCategory.oilChange),
        ]);
        await Future.microtask(() {});

        final filtered = provider.filterByCategory(ServiceCategory.oilChange);

        expect(filtered.length, 2);
        expect(filtered.every((m) => m.category == ServiceCategory.oilChange),
            true);
      });

      test('一致するカテゴリがなければ空リスト', () {
        final filtered = provider.filterByCategory(ServiceCategory.coating);
        expect(filtered, isEmpty);
      });
    });

    // ── filterByPriceRange ────────────────────────────────────────────────────

    group('filterByPriceRange', () {
      test('料金範囲内のメニューのみ返す', () async {
        provider.listenToMenus();
        mockService.emitMenus([
          _makeMenu(id: 'm1', basePrice: 1000),
          _makeMenu(id: 'm2', basePrice: 5000),
          _makeMenu(id: 'm3', basePrice: 10000),
        ]);
        await Future.microtask(() {});

        final filtered = provider.filterByPriceRange(2000, 6000);

        expect(filtered.length, 1);
        expect(filtered.first.id, 'm2');
      });

      test('basePrice が null のメニューは除外される', () async {
        provider.listenToMenus();
        mockService.emitMenus([
          _makeMenu(id: 'm1', basePrice: null),
          _makeMenu(id: 'm2', basePrice: 3000),
        ]);
        await Future.microtask(() {});

        final filtered = provider.filterByPriceRange(0, 10000);

        expect(filtered.length, 1);
        expect(filtered.first.id, 'm2');
      });

      test('範囲境界値（最小・最大を含む）', () async {
        provider.listenToMenus();
        mockService.emitMenus([
          _makeMenu(id: 'm1', basePrice: 1000),
          _makeMenu(id: 'm2', basePrice: 5000),
        ]);
        await Future.microtask(() {});

        // 境界値をちょうど含む
        final filtered = provider.filterByPriceRange(1000, 5000);
        expect(filtered.length, 2);
      });
    });

    // ── clear ─────────────────────────────────────────────────────────────────

    group('clear', () {
      test('clear で全状態がリセットされる', () async {
        provider.listenToMenus();
        mockService.emitMenus([_makeMenu()]);
        await Future.microtask(() {});

        await provider.loadPopularMenus();

        provider.clear();

        expect(provider.menus, isEmpty);
        expect(provider.popularMenus, isEmpty);
        expect(provider.recommendedMenus, isEmpty);
        expect(provider.groupedMenus, isEmpty);
        expect(provider.error, isNull);
      });
    });

    // ── Edge Cases ────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('getMenusByCategory が失敗しても空リストで返る', () async {
        mockService.byCategoryResult =
            Result.failure(AppError.network('failed'));
        final result =
            await provider.getMenusByCategory(ServiceCategory.oilChange);
        expect(result, isEmpty);
      });

      test('空のメニュー一覧でも groupedMenus は空マップ', () async {
        provider.listenToMenus();
        mockService.emitMenus([]);
        await Future.microtask(() {});

        expect(provider.groupedMenus, isEmpty);
      });

      test('同一カテゴリのメニューが多数あっても groupedMenus が正しい', () async {
        provider.listenToMenus();
        mockService.emitMenus(
          List.generate(
              10, (i) => _makeMenu(id: 'm$i', category: ServiceCategory.maintenance)),
        );
        await Future.microtask(() {});

        expect(provider.groupedMenus[ServiceCategory.maintenance]?.length, 10);
      });

      test('isRetryable はリトライ可能エラーのとき true', () async {
        provider.listenToMenus();
        mockService.emitError(
            Exception('[cloud_firestore/unavailable] Service unavailable'));
        await Future.microtask(() {});

        expect(provider.isRetryable, true);
      });

      test('errorMessage は error がないとき null', () {
        expect(provider.errorMessage, isNull);
      });
    });
  });
}
