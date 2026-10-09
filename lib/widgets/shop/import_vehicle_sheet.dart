import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/vehicle.dart';

/// Asks which car a shop-sent maintenance detail belongs to.
///
/// The sheet scrolls when the cars do not fit: at 1209x677 the old sheet
/// overflowed and the 4th car could not be chosen (usability test 2026-10-09,
/// shop #15). The car the shop named is preselected; the user confirms.
Future<String?> showImportVehicleSheet(
  BuildContext context, {
  required List<Vehicle> vehicles,
  String? initialVehicleId,
  String? shopVehicleLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ImportVehicleSheet(
      vehicles: vehicles,
      initialVehicleId: initialVehicleId,
      shopVehicleLabel: shopVehicleLabel,
    ),
  );
}

class ImportVehicleSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final String? initialVehicleId;

  /// The car as the shop wrote it (name and plate), shown for reference.
  final String? shopVehicleLabel;

  const ImportVehicleSheet({
    super.key,
    required this.vehicles,
    this.initialVehicleId,
    this.shopVehicleLabel,
  });

  @override
  State<ImportVehicleSheet> createState() => _ImportVehicleSheetState();
}

class _ImportVehicleSheetState extends State<ImportVehicleSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialVehicleId;
    if (initial != null && widget.vehicles.any((v) => v.id == initial)) {
      _selected = initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final shopLabel = widget.shopVehicleLabel;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('どの車の整備明細ですか？', style: theme.textTheme.titleMedium),
                  if (shopLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '店の指定: $shopLabel',
                      key: const Key('import_vehicle_shop_label'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: ListView(
                key: const Key('import_vehicle_list'),
                shrinkWrap: true,
                children: [
                  for (final v in widget.vehicles)
                    ListTile(
                      key: Key('import_vehicle_${v.id}'),
                      leading: const Icon(Icons.directions_car),
                      title: Text(v.displayName),
                      subtitle:
                          v.licensePlate == null ? null : Text(v.licensePlate!),
                      selected: _selected == v.id,
                      trailing: _selected == v.id
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () => setState(() => _selected = v.id),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton(
                key: const Key('import_vehicle_confirm'),
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                child: const Text('この車の記録に追加'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
