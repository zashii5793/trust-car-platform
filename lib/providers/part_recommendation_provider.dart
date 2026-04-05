import 'package:flutter/foundation.dart';
import '../models/part_listing.dart';
import '../models/vehicle.dart';
import '../services/part_recommendation_service.dart';
import '../core/constants/pagination.dart';
import '../core/error/app_error.dart';

/// パーツ提案プロバイダー
///
/// 設計思想:
/// - AIは提案する、決めない
/// - 複数候補＋理由（pros/cons）を表示
/// - 「ベスト1」ラベルや順位付けをしない
class PartRecommendationProvider with ChangeNotifier {
  final PartRecommendationService _service;

  PartRecommendationProvider({
    required PartRecommendationService partRecommendationService,
  }) : _service = partRecommendationService;

  List<PartRecommendation> _recommendations = [];
  List<PartListing> _featuredParts = [];
  bool _isLoading = false;
  AppError? _error;
  PartCategory? _selectedCategory;

  List<PartRecommendation> get recommendations => _recommendations;
  List<PartListing> get featuredParts => _featuredParts;
  bool get isLoading => _isLoading;
  AppError? get error => _error;
  String? get errorMessage => _error?.userMessage;
  PartCategory? get selectedCategory => _selectedCategory;

  /// カテゴリフィルタ適用済みの提案リスト
  List<PartRecommendation> get filteredRecommendations {
    if (_selectedCategory == null) return _recommendations;
    return _recommendations
        .where((r) => r.part.category == _selectedCategory)
        .toList();
  }

  /// 指定車両に対するパーツ提案を読み込む
  Future<void> loadRecommendations(
    Vehicle vehicle, {
    PartCategory? category,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _service.getRecommendationsForVehicle(
      vehicle,
      category: category,
      limit: Pagination.defaultPageSize,
    );

    result.when(
      success: (recs) {
        _recommendations = recs;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _recommendations = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// おすすめパーツ（特集）を読み込む
  Future<void> loadFeaturedParts({int limit = 8}) async {
    _isLoading = true;
    notifyListeners();

    final result = await _service.getFeaturedParts(limit: limit);

    result.when(
      success: (parts) {
        _featuredParts = parts;
        _error = null;
      },
      failure: (err) {
        _error = err;
        _featuredParts = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Browse (marketplace general listing) state
  // ---------------------------------------------------------------------------

  List<PartListing> _browseParts = [];
  String _searchQuery = '';

  List<PartListing> get browseParts => _browseParts;
  String get searchQuery => _searchQuery;

  /// マーケットプレイスのパーツ一覧を読み込む（車両指定なし）
  ///
  /// - query 指定時: タグ検索
  /// - category 指定時: カテゴリフィルタ
  /// - 両方 null: おすすめパーツ表示
  Future<void> loadBrowseParts({
    PartCategory? category,
    String? query,
  }) async {
    _isLoading = true;
    _searchQuery = query ?? '';
    notifyListeners();

    if (query != null && query.trim().isNotEmpty) {
      final result = await _service.searchParts(
        query.trim(),
        category: category,
      );
      result.when(
        success: (parts) {
          _browseParts = parts;
          _error = null;
        },
        failure: (err) {
          _error = err;
          _browseParts = [];
        },
      );
    } else if (category != null) {
      final result = await _service.getPartsByCategory(category, limit: Pagination.partsPageSize);
      result.when(
        success: (parts) {
          _browseParts = parts;
          _error = null;
        },
        failure: (err) {
          _error = err;
          _browseParts = [];
        },
      );
    } else {
      final result = await _service.getFeaturedParts(limit: Pagination.defaultPageSize);
      result.when(
        success: (parts) {
          _browseParts = parts;
          _error = null;
        },
        failure: (err) {
          _error = err;
          _browseParts = [];
        },
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  /// カテゴリを選択してフィルタを適用する
  void selectCategory(PartCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// 全状態をリセットする（ログアウト時など）
  void clear() {
    _recommendations = [];
    _featuredParts = [];
    _browseParts = [];
    _currentPartDetail = null;
    _isDetailLoading = false;
    _detailError = null;
    _isLoading = false;
    _error = null;
    _selectedCategory = null;
    _searchQuery = '';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Part Detail state (isolated from list loading state)
  // ---------------------------------------------------------------------------

  PartListing? _currentPartDetail;
  bool _isDetailLoading = false;
  AppError? _detailError;

  PartListing? get currentPartDetail => _currentPartDetail;
  bool get isDetailLoading => _isDetailLoading;
  String? get detailErrorMessage => _detailError?.userMessage;

  /// パーツ詳細を読み込む
  ///
  /// Returns true on success.
  Future<bool> loadPartDetail(String partId) async {
    _isDetailLoading = true;
    _detailError = null;
    _currentPartDetail = null;
    notifyListeners();

    final result = await _service.getPartDetail(partId);

    bool success = false;
    result.when(
      success: (part) {
        _currentPartDetail = part;
        success = true;
      },
      failure: (err) {
        _detailError = err;
      },
    );

    _isDetailLoading = false;
    notifyListeners();
    return success;
  }
}
