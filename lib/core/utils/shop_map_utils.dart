import '../../models/shop.dart';

enum ShopPinCategory { partner, nonPartner }

/// 緯度経度。google_maps_flutter の LatLng に依存させないための素の型。
///
/// Provider や純粋関数から地図 SDK を切り離しておくと、テストで地図を
/// 描かずにピンの出し分けを確かめられる。
typedef ShopGeoPoint = ({double latitude, double longitude});

class ShopPartition {
  final List<Shop> partners;
  final List<Shop> nonPartners;
  const ShopPartition({required this.partners, required this.nonPartners});
}

/// 地図に立てる1本のピン（Issue #43）。
///
/// 地図 SDK の Marker に変換する直前の、描画に要る情報だけを持つ。
class ShopMapPin {
  final String shopId;
  final double latitude;
  final double longitude;
  final ShopPinCategory category;

  /// InfoWindow のタイトル（名前＋審査済/広告/参考）。
  final String title;

  /// InfoWindow の本文（距離・住所）。無ければ空文字。
  final String snippet;

  final bool isVerified;
  final bool isFeatured;

  /// 現在地からの距離（km）。距離ソート前は null。
  final double? distanceKm;

  const ShopMapPin({
    required this.shopId,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.title,
    required this.snippet,
    required this.isVerified,
    required this.isFeatured,
    this.distanceKm,
  });

  bool get isPartner => category == ShopPinCategory.partner;
}

/// Pure functions for map pin categorization (Issue #41 Phase 1).
class ShopMapUtils {
  ShopMapUtils._();

  /// 現在地も店の位置も分からないときの中心（東京駅付近）。
  static const ShopGeoPoint defaultCenter =
      (latitude: 35.6812, longitude: 139.7671);

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
  ///
  /// 広告（isFeatured）は一覧と同じく必ず明示する（順位操作を隠さない）。
  static String infoWindowTitle(Shop shop) {
    final tags = <String>[
      if (shop.isPartner && shop.isVerified) '審査済',
      if (!shop.isPartner) '参考・未審査',
      if (shop.isFeatured) '広告',
    ];
    if (tags.isEmpty) return shop.name;
    return '${shop.name}（${tags.join('・')}）';
  }

  /// 店の一覧から地図のピンを作る。
  ///
  /// - 位置（location）の無い店は除く
  /// - [distanceFor] で距離が分かる店は近い順、分からない店は末尾
  ///   （同じ扱いの中では入力順を保つ）
  static List<ShopMapPin> buildPins(
    List<Shop> shops, {
    double? Function(String shopId)? distanceFor,
  }) {
    final pins = <ShopMapPin>[
      for (final shop in shops)
        if (shop.location != null) _toPin(shop, distanceFor?.call(shop.id)),
    ];

    // List.sort は安定とは限らないので、元の位置を添えて比較する。
    final indexed = pins.indexed.toList()
      ..sort((a, b) {
        final da = a.$2.distanceKm;
        final db = b.$2.distanceKm;
        if (da != null && db != null && da != db) return da.compareTo(db);
        if (da != null && db == null) return -1;
        if (da == null && db != null) return 1;
        return a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  /// 地図を開いたときの中心。
  ///
  /// 現在地 → 先頭の提携店 → 先頭のピン → [defaultCenter] の順で決める。
  static ShopGeoPoint initialCenter(
    List<ShopMapPin> pins, {
    ShopGeoPoint? origin,
  }) {
    if (origin != null) return origin;
    if (pins.isEmpty) return defaultCenter;
    final first = pins.firstWhere((p) => p.isPartner, orElse: () => pins.first);
    return (latitude: first.latitude, longitude: first.longitude);
  }

  static ShopMapPin _toPin(Shop shop, double? distanceKm) {
    final parts = <String>[
      if (distanceKm != null) '現在地から${distanceKm.toStringAsFixed(1)}km',
      if (shop.displayAddress.isNotEmpty) shop.displayAddress,
    ];
    return ShopMapPin(
      shopId: shop.id,
      latitude: shop.location!.latitude,
      longitude: shop.location!.longitude,
      category: categorize(shop),
      title: infoWindowTitle(shop),
      snippet: parts.join(' / '),
      isVerified: shop.isVerified,
      isFeatured: shop.isFeatured,
      distanceKm: distanceKm,
    );
  }
}
