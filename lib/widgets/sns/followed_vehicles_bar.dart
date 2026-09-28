import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/vehicle_profile.dart';
import '../../providers/auth_provider.dart';
import '../../screens/vehicle/vehicle_profile_screen.dart';
import '../../services/vehicle_profile_service.dart';

/// フィードの上に出す「フォロー中の愛車」。
///
/// 愛車ページをフォローしても、見に行く場所が無ければ意味がない。
/// フォローしている車が無いときは何も出さない（場所を取らない）。
class FollowedVehiclesBar extends StatefulWidget {
  /// テストで差し替えるため。null なら ServiceLocator から取る。
  final VehicleProfileService? service;
  final String? uid;

  const FollowedVehiclesBar({super.key, this.service, this.uid});

  @override
  State<FollowedVehiclesBar> createState() => _FollowedVehiclesBarState();
}

class _FollowedVehiclesBarState extends State<FollowedVehiclesBar> {
  List<VehicleProfile> _profiles = const [];

  VehicleProfileService? get _service =>
      widget.service ??
      (sl.isRegistered<VehicleProfileService>()
          ? sl.get<VehicleProfileService>()
          : null);

  String? get _uid {
    if (widget.uid != null) return widget.uid;
    try {
      return context.read<AuthProvider>().firebaseUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = _service;
    final uid = _uid;
    if (svc == null || uid == null) return;
    final list = await svc.followed(uid);
    if (!mounted) return;
    setState(() => _profiles = list);
  }

  @override
  Widget build(BuildContext context) {
    if (_profiles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key('followed_vehicles_bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: Text('フォロー中の愛車'),
            ),
          ),
          for (final p in _profiles)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ActionChip(
                key: Key('followed_${p.vehicleId}'),
                avatar: const Icon(Icons.directions_car, size: 16),
                label: Text(p.title),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => VehicleProfileScreen(
                      service: _service!,
                      profile: p,
                      viewerUid: _uid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
