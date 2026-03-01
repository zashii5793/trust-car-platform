import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock ShopService
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  Result<List<Shop>, AppError>? shopsResult;
  Result<List<Shop>, AppError>? featuredResult;
  Result<Shop, AppError>? shopResult;
  Result<List<Shop>, AppError>? searchResult;

  // Call tracking
  ShopType? lastType;
  ServiceCategory? lastService;
  String? lastPrefecture;
  String? lastQuery;
  String? lastShopId;
  int getShopsCallCount = 0;

  @override
  Future<Result<Shop, AppError>> getShop(String shopId) async {
    lastShopId = shopId;
    return shopResult ?? Result.failure(AppError.notFound('店舗が見つかりません'));
  }

  @override
  Future<Result<List<Shop>, AppError>> getShops({
    ShopType? type,
    ServiceCategory? serviceCategory,
    String? prefecture,
    int limit = 20,
    dynamic startAfter,
  }) async {
    lastType = type;
    lastService = serviceCategory;
    lastPrefecture = prefecture;
    getShopsCallCount++;
    return shopsResult ?? const Result.success([]);
  }

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops({int limit = 5}) async {
    return featuredResult ?? const Result.success([]);
  }

  @override
  Future<Result<List<Shop>, AppError>> searchShops(
    String query, {
    int limit = 20,
  }) async {
    lastQuery = query;
    return searchResult ?? const Result.success([]);
  }

  @override
  Future<Result<List<Shop>, AppError>> getShopsForMaker(
    String makerId, {
    int limit = 20,
  }) async => const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getNearbyShops(
    dynamic center,
    double radiusKm, {
    int limit = 20,
  }) async => const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsByService(
    ServiceCategory category, {
    int limit = 20,
  }) async => const Result.success([]);
}

// ---------------------------------------------------------------------------
// Mock InquiryService
// ---------------------------------------------------------------------------

class MockInquiryService implements InquiryService {
  Result<Inquiry, AppError>? createResult;
  Result<List<Inquiry>, AppError>? userInquiriesResult;

  // Argument capture
  String? lastUserId;
  String? lastShopId;
  String? lastSubject;
  String? lastMessage;
  InquiryType? lastType;

  @override
  Future<Result<Inquiry, AppError>> createInquiry({
    required String userId,
    required String shopId,
    required InquiryType type,
    required String subject,
    required String message,
    String? vehicleId,
    String? partListingId,
    dynamic vehicle,
    List<String> attachmentUrls = const [],
  }) async {
    lastUserId = userId;
    lastShopId = shopId;
    lastType = type;
    lastSubject = subject;
    lastMessage = message;
    return createResult ?? Result.failure(AppError.server('送信失敗'));
  }

  @override
  Future<Result<List<Inquiry>, AppError>> getUserInquiries(
    String userId, {
    InquiryStatus? status,
    int limit = 20,
    dynamic startAfter,
  }) async {
    lastUserId = userId;
    return userInquiriesResult ?? const Result.success([]);
  }

  // Unused stubs
  @override
  Future<Result<Inquiry, AppError>> getInquiry(String inquiryId) async =>
      Result.failure(AppError.notFound('not found'));

  @override
  Future<Result<List<Inquiry>, AppError>> getShopInquiries(
    String shopId, {
    InquiryStatus? status,
    int limit = 20,
    dynamic startAfter,
  }) async => const Result.success([]);

  @override
  Future<Result<InquiryMessage, AppError>> sendMessage({
    required String inquiryId,
    required String senderId,
    required bool isFromShop,
    required String content,
    List<String> attachmentUrls = const [],
  }) async => Result.failure(AppError.server('not implemented'));

  @override
  Future<Result<List<InquiryMessage>, AppError>> getMessages(
    String inquiryId, {
    int limit = 50,
    dynamic startAfter,
  }) async => const Result.success([]);

  @override
  Future<Result<void, AppError>> markAsRead({
    required String inquiryId,
    required bool isUser,
  }) async => const Result.success(null);

  @override
  Future<Result<Inquiry, AppError>> updateStatus(
    String inquiryId,
    InquiryStatus status,
  ) async => Result.failure(AppError.server('not implemented'));

