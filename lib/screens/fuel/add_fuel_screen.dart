import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/fuel_record.dart';
import '../../services/fuel_service.dart';

/// Twenty seconds at the pump.
///
/// `docs/HABIT_DESIGN.md` 打ち手1。給油は月2〜4回あり、**唯一の月単位の接点**。
///
/// **項目を増やしたら続かない。** 日付・給油量・金額・走行距離の4つで止める。
/// 保存した瞬間に燃費を返すのが肝で、毎回違う数字が出るから見たくなる。
class AddFuelScreen extends StatefulWidget {
  final FuelService service;
  final String vehicleId;
  final String userId;

  /// 前回の走行距離。入力欄の下に出して、打ち間違いに気づけるようにする。
  final int? lastOdometer;

  /// The day the form opens on. Defaults to today; tests - golden shots in
  /// particular - pin it so the shot does not change with the calendar.
  final DateTime? today;

  const AddFuelScreen({
    super.key,
    required this.service,
    required this.vehicleId,
    required this.userId,
    this.lastOdometer,
    this.today,
  });

  @override
  State<AddFuelScreen> createState() => _AddFuelScreenState();
}

class _AddFuelScreenState extends State<AddFuelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litersController = TextEditingController();
  final _costController = TextEditingController();
  final _odometerController = TextEditingController();

  late DateTime _date = widget.today ?? DateTime.now();
  bool _isFullTank = true;
  bool _busy = false;

  @override
  void dispose() {
    _litersController.dispose();
    _costController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: widget.today ?? DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);

    final record = FuelRecord(
      id: '',
      vehicleId: widget.vehicleId,
      userId: widget.userId,
      date: _date,
      liters: double.parse(_litersController.text.trim()),
      cost: int.tryParse(_costController.text.trim().replaceAll(',', '')) ?? 0,
      odometer:
          int.tryParse(_odometerController.text.trim().replaceAll(',', '')),
      isFullTank: _isFullTank,
      createdAt: DateTime.now(),
    );

    final result = await widget.service.add(record);
    if (!mounted) return;

    result.when(
      success: (saved) {
        Navigator.pop(context, saved);
        final efficiency = saved.efficiencyKmPerLiter;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              efficiency == null
                  // 出せないものを 0 と書かない。次に満タンにすれば出る。
                  ? '給油を記録しました'
                  : '給油を記録しました。今回の燃費は '
                      '${efficiency.toStringAsFixed(1)} km/L です',
            ),
          ),
        );
      },
      failure: (error) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = widget.lastOdometer;

    return Scaffold(
      appBar: AppBar(title: const Text('給油を記録')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  key: const Key('fuel_date_tile'),
                  leading: const Icon(Icons.event),
                  title: const Text('給油日'),
                  subtitle: Text(DateFormat('yyyy年M月d日').format(_date)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _pickDate,
                ),
              ),
              AppSpacing.verticalMd,
              TextFormField(
                key: const Key('fuel_liters_field'),
                controller: _litersController,
                enabled: !_busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: '給油量',
                  suffixText: 'L',
                  border: OutlineInputBorder(),
                ),
                validator: FuelRecord.validateLiters,
              ),
              AppSpacing.verticalMd,
              TextFormField(
                key: const Key('fuel_cost_field'),
                controller: _costController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '金額',
                  suffixText: '円',
                  border: OutlineInputBorder(),
                ),
                validator: FuelRecord.validateCost,
              ),
              AppSpacing.verticalMd,
              TextFormField(
                key: const Key('fuel_odometer_field'),
                controller: _odometerController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '走行距離（任意）',
                  suffixText: 'km',
                  border: const OutlineInputBorder(),
                  // 前回の値を出して、桁の打ち間違いに気づけるようにする。
                  helperText: last == null
                      ? '入れると燃費が出せます'
                      : '前回: ${NumberFormat('#,###').format(last)} km',
                ),
              ),
              AppSpacing.verticalMd,
              Card(
                margin: EdgeInsets.zero,
                child: SwitchListTile(
                  key: const Key('fuel_full_tank_switch'),
                  value: _isFullTank,
                  onChanged:
                      _busy ? null : (v) => setState(() => _isFullTank = v),
                  title: const Text('満タンにした'),
                  // なぜ聞かれるのかが分からないと、適当に答えられて燃費が狂う。
                  subtitle: const Text('満タンにした記録が2回そろうと燃費が出せます'),
                ),
              ),
              AppSpacing.verticalLg,
              FilledButton(
                key: const Key('fuel_save_button'),
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('記録する'),
              ),
              AppSpacing.verticalSm,
              Text(
                '入力は4つだけ。20秒で終わります。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
