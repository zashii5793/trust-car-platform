import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_record.dart';
import '../providers/maintenance_provider.dart';
import '../services/firebase_service.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/loading_indicator.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final String vehicleId;

  const AddMaintenanceScreen({super.key, required this.vehicleId});

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _mileageController = TextEditingController();

  MaintenanceType _selectedType = MaintenanceType.repair;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _shopNameController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = FirebaseService();

      final record = MaintenanceRecord(
        id: '',
        vehicleId: widget.vehicleId,
        userId: firebaseService.currentUserId ?? '',
        type: _selectedType,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        cost: int.parse(_costController.text),
        shopName:
            _shopNameController.text.isEmpty ? null : _shopNameController.text,
        date: _selectedDate,
        mileageAtService: _mileageController.text.isEmpty
            ? null
            : int.parse(_mileageController.text),
        createdAt: DateTime.now(),
      );

      final success =
          await Provider.of<MaintenanceProvider>(context, listen: false)
              .addMaintenanceRecord(record);

      if (success && mounted) {
        showSuccessSnackBar(context, 'メンテナンス履歴を追加しました');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '保存に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getTypeColor(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.repair:
        return AppColors.maintenanceRepair;
      case MaintenanceType.inspection:
        return AppColors.maintenanceInspection;
      case MaintenanceType.partsReplacement:
        return AppColors.maintenanceParts;
      case MaintenanceType.carInspection:
        return AppColors.maintenanceCarInspection;
    }
  }

  IconData _getTypeIcon(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.repair:
        return Icons.build;
      case MaintenanceType.inspection:
        return Icons.search;
      case MaintenanceType.partsReplacement:
        return Icons.settings;
      case MaintenanceType.carInspection:
        return Icons.verified;
    }
  }

  String _getTypeDisplayName(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.repair:
        return '修理';
      case MaintenanceType.inspection:
        return '点検';
      case MaintenanceType.partsReplacement:
        return '消耗品交換';
      case MaintenanceType.carInspection:
        return '車検';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メンテナンス履歴を追加'),
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        message: '保存中...',
        child: SingleChildScrollView(
          padding: AppSpacing.paddingScreen,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // タイプ選択
                Text(
                  'メンテナンスタイプ',
                  style: theme.textTheme.labelLarge,
                ),
                AppSpacing.verticalXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: MaintenanceType.values.map((type) {
                    final isSelected = _selectedType == type;
                    final color = _getTypeColor(type);
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getTypeIcon(type),
                            size: 16,
                            color: isSelected ? Colors.white : color,
                          ),
                          AppSpacing.horizontalXs,
                          Text(_getTypeDisplayName(type)),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: color,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = type;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                AppSpacing.verticalLg,

                // タイトル
                AppTextField(
                  controller: _titleController,
                  labelText: 'タイトル',
                  hintText: '例: 12ヶ月法定点検',
                  prefixIcon: const Icon(Icons.title),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'タイトルを入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // 日付
                AppDateField(
                  value: _selectedDate,
                  labelText: '実施日',
                  onChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  lastDate: DateTime.now(),
                ),
                AppSpacing.verticalMd,

                // 費用
                AppTextField.number(
                  controller: _costController,
                  labelText: '費用',
                  hintText: '例: 25000',
                  prefixText: '¥',
                  prefixIcon: const Icon(Icons.currency_yen),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '費用を入力してください';
                    }
                    final cost = int.tryParse(value);
                    if (cost == null || cost < 0) {
                      return '正しい金額を入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // 実施工場
                AppTextField(
                  controller: _shopNameController,
                  labelText: '実施工場（任意）',
                  hintText: '例: トヨタカローラ福岡',
                  prefixIcon: const Icon(Icons.store),
                ),
                AppSpacing.verticalMd,

                // 走行距離
                AppTextField.number(
                  controller: _mileageController,
                  labelText: '実施時の走行距離（任意）',
                  hintText: '例: 24500',
                  prefixIcon: const Icon(Icons.speed),
                  suffixText: 'km',
                ),
                AppSpacing.verticalMd,

                // 説明
                AppTextField.multiline(
                  controller: _descriptionController,
                  labelText: 'メモ（任意）',
                  hintText: '詳細な内容を記入できます',
                ),
                AppSpacing.verticalXl,

                // 保存ボタン
                AppButton.primary(
                  label: '保存する',
                  onPressed: _saveRecord,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  icon: Icons.check,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
