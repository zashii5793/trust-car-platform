import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../models/post.dart';
import '../../screens/vehicle/vehicle_profile_screen.dart';
import '../../services/vehicle_profile_service.dart';

/// 投稿に付いた「どの車の話か」。タップでその車の愛車ページを開く。
///
/// 投稿には車の札（vehicleTag）が 2026-09 から付いていたが、どこにも
/// 表示されていなかった。人ではなく車でつながる入口として出す。
///
/// 愛車ページが無い・公開されていないときは、そう伝えるだけにする
/// （非公開のページの有無を、それ以上は漏らさない）。
class PostVehicleChip extends StatelessWidget {
  final PostVehicleTag? tag;

  /// テストで差し替えるため。null なら ServiceLocator から取る。
  final VehicleProfileService? service;

  const PostVehicleChip({super.key, required this.tag, this.service});

  Future<void> _open(BuildContext context, String vehicleId) async {
    final svc = service ??
        (sl.isRegistered<VehicleProfileService>()
            ? sl.get<VehicleProfileService>()
            : null);
    if (svc == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await svc.get(vehicleId);
    final profile = result.valueOrNull;
    if (profile == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('この車の愛車ページは公開されていません')),
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleProfileScreen(service: svc, profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tag;
    final name = t?.displayName;
    if (t == null || name == null) return const SizedBox.shrink();
    final vehicleId = t.vehicleId;
    return ActionChip(
      key: Key('post_vehicle_chip_${vehicleId ?? name}'),
      avatar: const Icon(Icons.directions_car, size: 16),
      label: Text(name),
      visualDensity: VisualDensity.compact,
      onPressed: vehicleId == null ? null : () => _open(context, vehicleId),
    );
  }
}