  @override
  Future<Result<int, AppError>> getUnreadCountForUser(String userId) async =>
      const Result.success(0);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) => const Stream.empty();

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 's1',
  String name = 'テスト工場',
  ShopType type = ShopType.maintenanceShop,
  bool isFeatured = false,
  bool isVerified = false,
  double? rating,
  String? prefecture,
}) =>
    Shop(
      id: id,
      name: name,
      type: type,
      isFeatured: isFeatured,
      isVerified: isVerified,
      rating: rating,
      prefecture: prefecture,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

Inquiry _makeInquiry({
  String id = 'inq1',
  String userId = 'user1',
  String shopId = 's1',
  String subject = 'テスト問い合わせ',
}) =>
    Inquiry(
      id: id,
      userId: userId,
      shopId: shopId,
      type: InquiryType.estimate,
      subject: subject,
      initialMessage: '問い合わせ内容',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopProvider', () {
    late MockShopService mockShopService;
    late MockInquiryService mockInquiryService;
    late ShopProvider provider;

    setUp(() {
      mockShopService = MockShopService();
      mockInquiryService = MockInquiryService();
      provider = ShopProvider(
        shopService: mockShopService,
        inquiryService: mockInquiryService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    // -----------------------------------------------------------------------
    // Initial State
    // -----------------------------------------------------------------------

    group('Initial State', () {
      test('shops is empty on init', () {
        expect(provider.shops, isEmpty);
      });

      test('featuredShops is empty on init', () {
        expect(provider.featuredShops, isEmpty);
      });

      test('selectedShop is null on init', () {
        expect(provider.selectedShop, isNull);
      });

      test('isLoading is false on init', () {
        expect(provider.isLoading, isFalse);
      });

      test('error is null on init', () {
        expect(provider.error, isNull);
      });

      test('filter fields are null on init', () {
        expect(provider.selectedType, isNull);
        expect(provider.selectedService, isNull);
        expect(provider.selectedPrefecture, isNull);
      });

      test('userInquiries is empty on init', () {
        expect(provider.userInquiries, isEmpty);
      });

      test('isSubmitting is false on init', () {
        expect(provider.isSubmitting, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // loadShops
    // -----------------------------------------------------------------------

    group('loadShops', () {
      test('sets isLoading=true then false after completion', () async {
        final loading = <bool>[];
        provider.addListener(() => loading.add(provider.isLoading));

        await provider.loadShops();

        expect(loading, contains(true));
        expect(provider.isLoading, isFalse);
      });

      test('populates shops on success', () async {
        mockShopService.shopsResult = Result.success([
          _makeShop(id: 's1'),
          _makeShop(id: 's2'),
        ]);

        await provider.loadShops();

        expect(provider.shops.length, 2);
        expect(provider.error, isNull);
      });

      test('sets error on failure', () async {
        mockShopService.shopsResult =
            Result.failure(AppError.server('接続エラー'));

        await provider.loadShops();

        expect(provider.error, isNotNull);
        expect(provider.shops, isEmpty);
      });

      test('clears error on subsequent successful load', () async {
        mockShopService.shopsResult = Result.failure(AppError.server('err'));
        await provider.loadShops();
        expect(provider.error, isNotNull);

        mockShopService.shopsResult = const Result.success([]);
        await provider.loadShops();
        expect(provider.error, isNull);
      });

      test('passes type filter to service', () async {
        provider.selectType(ShopType.dealer);
        mockShopService.lastType = null;

        await provider.loadShops();

        expect(mockShopService.lastType, ShopType.dealer);
      });

      test('passes service filter to service', () async {
        provider.selectService(ServiceCategory.inspection);
        mockShopService.lastService = null;

        await provider.loadShops();

        expect(mockShopService.lastService, ServiceCategory.inspection);
      });

      test('passes prefecture filter to service', () async {
        provider.selectPrefecture('東京都');
        mockShopService.lastPrefecture = null;

        await provider.loadShops();

        expect(mockShopService.lastPrefecture, '東京都');
      });
    });

    // -----------------------------------------------------------------------
    // loadFeaturedShops
    // -----------------------------------------------------------------------

    group('loadFeaturedShops', () {
      test('populates featuredShops on success', () async {
        mockShopService.featuredResult = Result.success([
          _makeShop(id: 'fs1', isFeatured: true),
          _makeShop(id: 'fs2', isFeatured: true),
        ]);

        await provider.loadFeaturedShops();

        expect(provider.featuredShops.length, 2);
        expect(provider.error, isNull);
      });

      test('sets error on failure', () async {
        mockShopService.featuredResult =
            Result.failure(AppError.server('接続エラー'));

        await provider.loadFeaturedShops();

        expect(provider.error, isNotNull);
      });

      test('featuredShops is empty on failure', () async {
        mockShopService.featuredResult =
            Result.failure(AppError.server('err'));

        await provider.loadFeaturedShops();

        expect(provider.featuredShops, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // loadShop
    // -----------------------------------------------------------------------

    group('loadShop', () {
      test('sets selectedShop on success', () async {
        mockShopService.shopResult = Result.success(_makeShop(id: 's1'));

        await provider.loadShop('s1');

        expect(provider.selectedShop, isNotNull);
        expect(provider.selectedShop!.id, 's1');
      });

      test('selectedShop is null if shop not found', () async {
        mockShopService.shopResult =
            Result.failure(AppError.notFound('見つかりません'));

        await provider.loadShop('nonexistent');

        expect(provider.selectedShop, isNull);
        expect(provider.error, isNotNull);
      });

      test('sets error when service fails', () async {
        mockShopService.shopResult =
            Result.failure(AppError.server('サーバーエラー'));

        await provider.loadShop('s1');

        expect(provider.error, isNotNull);
      });

      test('passes shopId to service', () async {
        await provider.loadShop('target-shop-id');

        expect(mockShopService.lastShopId, 'target-shop-id');
      });
    });

    // -----------------------------------------------------------------------
    // searchShops
    // -----------------------------------------------------------------------

    group('searchShops', () {
      test('passes query to service', () async {
        mockShopService.searchResult = const Result.success([]);

        await provider.searchShops('トヨタ');

        expect(mockShopService.lastQuery, 'トヨタ');
      });

      test('populates shops on success', () async {
        mockShopService.searchResult = Result.success([
          _makeShop(id: 's1', name: 'トヨタ販売店'),
        ]);

        await provider.searchShops('トヨタ');

        expect(provider.shops.length, 1);
        expect(provider.shops.first.name, 'トヨタ販売店');
      });

      test('falls back to loadShops when query is empty string', () async {
        mockShopService.shopsResult = Result.success([
          _makeShop(id: 's1'),
          _makeShop(id: 's2'),
        ]);
        mockShopService.getShopsCallCount = 0;

        await provider.searchShops('');

        expect(mockShopService.getShopsCallCount, greaterThan(0));
        expect(mockShopService.lastQuery, isNull);
      });

      test('clears previous results on new search', () async {
        mockShopService.searchResult = Result.success([_makeShop(id: 's1')]);
        await provider.searchShops('first');
        expect(provider.shops.length, 1);

        mockShopService.searchResult = const Result.success([]);
        await provider.searchShops('second');
        expect(provider.shops, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // Filter operations
    // -----------------------------------------------------------------------

    group('フィルタ操作', () {
      test('selectType updates selectedType', () {
        provider.selectType(ShopType.dealer);
        expect(provider.selectedType, ShopType.dealer);
      });

      test('selectService updates selectedService', () {
        provider.selectService(ServiceCategory.inspection);
        expect(provider.selectedService, ServiceCategory.inspection);
      });

      test('selectPrefecture updates selectedPrefecture', () {
        provider.selectPrefecture('大阪府');
        expect(provider.selectedPrefecture, '大阪府');
      });

      test('clearFilters resets all filter fields', () {
        provider.selectType(ShopType.dealer);
        provider.selectService(ServiceCategory.inspection);
        provider.selectPrefecture('東京都');

        provider.clearFilters();

        expect(provider.selectedType, isNull);
        expect(provider.selectedService, isNull);
        expect(provider.selectedPrefecture, isNull);
      });

      test('selectType with null clears type filter', () {
        provider.selectType(ShopType.dealer);
        provider.selectType(null);
        expect(provider.selectedType, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // submitInquiry
    // -----------------------------------------------------------------------

    group('submitInquiry', () {
      test('sets isSubmitting=true then false', () async {
        final submitting = <bool>[];
        mockInquiryService.createResult = Result.success(_makeInquiry());
        provider.addListener(() => submitting.add(provider.isSubmitting));

        await provider.submitInquiry(
          userId: 'user1',
          shopId: 's1',
          type: InquiryType.estimate,
          subject: '見積り',
          message: '車検の見積りをお願いします',
        );

        expect(submitting, contains(true));
        expect(provider.isSubmitting, isFalse);
      });

      test('returns created inquiry on success', () async {
        mockInquiryService.createResult = Result.success(_makeInquiry(id: 'new-inq'));

        final result = await provider.submitInquiry(
          userId: 'user1',
          shopId: 's1',
          type: InquiryType.estimate,
          subject: '見積り',
          message: '依頼内容',
        );

        expect(result, isNotNull);
        expect(result!.id, 'new-inq');
        expect(provider.error, isNull);
      });

      test('sets error on failure', () async {
        mockInquiryService.createResult =
            Result.failure(AppError.server('送信失敗'));

        final result = await provider.submitInquiry(
          userId: 'user1',
          shopId: 's1',
          type: InquiryType.estimate,
          subject: '件名',
          message: '本文',
        );

        expect(result, isNull);
        expect(provider.error, isNotNull);
      });

      test('passes correct arguments to InquiryService', () async {
        mockInquiryService.createResult = Result.success(_makeInquiry());

        await provider.submitInquiry(
          userId: 'user-abc',
          shopId: 'shop-xyz',
          type: InquiryType.appointment,
          subject: 'テスト件名',
          message: 'テスト本文',
        );

        expect(mockInquiryService.lastUserId, 'user-abc');
        expect(mockInquiryService.lastShopId, 'shop-xyz');
        expect(mockInquiryService.lastType, InquiryType.appointment);
        expect(mockInquiryService.lastSubject, 'テスト件名');
        expect(mockInquiryService.lastMessage, 'テスト本文');
      });
    });

    // -----------------------------------------------------------------------
    // loadUserInquiries
    // -----------------------------------------------------------------------

    group('loadUserInquiries', () {
      test('populates userInquiries on success', () async {
        mockInquiryService.userInquiriesResult = Result.success([
          _makeInquiry(id: 'i1'),
          _makeInquiry(id: 'i2'),
        ]);

        await provider.loadUserInquiries('user1');

        expect(provider.userInquiries.length, 2);
        expect(provider.error, isNull);
      });

      test('sets error on failure', () async {
        mockInquiryService.userInquiriesResult =
            Result.failure(AppError.server('取得失敗'));

        await provider.loadUserInquiries('user1');

        expect(provider.error, isNotNull);
      });

      test('passes userId to service correctly', () async {
        mockInquiryService.lastUserId = null;

        await provider.loadUserInquiries('target-user');

        expect(mockInquiryService.lastUserId, 'target-user');
      });
    });

    // -----------------------------------------------------------------------
    // clear
    // -----------------------------------------------------------------------

    group('clear', () {
      test('resets all state', () async {
        mockShopService.shopsResult =
            Result.success([_makeShop(id: 's1')]);
        mockShopService.featuredResult =
            Result.success([_makeShop(id: 'fs1', isFeatured: true)]);
        mockShopService.shopResult = Result.success(_makeShop(id: 's1'));
        mockInquiryService.userInquiriesResult =
            Result.success([_makeInquiry()]);

        await provider.loadShops();
        await provider.loadFeaturedShops();
        await provider.loadShop('s1');
        await provider.loadUserInquiries('user1');
        provider.selectType(ShopType.dealer);
        provider.selectService(ServiceCategory.inspection);
        provider.selectPrefecture('東京都');

        provider.clear();

        expect(provider.shops, isEmpty);
        expect(provider.featuredShops, isEmpty);
        expect(provider.selectedShop, isNull);
        expect(provider.userInquiries, isEmpty);
        expect(provider.selectedType, isNull);
        expect(provider.selectedService, isNull);
        expect(provider.selectedPrefecture, isNull);
        expect(provider.error, isNull);
        expect(provider.isLoading, isFalse);
        expect(provider.isSubmitting, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Edge Cases
    // -----------------------------------------------------------------------

    group('Edge Cases', () {
      test('concurrent loadShops calls do not corrupt state', () async {
        mockShopService.shopsResult = Result.success([_makeShop(id: 's1')]);

        final f1 = provider.loadShops();
        final f2 = provider.loadShops();
        await Future.wait([f1, f2]);

        expect(provider.isLoading, isFalse);
      });

      test('searchShops with 10000-char query still calls service', () async {
        final longQuery = 'あ' * 10000;
        mockShopService.searchResult = const Result.success([]);

        await provider.searchShops(longQuery);

        expect(mockShopService.lastQuery, longQuery);
      });

      test('submitInquiry with empty subject sets error', () async {
        mockInquiryService.createResult =
            Result.failure(AppError.validation('件名は必須です'));

        final result = await provider.submitInquiry(
          userId: 'u1',
          shopId: 's1',
          type: InquiryType.general,
          subject: '',
          message: '本文',
        );

        expect(result, isNull);
        expect(provider.error, isNotNull);
      });

      test('loadShop with non-existent ID returns notFound error', () async {
        mockShopService.shopResult =
            Result.failure(AppError.notFound('見つかりません'));

        await provider.loadShop('does-not-exist');

        expect(provider.error, isNotNull);
        expect(provider.selectedShop, isNull);
      });

      test('clearFilters notifies listeners', () {
        bool notified = false;
        provider.selectType(ShopType.dealer);
        provider.addListener(() => notified = true);

        provider.clearFilters();

        expect(notified, isTrue);
      });
    });
  });
}
