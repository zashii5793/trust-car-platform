import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/shop.dart';
import 'shop_detail_screen.dart';

/// 近隣工場を地図で表示する画面（Issue #43）。
///
/// 提携（検証済み/注目）工場はピンの色で区別する。マーカーの情報ウィンドウを
/// タップすると工場詳細へ遷移する。API キーは `MapsConfig` 経由でビルド時に注入
/// される前提で、この画面はキーがある場合のみ開かれる（呼び出し側でガード）。
class ShopMapScreen extends StatefulWidget {
  /// 表示対象の工場一覧（`ShopProvider.shops` を想定）。
  final List<Shop> shops;

  /// 初期カメラ位置（現在地）。null の場合は工場位置の平均、無ければ東京駅。
  final double? initialLat;
  final double? initialLng;

  const ShopMapScreen({
    super.key,
    required this.shops,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  /// 東京駅（位置情報も工場位置も無いときのフォールバック）。
  static const _fallback = LatLng(35.681236, 139.767125);

  List<Shop> get _locatedShops =>
      widget.shops.where((s) => s.location != null).toList();

  LatLng _initialTarget() {
    if (widget.initialLat != null && widget.initialLng != null) {
      return LatLng(widget.initialLat!, widget.initialLng!);
    }
    final located = _locatedShops;
    if (located.isEmpty) return _fallback;
    final avgLat = located
            .map((s) => s.location!.latitude)
            .reduce((a, b) => a + b) /
        located.length;
    final avgLng = located
            .map((s) => s.location!.longitude)
            .reduce((a, b) => a + b) /
        located.length;
    return LatLng(avgLat, avgLng);
  }

  double _hueFor(Shop shop) {
    // 提携（検証済み）= 青、注目（広告）= オレンジ、その他 = 赤。
    if (shop.isVerified) return BitmapDescriptor.hueAzure;
    if (shop.isFeatured) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueRed;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 現在地マーカー（緑）。
    if (widget.initialLat != null && widget.initialLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('_current_location'),
          position: LatLng(widget.initialLat!, widget.initialLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: '現在地'),
        ),
      );
    }

    for (final shop in _locatedShops) {
      final GeoPoint loc = shop.location!;
      final rating = shop.rating;
      markers.add(
        Marker(
          markerId: MarkerId(shop.id),
          position: LatLng(loc.latitude, loc.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(shop)),
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: rating != null
                ? '★${rating.toStringAsFixed(1)}・タップで詳細'
                : 'タップで詳細',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopDetailScreen(shop: shop),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final located = _locatedShops;
    return Scaffold(
      appBar: AppBar(
        title: const Text('近隣の工場（地図）'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialTarget(),
              zoom: 11,
            ),
            markers: _buildMarkers(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),
          if (located.isEmpty)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '位置情報が登録された工場がまだありません。'
                    '工場が住所・位置を登録すると地図に表示されます。',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
