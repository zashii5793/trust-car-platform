import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/shop.dart';
import '../models/inquiry.dart';
import '../services/shop_service.dart';
import '../services/inquiry_service.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// BtoBマーケットプレイス プロバイダー
///
/// 設計思想:
/// - ユーザーが工場を探す、工場から売り込まない
/// - 問い合わせ起点はユーザー側のみ（FABなし、プッシュ通知なし）
/// - isFeatured は「広告」ラベルとして表示し、順位操作であることを明示する
class ShopProvider with ChangeNotifier {
  final ShopService _shopService;
  final InquiryService _inquiryService;

  ShopProvider({
    required ShopService shopService,
    required InquiryService inquiryService,
  })  : _shopService = shopService,
        _inquiryService = inquiryService;

  // --- Shop一覧系 ---
  List<Shop> _shops = [];
  List<Shop> _featuredShops = [];
  Shop? _selectedShop;

  // --- 自分のショップ ---
  Shop? _myShop;
  String? _submitError;

  // --- フィルタ状態 ---
  ShopType? _selectedType;
  ServiceCategory? _selectedService;
  String? _selectedPrefecture;

  // --- 問い合わせ系 ---
  List<Inquiry> _userInquiries = [];

  // --- 店舗オーナー向け問い合わせ一覧・件数 ---
  List<Inquiry> _shopInquiries = [];
  int _inquiryTotal = 0;
  int _inquiryUnread = 0;
  bool _isLoadingShopInquiries = false;

  // --- Firestore real-time subscription for inquiry counts ---
  StreamSubscription<Map<String, int>>? _inquirySubscription;

  // --- ローディング/エラー ---
  bool _isLoading = false;
  bool _isSubmitting = false;
  AppError? _error;

  // --- Getters ---
  List<Shop> get shops => _shops;
  List<Shop> get featuredShops => _featuredShops;
  Shop? get selectedShop => _selectedShop;
  Shop? get myShop => _myShop;
  ShopType? get selectedType => _selectedType;
  ServiceCategory? get selectedService => _selectedService;
  String? get selectedPrefecture => _selectedPrefecture;
  List<Inquiry> get userInquiries => _userInquiries;
  List<Inquiry> get shopInquiries => _shopInquiries;
  int get inquiryTotal => _inquiryTotal;
  int get inquiryUnread => _inquiryUnread;
  bool get isLoadingShopInquiries => _isLoadingShopInquiries;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get submitError => _submitError;
  AppError? get error => _error;
  String? get errorMessage => _error?.userMessage;

