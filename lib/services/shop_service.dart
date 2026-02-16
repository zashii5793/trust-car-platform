import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop.dart';

/// Service for shop (business partner) operations
class ShopService {
  final FirebaseFirestore _firestore;

  ShopService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
      Query<Map<String, dynamic>> query = _shopsCollection
          .where('isActive', isEqualTo: true);

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

      final shops = snapshot.docs
          .map((doc) => Shop.fromFirestore(doc))
          .toList();

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

      final shops = snapshot.docs
          .map((doc) => Shop.fromFirestore(doc))
          .toList();

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

      final shops = snapshot.docs
          .map((doc) => Shop.fromFirestore(doc))
          .toList();

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

      final shops = snapshot.docs
          .map((doc) => Shop.fromFirestore(doc))
          .toList();

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

      final shops = snapshot.docs
          .map((doc) => Shop.fromFirestore(doc))
          .where((shop) {
            if (shop.location == null) return false;
            // Rough distance calculation
            final distance = _calculateDistance(
              center.latitude,
              center.longitude,
              shop.location!.latitude,
              shop.location!.longitude,
            );
            return distance <= radiusKm;
          })
          .toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('周辺店舗の取得に失敗しました: $e'));
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

      final shops = snapshot.docs
          .map((doc) => Shop.fromFirestore(doc))
          .toList();

      return Result.success(shops);
    } catch (e) {
      return Result.failure(AppError.server('店舗の取得に失敗しました: $e'));
    }
  }

  // Simple Haversine distance calculation
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
        _sin(dLon / 2) * _sin(dLon / 2);
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
    while (x > 3.14159265359) x -= 2 * 3.14159265359;
    while (x < -3.14159265359) x += 2 * 3.14159265359;

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
