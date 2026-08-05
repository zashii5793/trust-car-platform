import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/drive_log.dart';
import '../../models/vehicle.dart';
import '../../providers/drive_log_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_indicator.dart';

/// ドライブログの手動入力フォーム。
///
/// GPS記録を使わず、過去のドライブを後から手入力で記録するための画面。
/// 距離・時間・区間・メモなどを入力して完了済みのドライブログを作成する。
class ManualDriveLogScreen extends StatefulWidget {
  const ManualDriveLogScreen({super.key});

  @override
  State<ManualDriveLogScreen> createState() => _ManualDriveLogScreenState();
}

class _ManualDriveLogScreenState extends State<ManualDriveLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  String? _selectedVehicleId;
  WeatherCondition? _weather;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _orNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = context.read<AuthProvider>().firebaseUser?.uid;
    if (userId == null) {
      showErrorSnackBar(context, 'ログインが必要です');
      return;
    }

    final provider = context.read<DriveLogProvider>();
    final distanceKm = double.tryParse(_distanceController.text.trim()) ?? 0;
    final durationMinutes = int.tryParse(_durationController.text.trim()) ?? 0;

    setState(() => _isSaving = true);
    final success = await provider.addManualDriveLog(
      userId: userId,
      vehicleId: _selectedVehicleId,
      startTime: _date,
      title: _orNull(_titleController.text),
      description: _orNull(_notesController.text),
      startAddress: _orNull(_fromController.text),
      endAddress: _orNull(_toController.text),
      distanceKm: distanceKm,
      durationSeconds: durationMinutes * 60,
      weather: _weather,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      showSuccessSnackBar(context, 'ドライブログを保存しました');
      Navigator.of(context).pop(true);
    } else {
      showErrorSnackBar(context, '保存に失敗しました');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicles = context.watch<VehicleProvider>().vehicles;
    final month = _date.month.toString().padLeft(2, '0');
    final day = _date.day.toString().padLeft(2, '0');
    final dateLabel = '${_date.year}/$month/$day';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ドライブを手動で記録'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            AppTextField(
              controller: _titleController,
              labelText: 'タイトル（任意）',
              hintText: '例: 箱根ドライブ',
              prefixIcon: const Icon(Icons.title),
            ),
            AppSpacing.verticalMd,
            if (vehicles.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: _selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: '車両（任意）',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('指定なし'),
                  ),
                  ...vehicles.map(
                    (Vehicle v) => DropdownMenuItem<String?>(
                      value: v.id,
                      child: Text('${v.maker} ${v.model}'),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedVehicleId = value),
              ),
              AppSpacing.verticalMd,
            ],
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '日付',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(dateLabel),
              ),
            ),
            AppSpacing.verticalMd,
            AppTextField(
              controller: _distanceController,
              labelText: '走行距離',
              hintText: '例: 42.5',
              prefixIcon: const Icon(Icons.route),
              suffixText: 'km',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '走行距離を入力してください';
                }
                final km = double.tryParse(value.trim());
                if (km == null || km <= 0) {
                  return '正しい距離を入力してください';
                }
                return null;
              },
            ),
            AppSpacing.verticalMd,
            AppTextField.number(
              controller: _durationController,
              labelText: '所要時間（任意）',
              hintText: '例: 90',
              prefixIcon: const Icon(Icons.timer_outlined),
              suffixText: '分',
            ),
            AppSpacing.verticalMd,
            AppTextField(
              controller: _fromController,
              labelText: '出発地（任意）',
              prefixIcon: const Icon(Icons.trip_origin),
            ),
            AppSpacing.verticalMd,
            AppTextField(
              controller: _toController,
              labelText: '目的地（任意）',
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            AppSpacing.verticalMd,
            DropdownButtonFormField<WeatherCondition?>(
              // ignore: deprecated_member_use
              value: _weather,
              decoration: const InputDecoration(
                labelText: '天気（任意）',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
              items: [
                const DropdownMenuItem<WeatherCondition?>(
                  value: null,
                  child: Text('指定なし'),
                ),
                ...WeatherCondition.values.map(
                  (w) => DropdownMenuItem<WeatherCondition?>(
                    value: w,
                    child: Text('${w.emoji} ${w.displayName}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _weather = value),
            ),
            AppSpacing.verticalMd,
            AppTextField.multiline(
              controller: _notesController,
              labelText: 'メモ（任意）',
              hintText: '感想や立ち寄った場所など',
            ),
            AppSpacing.verticalLg,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? '保存中...' : '保存する'),
              ),
            ),
            AppSpacing.verticalMd,
            Text(
              'GPSを使わずに過去のドライブを記録できます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
