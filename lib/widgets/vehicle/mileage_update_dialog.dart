import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../models/vehicle.dart';

/// Dialog for updating vehicle mileage.
/// Shows current mileage and validates that new value is >= current.
class MileageUpdateDialog extends StatefulWidget {
  final Vehicle vehicle;
  final Future<void> Function(int newMileage) onUpdate;

  const MileageUpdateDialog({
    super.key,
    required this.vehicle,
    required this.onUpdate,
  });

  /// Opens the mileage update dialog.
  static Future<void> show(
    BuildContext context,
    Vehicle vehicle,
    Future<void> Function(int newMileage) onUpdate,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => MileageUpdateDialog(
        vehicle: vehicle,
        onUpdate: onUpdate,
      ),
    );
  }

  @override
  State<MileageUpdateDialog> createState() => _MileageUpdateDialogState();
}

class _MileageUpdateDialogState extends State<MileageUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '走行距離を入力してください';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '整数で入力してください';
    }
    if (parsed < 0) {
      return '0以上の値を入力してください';
    }
    if (parsed < widget.vehicle.mileage) {
      return '現在の走行距離（${widget.vehicle.mileage} km）以上を入力してください';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final newMileage = int.parse(_controller.text.trim());

    setState(() => _isLoading = true);
    try {
      await widget.onUpdate(newMileage);
    } finally {
      // Check mounted before using context after async gap
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Icon(Icons.speed_outlined, color: AppColors.warning, size: 24),
          const SizedBox(width: 8),
          const Text('走行距離を更新'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '現在の走行距離: ${widget.vehicle.mileage} km',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '新しい走行距離',
                hintText: widget.vehicle.mileage.toString(),
                suffixText: 'km',
                border: const OutlineInputBorder(),
              ),
              validator: _validate,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('更新'),
        ),
      ],
    );
  }
}
