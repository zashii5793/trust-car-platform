import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/maintenance_preferences.dart';
import '../../models/vehicle.dart';
import '../../services/maintenance_preference_service.dart';
import '../../services/maintenance_schedule_service.dart';

/// 交換目安（メンテナンス間隔）の車両ごとカスタマイズ画面。
///
/// 標準値を表示しつつ、乗り方に合わせてユーザーが上書きできる。
/// 空欄＝標準値を使用。
class MaintenanceIntervalSettingsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const MaintenanceIntervalSettingsScreen({super.key, required this.vehicle});

  @override
  State<MaintenanceIntervalSettingsScreen> createState() =>
      _MaintenanceIntervalSettingsScreenState();
}

class _MaintenanceIntervalSettingsScreenState
    extends State<MaintenanceIntervalSettingsScreen> {
  final _numberFormat = NumberFormat('#,###');
  late final MaintenancePreferenceService _service;
  late final List<ScheduledMaintenance> _items;

  // type.name -> controllers
  final Map<String, TextEditingController> _kmControllers = {};
  final Map<String, TextEditingController> _monthControllers = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = sl.get<MaintenancePreferenceService>();
    // 標準スケジュール（上書きなし）を項目の母集合にする
    _items =
        const MaintenanceScheduleService().generateSchedule(widget.vehicle);
    for (final item in _items) {
      _kmControllers[item.type.name] = TextEditingController();
      _monthControllers[item.type.name] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _kmControllers.values) {
      c.dispose();
    }
    for (final c in _monthControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final result =
        await _service.getPreferences(widget.vehicle.id, widget.vehicle.userId);
    if (!mounted) return;
    final prefs = result.valueOrNull;
    if (prefs != null) {
      for (final item in _items) {
        final ov = prefs.forType(item.type);
        if (ov?.intervalKm != null) {
          _kmControllers[item.type.name]!.text = ov!.intervalKm.toString();
        }
        if (ov?.intervalMonths != null) {
          _monthControllers[item.type.name]!.text =
              ov!.intervalMonths.toString();
        }
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    var prefs =
        MaintenancePreferences.empty(widget.vehicle.id, widget.vehicle.userId);
    for (final item in _items) {
      final km = int.tryParse(_kmControllers[item.type.name]!.text.trim());
      final months =
          int.tryParse(_monthControllers[item.type.name]!.text.trim());
      final override = IntervalOverride(intervalKm: km, intervalMonths: months);
      if (!override.isEmpty) {
        prefs = prefs.withOverride(item.type, override);
      }
    }
    final result = await _service.savePreferences(prefs);
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('交換目安を保存しました')),
        );
        Navigator.pop(context, true);
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  void _resetItem(ScheduledMaintenance item) {
    setState(() {
      _kmControllers[item.type.name]!.clear();
      _monthControllers[item.type.name]!.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('交換目安の設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.surfaceContainerHighest,
                  padding: AppSpacing.paddingScreen,
                  child: Text(
                    '交換目安は乗り方によって変わります。標準値を目安に、'
                    'お客様の使い方に合わせて上書きできます。'
                    '空欄のままなら標準値が使われます。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: AppSpacing.paddingScreen,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: AppSpacing.lg),
                    itemBuilder: (_, i) => _buildItem(_items[i]),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中...' : '保存する'),
                ),
              ),
            ),
    );
  }

  Widget _buildItem(ScheduledMaintenance item) {
    final theme = Theme.of(context);
    final stdKm = item.intervalKm != null
        ? '${_numberFormat.format(item.intervalKm)}km'
        : null;
    final stdMonths =
        item.intervalMonths != null ? '${item.intervalMonths}ヶ月' : null;
    final stdText = [stdKm, stdMonths].whereType<String>().join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.type.icon, size: 18, color: item.type.color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                item.type.displayName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => _resetItem(item),
              child: const Text('標準に戻す'),
            ),
          ],
        ),
        Text(
          '標準: ${stdText.isEmpty ? '—' : stdText}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (item.intervalKm != null)
              Expanded(
                child: TextField(
                  controller: _kmControllers[item.type.name],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '距離',
                    suffixText: 'km',
                    hintText: item.intervalKm.toString(),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            if (item.intervalKm != null && item.intervalMonths != null)
              const SizedBox(width: AppSpacing.sm),
            if (item.intervalMonths != null)
              Expanded(
                child: TextField(
                  controller: _monthControllers[item.type.name],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '期間',
                    suffixText: 'ヶ月',
                    hintText: item.intervalMonths.toString(),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
