import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/vehicle_colors.dart';

/// Body color (車体色) picker bottom sheet.
///
/// Choices first, free text as fallback: [kCommonVehicleColors] is only an
/// input aid — real paint names (例: クリスタルホワイトパールマイカ) are
/// maker-specific and cannot be enumerated, so the sheet always keeps a
/// free-text field at the bottom. A color missing from the list must never
/// block registration (same policy as maker/model/grade pickers).

/// Shows a bottom sheet with common color chips and a free-text fallback.
///
/// Resolves with the chosen or typed color, or null when dismissed.
/// [current] pre-fills the free-text field so an already-entered custom
/// color is not lost when the sheet reopens.
Future<String?> showColorPickerSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ColorPickerSheet(current: current),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  final String? current;

  const _ColorPickerSheet({this.current});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final TextEditingController _customController =
      TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final color = _customController.text.trim();
    // Empty input is a no-op (same as the grade picker's custom input) —
    // clearing the color is done by editing the field on the form itself.
    if (color.isEmpty) return;
    Navigator.pop(context, color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        // Keep the free-text row above the software keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    '車体色を選択',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final color in kCommonVehicleColors)
                      ActionChip(
                        label: Text(color),
                        onPressed: () => Navigator.pop(context, color),
                      ),
                  ],
                ),
              ),
            ),
            AppSpacing.verticalMd,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      decoration: InputDecoration(
                        labelText: '一覧に無い色を入力',
                        hintText: '例: クリスタルホワイトパールマイカ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _submitCustom(),
                    ),
                  ),
                  AppSpacing.horizontalSm,
                  ElevatedButton(
                    onPressed: _submitCustom,
                    child: const Text('決定'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
