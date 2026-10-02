import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/shop_map_utils.dart';
import '../../models/shop.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import 'shop_detail_screen.dart';

/// 地図本体を組む関数。
///
/// google_maps_flutter の GoogleMap はテスト環境で描けない（プラットフォーム
/// ビュー）。地図そのものだけを差し替えられるようにして、ピンの出し分けや
/// BottomSheet はテストで確かめる。
typedef ShopMapViewBuilder = Widget Function(
  BuildContext context,
  ShopMapViewData data,
);

/// 地図本体に渡すもの。地図 SDK の型は含めない。
class ShopMapViewData {
  /// 立てるピン（近い順。距離が無い店は末尾）。
  final List<ShopMapPin> pins;

  /// 中心（現在地 → 提携店 → 東京駅の順で決まる）。
  final ShopGeoPoint center;

  /// 現在地を取得済みか。取得済みのときだけ現在地の青い点を出す
  /// （権限が無いまま myLocationEnabled にしない）。
  final bool hasUserLocation;

  /// ピンがタップされたとき。
  final ValueChanged<ShopMapPin> onPinTap;

  const ShopMapViewData({
    required this.pins,
    required this.center,
    required this.hasUserLocation,
    required this.onPinTap,
  });
}

/// Issue #41 Phase 1 / #43: 近隣工場地図表示（GoogleMap連動・色分けピン）
///
/// - 提携店: AppColors.primary 系ブルーマーカー + 審査済バッジ
/// - 非提携店: オレンジマーカー +「参考（未審査）」ラベル
/// - 広告（isFeatured）は InfoWindow と BottomSheet で明示する
/// - ピンタップ→BottomSheetで詳細＋「詳細を見る」CTA
///
/// Maps のキーが無いビルド（MapsConfig.isConfigured == false）では、
/// 呼び出し側（ShopListScreen）がこの画面自体を出さない。
class NearbyShopsMapScreen extends StatelessWidget {
  /// 地図本体。null なら GoogleMap を使う。テストで差し替える。
  final ShopMapViewBuilder? mapViewBuilder;

  const NearbyShopsMapScreen({super.key, this.mapViewBuilder});

  void _showShopBottomSheet(BuildContext context, ShopMapPin pin) {
    final provider = context.read<ShopProvider>();
    final shop = provider.shops.where((s) => s.id == pin.shopId).firstOrNull;
    if (shop == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ShopInfoSheet(shop: shop, distanceKm: pin.distanceKm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppLoadingCenter(message: '工場を検索中...');
        }

        // 絞り込みや距離ソートのたびに作り直す（以前は初回だけで、
        // 絞り込みを変えてもピンが残っていた）。
        final pins = ShopMapUtils.buildPins(
          provider.shops,
          distanceFor: provider.distanceForShop,
        );
        final origin = provider.distanceOrigin;
        final data = ShopMapViewData(
          pins: pins,
          center: ShopMapUtils.initialCenter(pins, origin: origin),
          hasUserLocation: origin != null,
          onPinTap: (pin) => _showShopBottomSheet(context, pin),
        );
        final builder = mapViewBuilder ?? _buildGoogleMap;

        return Stack(
          children: [
            Positioned.fill(child: builder(context, data)),
            const _MapLegend(),
            if (pins.isEmpty) const _NoLocationBanner(),
          ],
        );
      },
    );
  }

  static Widget _buildGoogleMap(BuildContext context, ShopMapViewData data) =>
      _GoogleShopMapView(data: data);
}

/// GoogleMap による地図本体（実機・Web 用）。
class _GoogleShopMapView extends StatefulWidget {
  final ShopMapViewData data;
  const _GoogleShopMapView({required this.data});

  @override
  State<_GoogleShopMapView> createState() => _GoogleShopMapViewState();
}

class _GoogleShopMapViewState extends State<_GoogleShopMapView> {
  GoogleMapController? _mapController;

  static const _defaultZoom = 13.0;

  @override
  void didUpdateWidget(covariant _GoogleShopMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 地図を開いた後に現在地が取れたら、そこへ寄せる。
    final c = widget.data.center;
    if (c != oldWidget.data.center) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(c.latitude, c.longitude)),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _markers() {
    return {
      for (final pin in widget.data.pins)
        Marker(
          markerId: MarkerId(pin.shopId),
          position: LatLng(pin.latitude, pin.longitude),
          // Azure=提携（ブランドブルー系）、Orange=非提携（参考・未審査）
          icon: BitmapDescriptor.defaultMarkerWithHue(
            pin.isPartner
                ? BitmapDescriptor.hueAzure
                : BitmapDescriptor.hueOrange,
          ),
          // 提携店のピンを非提携店より手前に出す。
          zIndexInt: pin.isPartner ? 1 : 0,
          infoWindow: InfoWindow(
            title: pin.title,
            snippet: pin.snippet.isEmpty ? null : pin.snippet,
          ),
          onTap: () => widget.data.onPinTap(pin),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.data.center;
    return GoogleMap(
      key: const Key('nearby_shops_map'),
      initialCameraPosition: CameraPosition(
        target: LatLng(c.latitude, c.longitude),
        zoom: _defaultZoom,
      ),
      markers: _markers(),
      myLocationButtonEnabled: widget.data.hasUserLocation,
      myLocationEnabled: widget.data.hasUserLocation,
      mapToolbarEnabled: false,
      onMapCreated: (controller) => _mapController = controller,
    );
  }
}

// ── 凡例（右下） ────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Card(
        key: const Key('map_legend'),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendItem(
                color: AppColors.primary,
                label: '提携店',
              ),
              const SizedBox(height: 4),
              _LegendItem(
                color: Colors.orange,
                label: '参考（未審査）',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ── location未登録バナー ──────────────────────────────────────────────
class _NoLocationBanner extends StatelessWidget {
  const _NoLocationBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.amber.shade100,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '現在、地図に表示できる工場がありません。\n「リスト」ビューで全工場を確認できます。',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// ── 工場情報BottomSheet ───────────────────────────────────────────────
class _ShopInfoSheet extends StatelessWidget {
  final Shop shop;

  /// 現在地からの距離（km）。未取得なら出さない。
  final double? distanceKm;

  const _ShopInfoSheet({required this.shop, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final isPartner = shop.isPartner;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              key: const Key('bottom_sheet_handle'),
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (shop.isVerified)
                Chip(
                  key: const Key('verified_badge'),
                  label: const Text('審査済'),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                  ),
                  padding: EdgeInsets.zero,
                ),
              // 広告は一覧と同じく必ず明示する（順位操作を隠さない）。
              if (shop.isFeatured)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Chip(
                    key: const Key('featured_badge'),
                    label: const Text('広告'),
                    backgroundColor: Colors.amber.shade100,
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                  ),
                ),
              if (!isPartner)
                Chip(
                  key: const Key('non_partner_badge'),
                  label: const Text('参考（未審査）'),
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: const TextStyle(fontSize: 11),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          if (distanceKm != null) ...[
            const SizedBox(height: 4),
            Text(
              '現在地から${distanceKm!.toStringAsFixed(1)}km',
              key: const Key('sheet_distance'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
          if (shop.displayAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              shop.displayAddress,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          if (isPartner)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('view_detail_button'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ShopDetailScreen(shopId: shop.id),
                    ),
                  );
                },
                child: const Text('詳細・問い合わせ'),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const Key('non_partner_inquiry_prompt'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'この工場への問い合わせは、パートナー登録後に可能になります。'
                          'ご要望は需要として記録し、工場へ通知します。',
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('問い合わせするには？'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
