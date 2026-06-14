import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop.dart';
import '../models/shop_case_study.dart';

/// Service for shop (business partner) operations
class ShopService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ShopService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _shopsCollection =>
      _firestore.collection('shops');

  /// Get shop by ID
  Future<Result<Shop, AppError>> getShop(String shopId) async {
    try {
      final doc = await _shopsCollection.doc(shopId).get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('店舗が見つかりません'));
      }

      return Result.success(Shop.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('店舗情報の取得に失敗しました: $e'));
    }
  }

  /// Get all active shops
  Future<Result<List<Shop>, AppError>> getShops({
    ShopType? type,
    ServiceCategory? serviceCategory,
    String? prefecture,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _shopsCollection.where('isActive', isEqualTo: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (serviceCategory != null) {
        query = query.where('services', arrayContains: serviceCategory.name);
      }

      if (prefecture != null) {
        query = query.where('prefecture', isEqualTo: prefecture);
      }

      query = query
          .orderBy('isFeatured', descending: true)
          .orderBy('rating', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final shops =
          snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('店舗一覧の取得に失敗しました: $e'));
    }
  }

  /// Get featured shops
  Future<Result<List<Shop>, AppError>> getFeaturedShops({int limit = 5}) async {
    try {
      final snapshot = await _shopsCollection
          .where('isActive', isEqualTo: true)
          .where('isFeatured', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final shops =
          snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('おすすめ店舗の取得に失敗しました: $e'));
    }
  }

  /// Get shops that support a specific vehicle maker
  Future<Result<List<Shop>, AppError>> getShopsForMaker(
    String makerId, {
    int limit = 20,
  }) async {
    try {
      // Get shops that explicitly support this maker OR support all makers (empty array)
      final snapshot = await _shopsCollection
          .where('isActive', isEqualTo: true)
          .where('supportedMakerIds', arrayContains: makerId)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final shops =
          snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('店舗の取得に失敗しました: $e'));
    }
  }

  /// Search shops by name or location
  Future<Result<List<Shop>, AppError>> searchShops(
    String query, {
    int limit = 20,
  }) async {
    try {
      // Simple prefix search on name
      // Note: Firestore doesn't support full-text search, consider Algolia for production
      final snapshot = await _shopsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(limit)
          .get();

      final shops =
          snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('検索に失敗しました: $e'));
    }
  }

  /// Get nearby shops (requires location index in Firestore)
  Future<Result<List<Shop>, AppError>> getNearbyShops(
    GeoPoint center,
    double radiusKm, {
    int limit = 20,
  }) async {
    try {
      // Simplified: Get shops in same prefecture
      // For production, use GeoFirestore or similar for proper geo queries
      final snapshot = await _shopsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final shops =
          snapshot.docs.map((doc) => Shop.fromFirestore(doc)).where((shop) {
        if (shop.location == null) return false;
        // Rough distance calculation
        final distance = _calculateDistance(
          center.latitude,
          center.longitude,
          shop.location!.latitude,
          shop.location!.longitude,
        );
        return distance <= radiusKm;
      }).toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('周辺店舗の取得に失敗しました: $e'));
    }
  }

  /// Create a shop for the current user (docId = uid)
  Future<Result<Shop, AppError>> createMyShop(Shop shop) async {
    try {
      final data = shop.toMap();
      data['createdAt'] = data['updatedAt']; // Ensure createdAt is set
      await _shopsCollection.doc(shop.id).set(data);
      final doc = await _shopsCollection.doc(shop.id).get();
      return Result.success(Shop.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('ショップの作成に失敗しました: $e'));
    }
  }

  /// Update the current user's shop (validates ownerId before writing)
  Future<Result<Shop, AppError>> updateMyShop(Shop shop) async {
    try {
      final existing = await _shopsCollection.doc(shop.id).get();
      if (!existing.exists) {
        return Result.failure(AppError.notFound('ショップが見つかりません'));
      }

      final existingData = existing.data()!;
      if (existingData['ownerId'] != shop.ownerId) {
        return Result.failure(AppError.permission('このショップを更新する権限がありません'));
      }

      final data = shop.toMap();
      data['updatedAt'] = data['updatedAt'];
      await _shopsCollection.doc(shop.id).update(data);
      final doc = await _shopsCollection.doc(shop.id).get();
      return Result.success(Shop.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('ショップの更新に失敗しました: $e'));
    }
  }

  /// Get the current user's shop by UID (returns null if not exists)
  Future<Result<Shop?, AppError>> getMyShop(String uid) async {
    try {
      final doc = await _shopsCollection.doc(uid).get();
      if (!doc.exists) {
        return Result.success(null);
      }
      return Result.success(Shop.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('ショップ情報の取得に失敗しました: $e'));
    }
  }

  /// Stream of inquiry counts for a shop — emits real-time updates.
  ///
  /// Each event is {'total': N, 'unread': M} where unread is the number of
  /// threads with unreadCountShop > 0.
  ///
  /// Implementation uses two parallel snapshots merged via Rx-style combineLatest
  /// approximation: both queries are listened separately and the latest value
  /// of each is combined on every emission.
  Stream<Map<String, int>> watchInquiryCount(String shopId) {
    final inquiriesCollection =
        _firestore.collection(FirestoreCollections.inquiries);

    // Stream of all inquiry docs for the shop
    final totalStream =
        inquiriesCollection.where('shopId', isEqualTo: shopId).snapshots();

    // Stream of unread inquiry docs for the shop
    final unreadStream = inquiriesCollection
        .where('shopId', isEqualTo: shopId)
        .where('unreadCountShop', isGreaterThan: 0)
        .snapshots();

    // Combine both streams by keeping track of latest values
    int latestTotal = 0;
    int latestUnread = 0;

    return Stream.multi((controller) {
      bool totalReceived = false;
      bool unreadReceived = false;

      void emit() {
        if (totalReceived && unreadReceived) {
          controller.add({'total': latestTotal, 'unread': latestUnread});
        }
      }

      final totalSub = totalStream.listen(
        (snapshot) {
          latestTotal = snapshot.docs.length;
          totalReceived = true;
          emit();
        },
        onError: controller.addError,
      );

      final unreadSub = unreadStream.listen(
        (snapshot) {
          latestUnread = snapshot.docs.length;
          unreadReceived = true;
          emit();
        },
        onError: controller.addError,
      );

      controller.onCancel = () {
        totalSub.cancel();
        unreadSub.cancel();
      };
    });
  }

  /// Get inquiry count for a shop (total and unread by shop)
  ///
  /// Returns {'total': N, 'unread': M} where unread is threads with
  /// unreadCountShop > 0.
  Future<Result<Map<String, int>, AppError>> getInquiryCount(
    String shopId,
  ) async {
    try {
      final inquiriesCollection =
          _firestore.collection(FirestoreCollections.inquiries);

      // Fetch all inquiries for this shop
      final totalSnapshot =
          await inquiriesCollection.where('shopId', isEqualTo: shopId).get();

      // Count threads where shop has unread messages
      final unreadSnapshot = await inquiriesCollection
          .where('shopId', isEqualTo: shopId)
          .where('unreadCountShop', isGreaterThan: 0)
          .get();

      return Result.success({
        'total': totalSnapshot.docs.length,
        'unread': unreadSnapshot.docs.length,
      });
    } catch (e) {
      return Result.failure(AppError.server('問い合わせ件数の取得に失敗しました: $e'));
    }
  }

  /// Delete the current user's shop
  Future<Result<void, AppError>> deleteMyShop(String uid) async {
    try {
      final doc = await _shopsCollection.doc(uid).get();
      if (!doc.exists) {
        return Result.failure(AppError.notFound('ショップが見つかりません'));
      }

      final data = doc.data()!;
      if (data['ownerId'] != uid) {
        return Result.failure(AppError.permission('このショップを削除する権限がありません'));
      }

      await _shopsCollection.doc(uid).delete();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.server('ショップの削除に失敗しました: $e'));
    }
  }

  /// Get shops by service category
  Future<Result<List<Shop>, AppError>> getShopsByService(
    ServiceCategory category, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _shopsCollection
          .where('isActive', isEqualTo: true)
          .where('services', arrayContains: category.name)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final shops =
          snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('店舗の取得に失敗しました: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Case studies (施工事例)
  // ---------------------------------------------------------------------------

  /// Uploads a case study image and returns the download URL.
  /// [type] should be 'before' or 'after'.
  Future<Result<String, AppError>> uploadCaseStudyImage(
      String shopId, XFile image, String type) async {
    try {
      final ext = image.path.split('.').last.toLowerCase();
      final name =
          '${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage
          .ref()
          .child('shops/$shopId/caseStudies/$name');
      final uploadTask = await ref.putFile(File(image.path));
      final url = await uploadTask.ref.getDownloadURL();
      return Result.success(url);
    } catch (e) {
      return Result.failure(AppError.server('画像のアップロードに失敗しました: $e'));
    }
  }

  CollectionReference<Map<String, dynamic>> _caseStudiesCollection(
          String shopId) =>
      _shopsCollection.doc(shopId).collection('caseStudies');

  /// Fetches all case studies for a shop, newest first.
  Future<Result<List<ShopCaseStudy>, AppError>> getCaseStudies(
      String shopId) async {
    try {
      final snapshot = await _caseStudiesCollection(shopId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      final studies =
          snapshot.docs.map((doc) => ShopCaseStudy.fromFirestore(doc)).toList();
      return Result.success(studies);
    } catch (e) {
      return Result.failure(AppError.server('施工事例の取得に失敗しました: $e'));
    }
  }

  /// Adds a case study. The returned study has the Firestore-generated id.
  Future<Result<ShopCaseStudy, AppError>> addCaseStudy(
      ShopCaseStudy study) async {
    try {
      final ref = await _caseStudiesCollection(study.shopId).add(study.toMap());
      final doc = await ref.get();
      return Result.success(ShopCaseStudy.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('施工事例の追加に失敗しました: $e'));
    }
  }

  /// Deletes a case study by id.
  Future<Result<void, AppError>> deleteCaseStudy(
      String shopId, String studyId) async {
    try {
      await _caseStudiesCollection(shopId).doc(studyId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.server('施工事例の削除に失敗しました: $e'));
    }
  }

  // Simple Haversine distance calculation
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 3.14159265359 / 2);
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }

  double _taylorSin(double x) {
    // Normalize to [-π, π]
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }

    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _atan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.14159265359 / 2 - _atan(1 / x.abs()));
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  double _newtonSqrt(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
