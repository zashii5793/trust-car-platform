import 'dart:math' as math;
import '../models/shop.dart';

/// Result of comparing a single shop against user criteria
class ShopComparisonResult {
  final Shop shop;

  /// Distance from user's location in kilometres. Null when shop has no
  /// GeoPoint or the user location was not provided.
  final double? distanceKm;

  /// True when the shop offers all of the [requiredServices] requested,
  /// or when no required services were specified.
  final bool offersRequestedService;

  /// Estimated response / availability in days.
  /// 1 = same day, 2 = next day, 3 = 2-3 days.
  final int estimatedResponseDays;

  const ShopComparisonResult({
    required this.shop,
    this.distanceKm,
    required this.offersRequestedService,
    required this.estimatedResponseDays,
  });
}

/// Pure comparison / recommendation service for shops.
///
/// Has no Firestore dependency — use a `const` constructor.
class ShopComparisonService {
  const ShopComparisonService();

  // ──────────────────────────────────────────────
  // compare
  // ──────────────────────────────────────────────

  /// Compare 2–5 shops and return a scored result for each.
  ///
  /// When [userLat] / [userLng] and the shop's [Shop.location] (GeoPoint)
  /// are all provided, [ShopComparisonResult.distanceKm] is populated and
  /// the list is sorted nearest-first.
  List<ShopComparisonResult> compare({
    required List<Shop> shops,
    List<ServiceCategory>? requiredServices,
    double? userLat,
    double? userLng,
  }) {
    final results = shops.map((shop) {
      final distance = _computeDistance(shop, userLat, userLng);
      final offersService = _offersAllServices(shop, requiredServices);
      final responseDays = _estimateResponseDays(shop);

      return ShopComparisonResult(
        shop: shop,
        distanceKm: distance,
        offersRequestedService: offersService,
        estimatedResponseDays: responseDays,
      );
    }).toList();

    // Sort by distance when available
    if (userLat != null && userLng != null) {
      results.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    }

    return results;
  }

  // ──────────────────────────────────────────────
  // recommend
  // ──────────────────────────────────────────────

  /// Return the best-balanced shop for [primaryNeed] using a composite score.
  ///
  /// Score = rating * ln(reviewCount + 1) - distancePenalty
  ///
  /// Only shops that offer [primaryNeed] are considered.
  /// Returns null if no eligible shop exists.
  Shop? recommend({
    required List<ShopComparisonResult> results,
    required ServiceCategory primaryNeed,
  }) {
    final candidates = results
        .where((r) => r.shop.offersService(primaryNeed))
        .toList();

    if (candidates.isEmpty) return null;

    ShopComparisonResult? best;
    double bestScore = double.negativeInfinity;

    for (final candidate in candidates) {
      final score = _compositeScore(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best?.shop;
  }

  // ──────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────

  /// Haversine distance between user location and shop GeoPoint (km).
  /// Returns null when either location is unavailable.
  double? _computeDistance(Shop shop, double? userLat, double? userLng) {
    if (userLat == null || userLng == null) return null;
    final geoPoint = shop.location;
    if (geoPoint == null) return null;

    const earthRadiusKm = 6371.0;
    final dLat = _toRad(geoPoint.latitude - userLat);
    final dLng = _toRad(geoPoint.longitude - userLng);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(userLat)) *
            math.cos(_toRad(geoPoint.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRad(double deg) => deg * math.pi / 180.0;

  /// True when [shop] offers every service in [required], or when [required]
  /// is null / empty.
  bool _offersAllServices(Shop shop, List<ServiceCategory>? required) {
    if (required == null || required.isEmpty) return true;
    return required.every((s) => shop.offersService(s));
  }

  /// Heuristic: shops with walkIn or phone reservations can respond same-day.
  int _estimateResponseDays(Shop shop) {
    if (shop.reservationMethods.contains(ReservationMethod.walkIn)) {
      return 1; // same day
    }
    if (shop.reservationMethods.contains(ReservationMethod.phone) ||
        shop.reservationMethods.contains(ReservationMethod.line)) {
      return 2; // next day
    }
    return 3; // 2-3 days
  }

  /// Composite score for recommendation ranking.
  ///
  /// score = rating * ln(reviewCount + 1) - distancePenalty
  double _compositeScore(ShopComparisonResult result) {
    final rating = result.shop.rating ?? 0.0;
    final reviewCount = result.shop.reviewCount;
    final ratingScore = rating * math.log(reviewCount + 1);

    // Distance penalty: 0.05 per km (small — service quality matters more)
    final distancePenalty = (result.distanceKm ?? 0.0) * 0.05;

    return ratingScore - distancePenalty;
  }
}
