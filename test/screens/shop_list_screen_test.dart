// ShopListScreen Widget Tests

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/screens/marketplace/shop_list_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/shop_case_study.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/utils/shop_map_utils.dart';
import 'package:trust_car_platform/screens/marketplace/nearby_shops_map_screen.dart';

import '../golden/font_loader.dart';

// ---------------------------------------------------------------------------
// Mock ShopService
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  Result<List<Shop>, AppError> shopsResult = const Result.success([]);
  Result<Shop, AppError>? shopDetailResult;
  int getShopsCallCount = 0;
  ShopType? lastType;
  ServiceCategory? lastService;
  String? lastPrefecture;

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
    return shopsResult;
  }

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops(
          {int limit = 5}) async =>
      const Result.success([]);

  @override
  Future<Result<Shop, AppError>> getShop(String shopId) async =>
      shopDetailResult ??
      Result.failure(AppError.notFound('Not found', resourceType: '工場'));

  @override
  Future<Result<List<Shop>, AppError>> searchShops(String query,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsForMaker(String makerId,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getNearbyShops(
          dynamic center, double radiusKm,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsByService(
          ServiceCategory category,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<Shop, AppError>> createMyShop(Shop shop) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<Shop, AppError>> updateMyShop(Shop shop) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<Shop?, AppError>> getMyShop(String uid) async =>
      const Result.success(null);

  @override
  Stream<Map<String, int>> watchInquiryCount(String shopId) =>
      Stream.value(const {'total': 0, 'unread': 0});

  @override
  Future<Result<Map<String, int>, AppError>> getInquiryCount(
          String shopId) async =>
      const Result.success({'total': 0, 'unread': 0});

  @override
  Future<Result<void, AppError>> deleteMyShop(String uid) async =>
      const Result.success(null);

  @override
  Future<Result<List<ShopCaseStudy>, AppError>> getCaseStudies(
          String shopId) async =>
      const Result.success([]);

  @override
  Future<Result<ShopCaseStudy, AppError>> addCaseStudy(
          ShopCaseStudy study) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> deleteCaseStudy(
          String shopId, String studyId) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> uploadCaseStudyImage(
          String shopId, dynamic image, String type) async =>
      Result.failure(AppError.unknown('not impl'));
}

// ---------------------------------------------------------------------------
// Mock InquiryService
// ---------------------------------------------------------------------------

class MockInquiryService implements InquiryService {
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
    String? shopName,
  }) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<Inquiry, AppError>> getInquiry(String inquiryId) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<List<Inquiry>, AppError>> getUserInquiries(String userId,
          {dynamic status, int limit = 20, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Inquiry>, AppError>> getShopInquiries(String shopId,
          {dynamic status, int limit = 20, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<InquiryMessage, AppError>> sendMessage({
    required String inquiryId,
    required String senderId,
    required bool isFromShop,
    required String content,
    List<String> attachmentUrls = const [],
    Map<String, dynamic>? maintenancePayload,
  }) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<List<InquiryMessage>, AppError>> getMessages(String inquiryId,
          {int limit = 50, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<void, AppError>> markAsRead(
          {required String inquiryId, required bool isUser}) async =>
      const Result.success(null);

  @override
  Future<Result<Inquiry, AppError>> updateStatus(
          String inquiryId, dynamic status) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<int, AppError>> getUnreadCountForUser(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<int, AppError>> countUserInquiriesThisMonth(
          String userId) async =>
      const Result.success(0);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) =>
      const Stream.empty();

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      const Stream.empty();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 'shop1',
  String name = 'テストモータース',
  ShopType type = ShopType.maintenanceShop,
  String prefecture = '東京都',
  double? rating = 4.5,
  int reviewCount = 100,
  bool isVerified = true,
  bool isFeatured = false,
  bool isActive = true,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: type,
    isActive: isActive,
    isVerified: isVerified,
    isFeatured: isFeatured,
    prefecture: prefecture,
    services: [ServiceCategory.maintenance, ServiceCategory.inspection],
    supportedMakerIds: [],
    imageUrls: [],
    businessHours: {},
    reviewCount: reviewCount,
    rating: rating,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(ShopProvider provider, {ThemeData? theme}) {
  return ChangeNotifierProvider<ShopProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const ShopListScreen(),
    ),
  );
}

ShopProvider _makeProvider(MockShopService shopService) {
  return ShopProvider(
    shopService: shopService,
    inquiryService: MockInquiryService(),
  );
}

// ---------------------------------------------------------------------------
// 地図（Issue #43）用ヘルパー
// ---------------------------------------------------------------------------

/// GoogleMap の代わりに置く地図。受け取ったものを記録し、ピンをボタンで並べる。
class _FakeMap {
  ShopMapViewData? last;

  Widget build(BuildContext context, ShopMapViewData data) {
    last = data;
    return ListView(
      key: const Key('fake_map'),
      children: [
        for (final pin in data.pins)
          TextButton(
            key: Key('fake_pin_${pin.shopId}'),
            onPressed: () => data.onPinTap(pin),
            child: Text('${pin.shopId}:${pin.category.name}'),
          ),
      ],
    );
  }
}

Widget _buildMapApp(
  ShopProvider provider, {
  required _FakeMap fakeMap,
  bool mapsConfigured = true,
  bool embedded = false,
  bool selectMode = false,
  bool compareMode = false,
}) {
  return ChangeNotifierProvider<ShopProvider>.value(
    value: provider,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: embedded
          ? Scaffold(
              body: ShopListScreen(
                embedded: true,
                mapsConfigured: mapsConfigured,
                mapViewBuilder: fakeMap.build,
              ),
            )
          : ShopListScreen(
              selectMode: selectMode,
              compareMode: compareMode,
              mapsConfigured: mapsConfigured,
              mapViewBuilder: fakeMap.build,
            ),
    ),
  );
}

Shop _partnerAt(String id, double lat, double lng,
        {bool isVerified = true, bool isFeatured = false}) =>
    _makeShop(
            id: id,
            name: '提携$id',
            isVerified: isVerified,
            isFeatured: isFeatured)
        .copyWith(
      location: GeoPoint(lat, lng),
      subscriptionStatus: ShopSubscriptionStatus.active,
    );

Shop _nonPartnerAt(String id, double lat, double lng) =>
    _makeShop(id: id, name: '一般$id', isVerified: false).copyWith(
      location: GeoPoint(lat, lng),
      subscriptionStatus: ShopSubscriptionStatus.free,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // 見え方を画像に残す。CI では走らない（tags: 'golden'）。
  group('ゴールデン', () {
    setUpAll(() async {
      await loadMaterialIcons();
      await loadJapaneseFont();
    });

    Future<void> shoot(WidgetTester tester, String name, ThemeData base) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp(_makeProvider(MockShopService()), theme: goldenTheme(base)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../golden/goldens/$name.png'),
      );
    }

    testWidgets('工場一覧（ライト）', (tester) async {
      await shoot(tester, 'screen_shop_list_light', AppTheme.lightTheme);
    }, tags: 'golden');

    testWidgets('工場一覧（ダーク）', (tester) async {
      await shoot(tester, 'screen_shop_list_dark', AppTheme.darkTheme);
    }, tags: 'golden');
  });

  group('ShopListScreen', () {
    late MockShopService mockShop;
    late ShopProvider provider;

    setUp(() {
      mockShop = MockShopService();
      provider = _makeProvider(mockShop);
    });

    testWidgets('ショップが0件のとき空状態が表示される', (tester) async {
      mockShop.shopsResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('整備工場・業者が見つかりません'), findsOneWidget);
    });

    testWidgets('ショップリストが正常に表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(id: 's1', name: 'ガレージA'),
        _makeShop(id: 's2', name: 'ガレージB'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('ガレージA'), findsOneWidget);
      expect(find.text('ガレージB'), findsOneWidget);
    });

    testWidgets('件数テキストが表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(id: 's1'),
        _makeShop(id: 's2'),
        _makeShop(id: 's3'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('エラー時にエラーUIが表示される', (tester) async {
      mockShop.shopsResult =
          Result.failure(AppError.network('connection failed'));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // エラー状態のUI（リトライボタンなど）が存在する
      expect(find.byIcon(Icons.refresh), findsWidgets);
    });

    testWidgets('検索バーが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('フィルタ行のDropdownChipが3つ表示される', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 業種・サービス・地域の3ラベルが存在する
      expect(find.text('業種'), findsOneWidget);
      expect(find.text('サービス'), findsOneWidget);
      expect(find.text('地域'), findsOneWidget);
    });

    testWidgets('検索テキスト入力でclearアイコンが出現する', (tester) async {
      mockShop.shopsResult = const Result.success([]);
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextField), 'トヨタ');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clearアイコンタップで検索テキストがクリアされる', (tester) async {
      mockShop.shopsResult = const Result.success([]);
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextField), 'テスト');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('認証済みショップに認証バッジが表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(name: '認証ショップ', isVerified: true),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('注目ショップに「広告」ラベルが表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(name: 'スポンサー店', isFeatured: true, isVerified: false),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('広告'), findsOneWidget);
    });

    testWidgets('認証済みかつ注目ショップは認証バッジと「広告」ラベルの両方を表示する', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(name: '認証スポンサー店', isFeatured: true, isVerified: true),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 透明性原則: 有料掲載は認証済みでも必ず「広告」と明示する
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('広告'), findsOneWidget);
    });

    group('Edge Cases', () {
      testWidgets('ショップ名が非常に長くてもクラッシュしない', (tester) async {
        mockShop.shopsResult = Result.success([
          _makeShop(name: 'あ' * 50),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      });

      testWidgets('評価なし（rating: null）でもクラッシュしない', (tester) async {
        mockShop.shopsResult = Result.success([
          _makeShop(rating: null),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      });

      testWidgets('多数のショップ（20件）でもスクロール可能', (tester) async {
        mockShop.shopsResult = Result.success(
          List.generate(
            20,
            (i) => _makeShop(id: 'shop_$i', name: 'ショップ$i'),
          ),
        );

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.byType(ListView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('地図（Issue #43）', () {
    late MockShopService mockShop;
    late ShopProvider provider;
    late _FakeMap fakeMap;

    // 東京駅 / 横浜駅 / 大阪駅
    final tokyo = _partnerAt('tokyo', 35.681, 139.767);
    final yokohama = _nonPartnerAt('yokohama', 35.466, 139.622);
    final osaka = _partnerAt('osaka', 34.702, 135.495, isFeatured: true);

    setUp(() {
      mockShop = MockShopService();
      provider = _makeProvider(mockShop);
      fakeMap = _FakeMap();
    });

    Future<void> pumpList(WidgetTester tester, Widget app) async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
    }

    /// geolocator のチャネルを「失敗する端末」に差し替え、呼ばれたメソッドを記録する。
    ///
    /// 差し替えないとテスト環境では MissingPluginException が実時間で返り、
    /// 負荷が高いと待ち時間が足りずに不安定になる（2026-10-01 に一度落ちた）。
    List<String> mockGeolocatorFailure(WidgetTester tester) {
      final calls = <String>[];
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        throw PlatformException(code: 'LOCATION_UNAVAILABLE');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      return calls;
    }

    Future<void> openMap(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('toggle_map_button')));
      await tester.pumpAndSettle();
    }

    group('キーが無いとき', () {
      testWidgets('地図ボタンを出さず、リストのまま', (tester) async {
        mockShop.shopsResult = Result.success([tokyo, yokohama]);
        await pumpList(
          tester,
          _buildMapApp(provider, fakeMap: fakeMap, mapsConfigured: false),
        );

        expect(find.byKey(const Key('toggle_map_button')), findsNothing);
        expect(find.byKey(const Key('fake_map')), findsNothing);
        expect(find.text('提携tokyo'), findsOneWidget);
      });

      testWidgets('埋め込み表示でも地図ボタンを出さない', (tester) async {
        mockShop.shopsResult = Result.success([tokyo]);
        await pumpList(
          tester,
          _buildMapApp(provider,
              fakeMap: fakeMap, mapsConfigured: false, embedded: true),
        );

        expect(
            find.byKey(const Key('toggle_map_button_embedded')), findsNothing);
        expect(find.text('提携tokyo'), findsOneWidget);
      });

      testWidgets('既定（MapsConfig）ではテスト環境にキーが無いので地図ボタンが無い', (tester) async {
        mockShop.shopsResult = Result.success([tokyo]);
        await pumpList(tester, _buildApp(provider));

        expect(find.byKey(const Key('toggle_map_button')), findsNothing);
      });

      testWidgets('近い順に並べるとリストが距離順になる', (tester) async {
        mockShop.shopsResult = Result.success([osaka, yokohama, tokyo]);
        await pumpList(
          tester,
          _buildMapApp(provider, fakeMap: fakeMap, mapsConfigured: false),
        );

        // 現在地の取得は実機の権限に依存するので、Provider に直接渡す。
        provider.sortByDistanceFrom(35.681, 139.767);
        await tester.pumpAndSettle();

        final dy = [
          tester.getTopLeft(find.text('提携tokyo')).dy,
          tester.getTopLeft(find.text('一般yokohama')).dy,
          tester.getTopLeft(find.text('提携osaka')).dy,
        ];
        expect(dy[0], lessThan(dy[1]));
        expect(dy[1], lessThan(dy[2]));
        expect(find.textContaining('現在地から0.0km'), findsOneWidget);
      });
    });

    group('キーがあるとき', () {
      testWidgets('地図に切り替えると提携・非提携のピンが出し分けられる', (tester) async {
        mockShop.shopsResult = Result.success([tokyo, yokohama]);
        await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
        provider.sortByDistanceFrom(35.681, 139.767);
        await openMap(tester);

        expect(find.byKey(const Key('fake_map')), findsOneWidget);
        expect(find.text('tokyo:partner'), findsOneWidget);
        expect(find.text('yokohama:nonPartner'), findsOneWidget);
        expect(find.byKey(const Key('map_legend')), findsOneWidget);
      });

      testWidgets('現在地があれば地図の中心は現在地、ピンは近い順', (tester) async {
        mockShop.shopsResult = Result.success([osaka, yokohama, tokyo]);
        await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
        provider.sortByDistanceFrom(35.0, 139.0);
        await openMap(tester);

        final data = fakeMap.last!;
        expect(data.center.latitude, 35.0);
        expect(data.center.longitude, 139.0);
        expect(data.hasUserLocation, isTrue);
        expect(data.pins.map((p) => p.shopId), ['yokohama', 'tokyo', 'osaka']);
      });

      testWidgets('リストへ戻れる', (tester) async {
        mockShop.shopsResult = Result.success([tokyo]);
        await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
        provider.sortByDistanceFrom(35.681, 139.767);
        await openMap(tester);
        await openMap(tester); // もう一度押すとリスト

        expect(find.byKey(const Key('fake_map')), findsNothing);
        expect(find.text('提携tokyo'), findsOneWidget);
      });

      testWidgets('埋め込み表示でも地図からリストへ戻れる', (tester) async {
        mockShop.shopsResult = Result.success([tokyo]);
        await pumpList(
          tester,
          _buildMapApp(provider, fakeMap: fakeMap, embedded: true),
        );
        provider.sortByDistanceFrom(35.681, 139.767);
        await tester.pumpAndSettle();

        final toggle = find.byKey(const Key('toggle_map_button_embedded'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake_map')), findsOneWidget);
        // 以前は地図表示中に切替ボタンが消え、戻れなかった。
        expect(toggle, findsOneWidget);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake_map')), findsNothing);
        expect(find.text('提携tokyo'), findsOneWidget);
      });

      testWidgets('選択モード・比較モードでは地図ボタンを出さない', (tester) async {
        mockShop.shopsResult = Result.success([tokyo]);
        await pumpList(
          tester,
          _buildMapApp(provider, fakeMap: fakeMap, selectMode: true),
        );
        expect(find.byKey(const Key('toggle_map_button')), findsNothing);

        await pumpList(
          tester,
          _buildMapApp(provider, fakeMap: fakeMap, compareMode: true),
        );
        expect(find.byKey(const Key('toggle_map_button')), findsNothing);
      });

      testWidgets('提携ピンをタップすると審査済・広告・距離と詳細ボタンが出る', (tester) async {
        mockShop.shopsResult = Result.success([osaka]);
        await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
        provider.sortByDistanceFrom(34.702, 135.495);
        await openMap(tester);

        await tester.tap(find.byKey(const Key('fake_pin_osaka')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('verified_badge')), findsOneWidget);
        expect(find.byKey(const Key('featured_badge')), findsOneWidget);
        expect(find.byKey(const Key('sheet_distance')), findsOneWidget);
        expect(find.byKey(const Key('view_detail_button')), findsOneWidget);
        expect(find.byKey(const Key('non_partner_badge')), findsNothing);
      });

      testWidgets('非提携ピンをタップすると「参考（未審査）」で、詳細ボタンは出ない', (tester) async {
        mockShop.shopsResult = Result.success([yokohama]);
        await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
        provider.sortByDistanceFrom(35.681, 139.767);
        await openMap(tester);

        await tester.tap(find.byKey(const Key('fake_pin_yokohama')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('non_partner_badge')), findsOneWidget);
        expect(find.byKey(const Key('non_partner_inquiry_prompt')),
            findsOneWidget);
        expect(find.byKey(const Key('view_detail_button')), findsNothing);
        expect(find.byKey(const Key('verified_badge')), findsNothing);
      });

      group('Edge Cases', () {
        testWidgets('現在地が取れなくても地図は出て、提携店を中心にする', (tester) async {
          // 位置情報の取得に失敗する端末（チャネルを差し替えて再現）。
          final calls = mockGeolocatorFailure(tester);
          mockShop.shopsResult = Result.success([yokohama, osaka]);
          await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
          await openMap(tester);

          expect(calls, isNotEmpty);
          expect(find.byKey(const Key('fake_map')), findsOneWidget);
          expect(find.text('現在地の取得に失敗しました'), findsOneWidget);
          final data = fakeMap.last!;
          expect(data.hasUserLocation, isFalse);
          expect(data.center.latitude, 34.702); // 先頭の提携店（大阪）
        });

        testWidgets('位置のある店が0件なら案内を出す', (tester) async {
          mockShop.shopsResult = Result.success([_makeShop(id: 'no-loc')]);
          await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
          provider.sortByDistanceFrom(35.681, 139.767);
          await openMap(tester);

          expect(fakeMap.last!.pins, isEmpty);
          expect(find.textContaining('地図に表示できる工場がありません'), findsOneWidget);
        });

        testWidgets('地図表示中に一覧が変わるとピンも変わる', (tester) async {
          mockShop.shopsResult = Result.success([tokyo, yokohama]);
          await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
          provider.sortByDistanceFrom(35.681, 139.767);
          await openMap(tester);
          expect(fakeMap.last!.pins, hasLength(2));

          mockShop.shopsResult = Result.success([tokyo]);
          await provider.loadShops();
          await tester.pumpAndSettle();

          expect(fakeMap.last!.pins.map((p) => p.shopId), ['tokyo']);
        });

        testWidgets('店0件のとき地図に切り替えても位置情報を取りに行かない', (tester) async {
          final calls = mockGeolocatorFailure(tester);
          mockShop.shopsResult = const Result.success([]);
          await pumpList(tester, _buildMapApp(provider, fakeMap: fakeMap));
          await openMap(tester);

          expect(calls, isEmpty);

          expect(find.byKey(const Key('fake_map')), findsOneWidget);
          expect(find.text('現在地の取得に失敗しました'), findsNothing);
          expect(fakeMap.last!.center, ShopMapUtils.defaultCenter);
        });
      });
    });
  });
}
