import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../models/shop_ledger.dart';
import '../../../services/shop_ledger_service.dart';
import 'ledger_format.dart';

/// 台帳の車両の登録・編集。保存・削除したら true を返して閉じる。
class LedgerVehicleEditScreen extends StatefulWidget {
  final ShopLedgerService service;
  final String shopId;
  final String customerId;
  final LedgerVehicle? existing;

  const LedgerVehicleEditScreen({
    super.key,
    required this.service,
    required this.shopId,
    required this.customerId,
    this.existing,
  });

  @override
  State<LedgerVehicleEditScreen> createState() =>
      _LedgerVehicleEditScreenState();
}

class _LedgerVehicleEditScreenState extends State<LedgerVehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _maker = TextEditingController(text: widget.existing?.maker);
  late final _model = TextEditingController(text: widget.existing?.model);
  late final _plate = TextEditingController(text: widget.existing?.plate);
  late final _year =
      TextEditingController(text: widget.existing?.year?.toString());
  late final _modelCode =
      TextEditingController(text: widget.existing?.modelCode);
  late final _mileage =
      TextEditingController(text: widget.existing?.lastMileage?.toString());
  late DateTime? _inspection = widget.existing?.inspectionExpiry;
  late DateTime? _lastVisit = widget.existing?.lastVisitAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_maker, _model, _plate, _year, _modelCode, _mileage]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '入力してください' : null;

  String? _yearValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final y = int.tryParse(v.trim());
    if (y == null || y < 1950 || y > DateTime.now().year + 1) {
      return '西暦4桁で入力してください';
    }
    return null;
  }

  String? _mileageValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final m = int.tryParse(v.replaceAll(',', '').trim());
    if (m == null || m < 0) return '0以上の数字で入力してください';
    return null;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.service.saveVehicle(
      shopId: widget.shopId,
      customerId: widget.customerId,
      vehicleId: widget.existing?.id,
      maker: _maker.text,
      model: _model.text,
      plate: _plate.text.trim().isEmpty ? null : _plate.text.trim(),
      year: int.tryParse(_year.text.trim()),
      modelCode: _modelCode.text,
      inspectionExpiry: _inspection,
      lastVisitAt: _lastVisit,
      lastMileage: int.tryParse(_mileage.text.replaceAll(',', '').trim()),
      externalId: widget.existing?.externalId,
    );
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (e) => setState(() {
        _error = e.userMessage;
        _saving = false;
      }),
    );
  }

  Future<void> _delete() async {
    final v = widget.existing;
    if (v == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この車両を削除しますか？'),
        content: Text('${v.displayName} を台帳から削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result =
        await widget.service.deleteVehicle(shopId: widget.shopId, vehicle: v);
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result.errorOrNull!.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '車両を追加' : '車両を編集'),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            TextFormField(
              key: const Key('vehicle_maker'),
              controller: _maker,
              decoration: const InputDecoration(
                labelText: 'メーカー *',
                hintText: '例: トヨタ',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            AppSpacing.verticalMd,
            TextFormField(
              key: const Key('vehicle_model'),
              controller: _model,
              decoration: const InputDecoration(
                labelText: '車種 *',
                hintText: '例: ハイエース',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            AppSpacing.verticalMd,
            TextFormField(
              key: const Key('vehicle_plate'),
              controller: _plate,
              decoration: const InputDecoration(
                labelText: 'ナンバー',
                hintText: '例: 品川 300 あ 12-34',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalMd,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '年式（西暦）',
                      border: OutlineInputBorder(),
                    ),
                    validator: _yearValidator,
                  ),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: TextFormField(
                    controller: _modelCode,
                    decoration: const InputDecoration(
                      labelText: '型式',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMd,
            TextFormField(
              controller: _mileage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '走行距離（km）',
                border: OutlineInputBorder(),
              ),
              validator: _mileageValidator,
            ),
            AppSpacing.verticalMd,
            _DateField(
              key: const Key('vehicle_inspection'),
              label: '車検満了日',
              value: _inspection,
              onTap: () => _pickDate(
                current: _inspection,
                onPicked: (d) => _inspection = d,
              ),
              onClear: () => setState(() => _inspection = null),
            ),
            AppSpacing.verticalMd,
            _DateField(
              label: '最終来店日',
              value: _lastVisit,
              onTap: () => _pickDate(
                current: _lastVisit,
                onPicked: (d) => _lastVisit = d,
              ),
              onClear: () => setState(() => _lastVisit = null),
            ),
            if (_error != null) ...[
              AppSpacing.verticalMd,
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            AppSpacing.verticalLg,
            FilledButton(
              key: const Key('vehicle_save'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
              ),
              child: Text(_saving ? '保存しています…' : '保存する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: '消す',
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? '未入力' : ledgerDate(value!)),
      ),
    );
  }
}