  /// 工場一覧を取得する（現在のフィルタを適用）
  Future<void> loadShops() async {
    _isLoading = true;
    notifyListeners();

    final result = await _shopService.getShops(
      type: _selectedType,
      serviceCategory: _selectedService,
      prefecture: _selectedPrefecture,
    );

    result.when(
      success: (shops) {
        _shops = shops;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _shops = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// おすすめ工場一覧を取得する
  Future<void> loadFeaturedShops() async {
    _isLoading = true;
    notifyListeners();

    final result = await _shopService.getFeaturedShops();

    result.when(
      success: (shops) {
        _featuredShops = shops;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _featuredShops = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 特定の工場の詳細を取得し selectedShop にセットする
  Future<void> loadShop(String shopId) async {
    _isLoading = true;
    _selectedShop = null;
    notifyListeners();

    final result = await _shopService.getShop(shopId);

    result.when(
      success: (shop) {
        _selectedShop = shop;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _selectedShop = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 工場を名前で検索する（空文字列の場合は loadShops にフォールバック）
  Future<void> searchShops(String query) async {
    if (query.isEmpty) {
      await loadShops();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final result = await _shopService.searchShops(query);

    result.when(
      success: (shops) {
        _shops = shops;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _shops = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// 業種フィルタを選択する
  void selectType(ShopType? type) {
    _selectedType = type;
    notifyListeners();
  }

  /// サービスフィルタを選択する
  void selectService(ServiceCategory? service) {
    _selectedService = service;
    notifyListeners();
  }

  /// 都道府県フィルタを選択する
  void selectPrefecture(String? prefecture) {
    _selectedPrefecture = prefecture;
    notifyListeners();
  }

  /// 全フィルタをリセットする
  void clearFilters() {
    _selectedType = null;
    _selectedService = null;
    _selectedPrefecture = null;
    notifyListeners();
  }

  /// 問い合わせを送信する
  ///
  /// 成功時は Inquiry を返す、失敗時は null を返す
  Future<Inquiry?> submitInquiry({
    required String userId,
    required String shopId,
    required InquiryType type,
    required String subject,
    required String message,
    String? vehicleId,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    final result = await _inquiryService.createInquiry(
      userId: userId,
      shopId: shopId,
      type: type,
      subject: subject,
      message: message,
      vehicleId: vehicleId,
    );

    Inquiry? created;
    result.when(
      success: (inquiry) {
        created = inquiry;
        _error = null;
      },
      failure: (err) {
        _error = err;
        created = null;
      },
    );

    _isSubmitting = false;
    notifyListeners();
    return created;
  }

  /// ユーザーの問い合わせ一覧を取得する
  Future<void> loadUserInquiries(String userId) async {
    _isLoading = true;
    notifyListeners();

    final result = await _inquiryService.getUserInquiries(userId);

    result.when(
      success: (inquiries) {
        _userInquiries = inquiries;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _userInquiries = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Load the current user's own shop
  Future<void> loadMyShop(String uid) async {
    _isLoading = true;
    notifyListeners();

    final result = await _shopService.getMyShop(uid);

    result.when(
      success: (shop) {
        _myShop = shop;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _myShop = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Load inquiry counts (total + unread) for the owner's shop (one-shot fetch).
  ///
  /// Prefer [startWatchingInquiries] for real-time updates.
  Future<void> loadInquiryCount(String shopId) async {
    final result = await _shopService.getInquiryCount(shopId);

    result.when(
      success: (counts) {
        _inquiryTotal = counts['total'] ?? 0;
        _inquiryUnread = counts['unread'] ?? 0;
      },
      failure: (_) {
        _inquiryTotal = 0;
        _inquiryUnread = 0;
      },
    );

    notifyListeners();
  }

  /// Start listening to real-time inquiry count updates for [shopId].
  ///
  /// Cancels any existing subscription before starting a new one.
  /// Call [stopWatchingInquiries] or [dispose] to clean up.
  void startWatchingInquiries(String shopId) {
    _inquirySubscription?.cancel();
    _inquirySubscription =
        _shopService.watchInquiryCount(shopId).listen((data) {
      _inquiryTotal = data['total'] ?? 0;
      _inquiryUnread = data['unread'] ?? 0;
      notifyListeners();
    });
  }

  /// Stop listening to real-time inquiry count updates.
  void stopWatchingInquiries() {
    _inquirySubscription?.cancel();
    _inquirySubscription = null;
  }

  @override
  void dispose() {
    _inquirySubscription?.cancel();
    super.dispose();
  }

  /// Load inquiry list for the owner's shop
  Future<void> loadShopInquiries(String shopId, {InquiryStatus? status}) async {
    _isLoadingShopInquiries = true;
    notifyListeners();

    final result = await _inquiryService.getShopInquiries(shopId, status: status);

    result.when(
      success: (inquiries) {
        _shopInquiries = inquiries;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _shopInquiries = [];
      },
    );

    _isLoadingShopInquiries = false;
    notifyListeners();
  }

  /// Create or update the current user's shop
  ///
  /// Returns true on success, false on failure.
  Future<bool> saveMyShop(Shop shop) async {
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    // Determine create or update based on existing _myShop
    final Result<Shop, AppError> result = _myShop == null
        ? await _shopService.createMyShop(shop)
        : await _shopService.updateMyShop(shop);

    bool success = false;
    result.when(
      success: (saved) {
        _myShop = saved;
        _error = null;
        success = true;
      },
      failure: (err) {
        _error = err;
        _submitError = err.userMessage;
        success = false;
      },
    );

    _isSubmitting = false;
    notifyListeners();
    return success;
  }

  /// Delete the current user's shop
  ///
  /// Returns true on success, false on failure.
  Future<bool> deleteMyShop(String uid) async {
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    final result = await _shopService.deleteMyShop(uid);

    bool success = false;
    result.when(
      success: (_) {
        _myShop = null;
        _error = null;
        success = true;
      },
      failure: (err) {
        _error = err;
        _submitError = err.userMessage;
        success = false;
      },
    );

    _isSubmitting = false;
    notifyListeners();
    return success;
  }

  /// 全状態をリセットする（ログアウト時など）
  void clear() {
    _shops = [];
    _featuredShops = [];
    _selectedShop = null;
    _myShop = null;
    _userInquiries = [];
    _shopInquiries = [];
    _inquiryTotal = 0;
    _inquiryUnread = 0;
    _isLoadingShopInquiries = false;
    _selectedType = null;
    _selectedService = null;
    _selectedPrefecture = null;
    _isLoading = false;
    _isSubmitting = false;
    _submitError = null;
    _error = null;
    notifyListeners();
  }
}
