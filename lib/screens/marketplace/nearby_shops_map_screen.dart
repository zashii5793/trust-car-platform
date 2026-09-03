import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/shop_map_utils.dart';
import '../../models/shop.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import 'shop_detail_screen.dart';

/// Issue #41 Phase 1: 近隣工場地図表示（GoogleMap連動・色分けピン）
///
/// - 提携店: AppColors.primary 系ブルーマーカー + 審査済バッジ
/// - 非提携店: グレーマーカー +「参考（未審査）」ラベル
/// - ピンタップ→BottomSheetで詳細＋「詳細を見る」CTA
class NearbyShopsMapScreen extends StatefulWidget {
  const NearbyShopsMapScreen({super.key});

  @override
  State<NearbyShopsMapScreen> createState() => _NearbyShopsMapScreenState();
}

class _NearbyShopsMapScreenState extends State<NearbyShopsMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // Default center: Tokyo station area
  static const _defaultCenter = LatLng(35.6812, 139.7671);
  static const _defaultZoom = 13.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildMarkers();
    });
  }

  void _buildMarkers() {
    final provider = context.read<ShopProvider>();
    final shops = ShopMapUtils.filterWithLocation(provider.shops);
    final markers = <Marker>{};

    for (final shop in shops) {
      final category = ShopMapUtils.categorize(shop);
      // Azure=提携（ブランドブルー系）、Orange=非提携（参考・未審査）
      final hue = category == ShopPinCategory.partner
          ? BitmapDescriptor.hueAzure
          : BitmapDescriptor.hueOrange;

      markers.add(Marker(
        markerId: MarkerId(shop.id),
        position: LatLng(
          shop.location!.latitude,
          shop.location!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: ShopMapUtils.infoWindowTitle(shop),
          snippet: shop.displayAddress,
        ),
        onTap: () => _onMarkerTapped(shop),
      ));
    }

    setState(() => _markers = markers);
  }

  void _onMarkerTapped(Shop shop) {
    _showShopBottomSheet(shop);
  }

  void _showShopBottomSheet(Shop shop) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ShopInfoSheet(shop: shop),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppLoadingCenter(message: '工場を検索中...');
        }

        final shopsWithLocation =
            ShopMapUtils.filterWithLocation(provider.shops);

        return Stack(
          children: [
            GoogleMap(
              key: const Key('nearby_shops_map'),
              initialCameraPosition: const CameraPosition(
                target: _defaultCenter,
                zoom: _defaultZoom,
              ),
              markers: _markers,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                _buildMarkers();
              },
            ),
            _MapLegend(),
            if (shopsWithLocation.isEmpty) const _NoLocationBanner(),
          ],
        );
      },
    );
  }
}

// ── 凡例（右下） ────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendItem(
                color: AppColors.primary,
                label: '提携（審査済）',
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
  const _ShopInfoSheet({required this.shop});

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
