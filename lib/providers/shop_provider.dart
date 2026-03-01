import 'package:flutter/foundation.dart';
import '../models/shop.dart';
import '../models/inquiry.dart';
import '../services/shop_service.dart';
import '../services/inquiry_service.dart';
import '../core/error/app_error.dart';

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

  // --- フィルタ状態 ---
  ShopType? _selectedType;
  ServiceCategory? _selectedService;
  String? _selectedPrefecture;

  // --- 問い合わせ系 ---
  List<Inquiry> _userInquiries = [];

  // --- ローディング/エラー ---
  bool _isLoading = false;
  bool _isSubmitting = false;
  AppError? _error;

  // --- Getters ---
  List<Shop> get shops => _shops;
  List<Shop> get featuredShops => _featuredShops;
  Shop? get selectedShop => _selectedShop;
  ShopType? get selectedType => _selectedType;
  ServiceCategory? get selectedService => _selectedService;
  String? get selectedPrefecture => _selectedPrefecture;
  List<Inquiry> get userInquiries => _userInquiries;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
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

  /// 全状態をリセットする（ログアウト時など）
  void clear() {
    _shops = [];
    _featuredShops = [];
    _selectedShop = null;
    _userInquiries = [];
    _selectedType = null;
    _selectedService = null;
    _selectedPrefecture = null;
    _isLoading = false;
    _isSubmitting = false;
    _error = null;
    notifyListeners();
  }
}
