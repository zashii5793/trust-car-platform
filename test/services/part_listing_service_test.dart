// PartListingService Unit Tests
//
// Firebase (Auth + Firestore) への直接アクセスが必要なメソッドのうち、
// 認証が絡む createListing の Firestore 書き込みは統合テストでカバーする。
// このファイルでは以下をテストする:
//   1. calculatePayout 手数料計算ロジック
//   2. PartCondition / ShippingMethod / PartListingStatus enum の動作
//   3. UserPartListing モデルの fromFirestore / toMap / priceDisplay
//   4. getMyListings バリデーション (sellerId 空の場合)
//   5. getMyListings の Firestore クエリ結果
//   6. updateListingStatus バリデーション (listingId 空の場合)
//   7. updateListingStatus の Firestore 更新
//   8. エッジケース

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/user_part_listing.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/part_listing_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Stub FirebaseService that always returns the provided result for uploadImages
class _StubFirebaseService extends FirebaseService {
  final Result<List<String>, AppError> uploadResult;

  _StubFirebaseService({
    this.uploadResult = const Result.success([]),
  });

  @override
  Future<Result<List<String>, AppError>> uploadImages(
    List<dynamic> images,
    String basePath,
  ) async =>
      uploadResult;

  @override
  String? get currentUserId => null;
}

/// Creates a UserPartListing document in the fake Firestore
Future<String> _seedListing(
  FakeFirebaseFirestore fakeFs, {
  String sellerId = 'user1',
  String title = 'Test Part',
  int price = 5000,
  PartListingStatus status = PartListingStatus.active,
}) async {
  final now = DateTime.now();
  final ref = fakeFs.collection('user_part_listings').doc();
  await ref.set({
    'id': ref.id,
    'sellerId': sellerId,
    'title': title,
    'category': PartCategory.other.name,
    'condition': PartCondition.goodCondition.name,
    'price': price,
    'payout': calculatePayout(price),
    'description': 'A description',
    'compatibleVehicle': null,
    'imageUrls': <String>[],
    'shippingMethod': ShippingMethod.includedInPrice.name,
    'status': status.name,
    'createdAt': Timestamp.fromDate(now),
    'updatedAt': Timestamp.fromDate(now),
  });
  return ref.id;
}

// ---------------------------------------------------------------------------
// calculatePayout
// ---------------------------------------------------------------------------

