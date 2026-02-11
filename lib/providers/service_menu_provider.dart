import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/service_menu.dart';
import '../services/service_menu_service.dart';
import '../core/error/app_error.dart';

/// サービスメニュー状態管理Provider
///
/// エラーはAppError型で保持し、型安全なエラーハンドリングを実現
class ServiceMenuProvider with ChangeNotifier {
  final ServiceMenuService _serviceMenuService;

  ServiceMenuProvider({required ServiceMenuService serviceMenuService})
      : _serviceMenuService = serviceMenuService;

  List<ServiceMenu> _menus = [];
  List<ServiceMenu> _popularMenus = [];
  List<ServiceMenu> _recommendedMenus = [];
  Map<ServiceCategory, List<ServiceMenu>> _groupedMenus = {};
  bool _isLoading = false;
  AppError? _error;
  StreamSubscription<List<ServiceMenu>>? _menusSubscription;

  List<ServiceMenu> get menus => _menus;
  List<ServiceMenu> get popularMenus => _popularMenus;
  List<ServiceMenu> get recommendedMenus => _recommendedMenus;
  Map<ServiceCategory, List<ServiceMenu>> get groupedMenus => _groupedMenus;
  bool get isLoading => _isLoading;

  /// エラー（AppError型）
  AppError? get error => _error;

  /// エラーメッセージ（ユーザー向け）
  String? get errorMessage => _error?.userMessage;

  /// エラーがリトライ可能か
  bool get isRetryable => _error?.isRetryable ?? false;

  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  /// サービスメニュー一覧をリスニング
  void listenToMenus({String? shopId}) {
    _menusSubscription?.cancel();

    _menusSubscription = _serviceMenuService.getActiveServiceMenus(shopId: shopId).listen(
      (menus) {
        _menus = menus;
        _error = null;
        _retryCount = 0;
        _updateGroupedMenus();
        notifyListeners();
      },
      onError: (error) {
        _error = mapFirebaseError(error);
        notifyListeners();
        _scheduleRetry(() => listenToMenus(shopId: shopId));
      },
    );
  }

  void _updateGroupedMenus() {
    _groupedMenus = {};
    for (final menu in _menus) {
      _groupedMenus.putIfAbsent(menu.category, () => []);
      _groupedMenus[menu.category]!.add(menu);
    }
  }

  void _scheduleRetry(VoidCallback action) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: 2 << _retryCount);
    _retryCount++;
    _retryTimer = Timer(delay, action);
  }

  /// リソースの解放
  void stopListening() {
    _menusSubscription?.cancel();
    _menusSubscription = null;
    _retryTimer?.cancel();
    _retryCount = 0;
  }

  /// ログアウト時のクリーンアップ
  void clear() {
    stopListening();
    _menus = [];
    _popularMenus = [];
    _recommendedMenus = [];
    _groupedMenus = {};
    _error = null;
    notifyListeners();
  }

  /// 人気メニューを読み込み
  Future<void> loadPopularMenus({String? shopId, int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    final result = await _serviceMenuService.getPopularMenus(
      shopId: shopId,
      limit: limit,
    );
    result.when(
      success: (menus) {
        _popularMenus = menus;
        _error = null;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// おすすめメニューを読み込み
  Future<void> loadRecommendedMenus({String? shopId, int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    final result = await _serviceMenuService.getRecommendedMenus(
      shopId: shopId,
      limit: limit,
    );
    result.when(
      success: (menus) {
        _recommendedMenus = menus;
        _error = null;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// カテゴリ別にグループ化されたメニューを読み込み
  Future<void> loadGroupedMenus({String? shopId}) async {
    _isLoading = true;
    notifyListeners();

    final result = await _serviceMenuService.getGroupedServiceMenus(shopId: shopId);
    result.when(
      success: (grouped) {
        _groupedMenus = grouped;
        _error = null;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// メニューを検索
  Future<List<ServiceMenu>> searchMenus(String query, {String? shopId}) async {
    _isLoading = true;
    notifyListeners();

    final result = await _serviceMenuService.searchServiceMenus(
      query: query,
      shopId: shopId,
    );
    List<ServiceMenu> searchResults = [];

    result.when(
      success: (menus) {
        searchResults = menus;
        _error = null;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return searchResults;
  }

  /// カテゴリ別メニューを取得
  Future<List<ServiceMenu>> getMenusByCategory(
    ServiceCategory category, {
    String? shopId,
  }) async {
    final result = await _serviceMenuService.getServiceMenusByCategory(
      category,
      shopId: shopId,
    );
    return result.getOrElse([]);
  }

  /// メニューを作成（管理者用）
  Future<String?> createMenu(ServiceMenu menu) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _serviceMenuService.createServiceMenu(menu);
    String? menuId;

    result.when(
      success: (id) {
        menuId = id;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return menuId;
  }

  /// メニューを更新（管理者用）
  Future<bool> updateMenu(String menuId, ServiceMenu menu) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _serviceMenuService.updateServiceMenu(menuId, menu);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// メニューを無効化（管理者用）
  Future<bool> deactivateMenu(String menuId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _serviceMenuService.deactivateServiceMenu(menuId);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
        _menus.removeWhere((menu) => menu.id == menuId);
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// メニューを有効化（管理者用）
  Future<bool> activateMenu(String menuId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _serviceMenuService.activateServiceMenu(menuId);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// メニューを削除（管理者用）
  Future<bool> deleteMenu(String menuId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _serviceMenuService.deleteServiceMenu(menuId);
    bool success = false;

    result.when(
      success: (_) {
        success = true;
        _menus.removeWhere((menu) => menu.id == menuId);
      },
      failure: (error) {
        _error = error;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// カテゴリでフィルタリング
  List<ServiceMenu> filterByCategory(ServiceCategory category) {
    return _menus.where((menu) => menu.category == category).toList();
  }

  /// 料金範囲でフィルタリング
  List<ServiceMenu> filterByPriceRange(int minPrice, int maxPrice) {
    return _menus.where((menu) {
      final price = menu.basePrice;
      if (price == null) return false;
      return price >= minPrice && price <= maxPrice;
    }).toList();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
