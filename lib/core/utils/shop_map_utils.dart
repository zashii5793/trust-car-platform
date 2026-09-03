import '../../models/shop.dart';

enum ShopPinCategory { partner, nonPartner }

class ShopPartition {
  final List<Shop> partners;
  final List<Shop> nonPartners;
  const ShopPartition({required this.partners, required this.nonPartners});
}

/// Pure functions for map pin categorization (Issue #41 Phase 1).
class ShopMapUtils {
  ShopMapUtils._();

  static ShopPinCategory categorize(Shop shop) =>
      shop.isPartner ? ShopPinCategory.partner : ShopPinCategory.nonPartner;

  /// Returns only shops that have a Firestore GeoPoint location set.
  static List<Shop> filterWithLocation(List<Shop> shops) =>
      shops.where((s) => s.location != null).toList();

  /// Splits shops (already filtered by location) into partner / nonPartner.
  static ShopPartition partition(List<Shop> shops) {
    final partners = <Shop>[];
    final nonPartners = <Shop>[];
    for (final shop in shops) {
      if (shop.isPartner) {
        partners.add(shop);
      } else {
        nonPartners.add(shop);
      }
    }
    return ShopPartition(partners: partners, nonPartners: nonPartners);
  }

  /// Returns the Google Maps InfoWindow title text for a shop.
  static String infoWindowTitle(Shop shop) {
    if (shop.isPartner && shop.isVerified) return '${shop.name}（審査済）';
    if (!shop.isPartner) return '${shop.name}（参考・未審査）';
    return shop.name;
  }
}