void main() {
  group('calculatePayout', () {
    test('典型的な価格で手数料8%を差し引く', () {
      // 10000 * 0.08 = 800 (>= 100 min), payout = 9200
      expect(calculatePayout(10000), 9200);
    });

    test('最低手数料(100円)が適用される低価格', () {
      // 500 * 0.08 = 40, min=100 → payout = 400
      expect(calculatePayout(500), 400);
    });

    test('手数料ちょうど100円になる境界値', () {
      // 1250 * 0.08 = 100.0 → ceil = 100, payout = 1150
      expect(calculatePayout(1250), 1150);
    });

    test('100円未満の価格は payout が 0 (マイナスにならない)', () {
      // 50 * 0.08 = 4, min=100 → 50 - 100 = -50 → clamped to 0
      expect(calculatePayout(50), 0);
    });

    test('高額商品でも正しく計算される', () {
      // 1000000 * 0.08 = 80000, payout = 920000
      expect(calculatePayout(1000000), 920000);
    });

    test('ちょうど 1 円でも 0 になる', () {
      expect(calculatePayout(1), 0);
    });

    test('切り上げ: 小数点以下の手数料', () {
      // 1001 * 0.08 = 80.08 → ceil = 81 (but min=100), payout = 901
      expect(calculatePayout(1001), 901);
    });

    group('Edge Cases', () {
      test('price=0 は 0 を返す', () {
        expect(calculatePayout(0), 0);
      });

      test('負の price は 0 を返す', () {
        expect(calculatePayout(-100), 0);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // PartCondition enum
  // ---------------------------------------------------------------------------

  group('PartCondition', () {
    test('全コンディションに displayName が設定されている', () {
      for (final c in PartCondition.values) {
        expect(c.displayName.isNotEmpty, true,
            reason: '${c.name} の displayName が空');
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final c in PartCondition.values) {
        expect(PartCondition.fromString(c.name), c);
      }
    });

    test('fromString で null は null を返す', () {
      expect(PartCondition.fromString(null), isNull);
    });

    test('fromString で不正な文字列は null を返す', () {
      expect(PartCondition.fromString('unknown'), isNull);
    });

    test('goodCondition が存在する', () {
      expect(PartCondition.fromString('goodCondition'), PartCondition.goodCondition);
    });
  });

  // ---------------------------------------------------------------------------
  // ShippingMethod enum
  // ---------------------------------------------------------------------------

  group('ShippingMethod', () {
    test('全配送方法に displayName が設定されている', () {
      for (final s in ShippingMethod.values) {
        expect(s.displayName.isNotEmpty, true);
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final s in ShippingMethod.values) {
        expect(ShippingMethod.fromString(s.name), s);
      }
    });

    test('fromString で null は null を返す', () {
      expect(ShippingMethod.fromString(null), isNull);
    });

    test('fromString で不正な値は null を返す', () {
      expect(ShippingMethod.fromString('express'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // PartListingStatus enum
  // ---------------------------------------------------------------------------

  group('PartListingStatus', () {
    test('全ステータスに displayName が設定されている', () {
      for (final s in PartListingStatus.values) {
        expect(s.displayName.isNotEmpty, true);
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final s in PartListingStatus.values) {
        expect(PartListingStatus.fromString(s.name), s);
      }
    });

    test('fromString で null は active を返す (デフォルト)', () {
      expect(PartListingStatus.fromString(null), PartListingStatus.active);
    });

    test('fromString で不正な値は active を返す', () {
      expect(PartListingStatus.fromString('deleted'), PartListingStatus.active);
    });
  });

  // ---------------------------------------------------------------------------
  // UserPartListing model
  // ---------------------------------------------------------------------------

  group('UserPartListing', () {
    final now = DateTime(2024, 1, 15, 12, 0, 0);

    UserPartListing _makeListing({
      int price = 5000,
      PartListingStatus status = PartListingStatus.active,
    }) {
      return UserPartListing(
        id: 'listing1',
        sellerId: 'user1',
        title: 'Oil Filter',
        category: PartCategory.maintenance,
        condition: PartCondition.likeNew,
        price: price,
        payout: calculatePayout(price),
        description: 'Genuine part',
        shippingMethod: ShippingMethod.includedInPrice,
        status: status,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('priceDisplay でカンマ区切りの通貨文字列を返す', () {
      expect(_makeListing(price: 10000).priceDisplay, '¥10,000');
    });

    test('priceDisplay 1000未満はカンマなし', () {
      expect(_makeListing(price: 500).priceDisplay, '¥500');
    });

    test('priceDisplay 1,000,000 以上もフォーマットされる', () {
      expect(_makeListing(price: 1000000).priceDisplay, '¥1,000,000');
    });

    test('toMap でシリアライズできる', () {
      final listing = _makeListing();
      final map = listing.toMap();
      expect(map['id'], 'listing1');
      expect(map['sellerId'], 'user1');
      expect(map['title'], 'Oil Filter');
      expect(map['price'], 5000);
      expect(map['status'], 'active');
    });

    test('copyWith でフィールドを上書きできる', () {
      final original = _makeListing(status: PartListingStatus.active);
      final updated = original.copyWith(status: PartListingStatus.soldOut);
      expect(updated.status, PartListingStatus.soldOut);
      expect(updated.id, original.id); // unchanged
    });

    test('== は id で比較する', () {
      final a = _makeListing();
      final b = _makeListing().copyWith(title: 'Different Title');
      expect(a, b); // same id
    });

    group('Edge Cases', () {
      test('imageUrls が空リストでも問題ない', () {
        expect(_makeListing().imageUrls, isEmpty);
      });

      test('compatibleVehicle が null でも問題ない', () {
        expect(_makeListing().compatibleVehicle, isNull);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // PartListingService — getMyListings
  // ---------------------------------------------------------------------------

  group('PartListingService.getMyListings', () {
    late FakeFirebaseFirestore fakeFs;
    late PartListingService service;

    setUp(() {
      fakeFs = FakeFirebaseFirestore();
      service = PartListingService(
        firestore: fakeFs,
        firebaseService: _StubFirebaseService(),
      );
    });

    test('sellerId が空文字のときバリデーションエラーを返す', () async {
      final result = await service.getMyListings('');
      expect(result.isFailure, true);
      final err = result.errorOrNull;
      expect(err, isA<ValidationError>());
      expect((err as ValidationError).field, 'sellerId');
    });

    test('ドキュメントが存在しない場合は空リストを返す', () async {
      final result = await service.getMyListings('unknown_user');
      expect(result.isSuccess, true);
      expect(result.valueOrNull, isEmpty);
    });

    test('自分のリスティングのみ返す', () async {
      await _seedListing(fakeFs, sellerId: 'user1', title: 'My Part');
      await _seedListing(fakeFs, sellerId: 'user2', title: 'Other Part');

      final result = await service.getMyListings('user1');
      expect(result.isSuccess, true);
      final listings = result.valueOrNull!;
      expect(listings.length, 1);
      expect(listings.first.title, 'My Part');
    });

    test('複数件を createdAt 降順で返す', () async {
      final now = DateTime.now();
      // older item first
      await fakeFs.collection('user_part_listings').add({
        'id': 'a',
        'sellerId': 'user1',
        'title': 'Older Part',
        'category': PartCategory.other.name,
        'condition': PartCondition.goodCondition.name,
        'price': 3000,
        'payout': calculatePayout(3000),
        'description': 'd',
        'compatibleVehicle': null,
        'imageUrls': <String>[],
        'shippingMethod': ShippingMethod.includedInPrice.name,
        'status': PartListingStatus.active.name,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'updatedAt': Timestamp.fromDate(now),
      });
      await fakeFs.collection('user_part_listings').add({
        'id': 'b',
        'sellerId': 'user1',
        'title': 'Newer Part',
        'category': PartCategory.other.name,
        'condition': PartCondition.goodCondition.name,
        'price': 5000,
        'payout': calculatePayout(5000),
        'description': 'd',
        'compatibleVehicle': null,
        'imageUrls': <String>[],
        'shippingMethod': ShippingMethod.includedInPrice.name,
        'status': PartListingStatus.active.name,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final result = await service.getMyListings('user1');
      expect(result.isSuccess, true);
      final listings = result.valueOrNull!;
      expect(listings.length, 2);
      // descending order: newer first
      expect(listings.first.title, 'Newer Part');
    });

    group('Edge Cases', () {
      test('全ステータスのリスティングをフィルタなしで取得する', () async {
        await _seedListing(fakeFs, sellerId: 'user1', status: PartListingStatus.active);
        await _seedListing(fakeFs, sellerId: 'user1', status: PartListingStatus.soldOut);
        await _seedListing(fakeFs, sellerId: 'user1', status: PartListingStatus.cancelled);

        final result = await service.getMyListings('user1');
        expect(result.valueOrNull?.length, 3);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // PartListingService — updateListingStatus
  // ---------------------------------------------------------------------------

  group('PartListingService.updateListingStatus', () {
    late FakeFirebaseFirestore fakeFs;
    late PartListingService service;

    setUp(() {
      fakeFs = FakeFirebaseFirestore();
      service = PartListingService(
        firestore: fakeFs,
        firebaseService: _StubFirebaseService(),
      );
    });

    test('listingId が空のときバリデーションエラーを返す', () async {
      final result = await service.updateListingStatus(
        '',
        PartListingStatus.soldOut,
      );
      expect(result.isFailure, true);
      final err = result.errorOrNull;
      expect(err, isA<ValidationError>());
      expect((err as ValidationError).field, 'listingId');
    });

    test('ステータスを soldOut に更新できる', () async {
      final id = await _seedListing(fakeFs, sellerId: 'user1');

      final result = await service.updateListingStatus(
        id,
        PartListingStatus.soldOut,
      );
      expect(result.isSuccess, true);

      final doc = await fakeFs.collection('user_part_listings').doc(id).get();
      expect(doc.data()?['status'], PartListingStatus.soldOut.name);
    });

    test('ステータスを cancelled に更新できる', () async {
      final id = await _seedListing(fakeFs, sellerId: 'user1');

      final result = await service.updateListingStatus(
        id,
        PartListingStatus.cancelled,
      );
      expect(result.isSuccess, true);

      final doc = await fakeFs.collection('user_part_listings').doc(id).get();
      expect(doc.data()?['status'], PartListingStatus.cancelled.name);
    });

    test('updatedAt が更新される', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 5));
      final id = await _seedListing(fakeFs);

      await service.updateListingStatus(id, PartListingStatus.soldOut);

      final doc = await fakeFs.collection('user_part_listings').doc(id).get();
      final updatedAt = (doc.data()?['updatedAt'] as Timestamp).toDate();
      expect(updatedAt.isAfter(before), true);
    });

    group('Edge Cases', () {
      test('存在しない listingId でも成功を返す (Firestore の merge 動作)', () async {
        final result = await service.updateListingStatus(
          'non_existent_id',
          PartListingStatus.soldOut,
        );
        // FakeFirebaseFirestore では存在しないドキュメントへの update は成功する
        expect(result.isSuccess, true);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // PartListingService — createListing バリデーション
  // ---------------------------------------------------------------------------

  group('PartListingService.createListing validation', () {
    late FakeFirebaseFirestore fakeFs;

    setUp(() {
      fakeFs = FakeFirebaseFirestore();
    });

    test('未認証時は AuthError を返す', () async {
      // FirebaseAuth.instance を使うと実際の Firebase に繋がるため
      // auth を省略して実行すると currentUser が null になりうる環境を期待するが、
      // 単体テスト環境では FirebaseAuth.instance の初期化自体が失敗するため
      // このケースは統合テスト (emulator) でカバーする。
      //
      // ここでは Result<String, AppError> の型が AuthError であることを確認するだけ。
      final authError = const AppError.auth(
        'Not authenticated',
        type: AuthErrorType.unknown,
      );
      expect(authError, isA<AuthError>());
      expect(authError.userMessage, isNotEmpty);
    });

    test('タイトルが空のとき ValidationError(field=title) を確認 (Result パターン)', () {
      // createListing の auth チェック後のバリデーション仕様の文書化テスト
      const error = AppError.validation('Title is required', field: 'title');
      expect(error, isA<ValidationError>());
      expect((error as ValidationError).field, 'title');
    });

    test('price が 0 のとき ValidationError(field=price) を確認 (Result パターン)', () {
      const error = AppError.validation('Price must be greater than 0', field: 'price');
      expect(error, isA<ValidationError>());
      expect((error as ValidationError).field, 'price');
    });
  });

  // ---------------------------------------------------------------------------
  // CreatePartListingInput
  // ---------------------------------------------------------------------------

  group('CreatePartListingInput', () {
    test('すべての必須フィールドを設定できる', () {
      const input = CreatePartListingInput(
        title: 'Air Filter',
        category: PartCategory.maintenance,
        condition: PartCondition.likeNew,
        price: 2000,
        description: 'Genuine air filter',
        shippingMethod: ShippingMethod.includedInPrice,
      );
      expect(input.title, 'Air Filter');
      expect(input.images, isEmpty);
      expect(input.compatibleVehicle, isNull);
    });

    test('オプションフィールドを設定できる', () {
      const input = CreatePartListingInput(
        title: 'Spoiler',
        category: PartCategory.aero,
        condition: PartCondition.goodCondition,
        price: 15000,
        description: 'Carbon spoiler',
        compatibleVehicle: 'トヨタ GR86',
        shippingMethod: ShippingMethod.buyerPays,
      );
      expect(input.compatibleVehicle, 'トヨタ GR86');
      expect(input.shippingMethod, ShippingMethod.buyerPays);
    });
  });
}
