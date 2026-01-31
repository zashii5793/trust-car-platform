import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_record.dart';
import '../providers/maintenance_provider.dart';
import '../services/firebase_service.dart';
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
  final _partNumberController = TextEditingController();
  final _partManufacturerController = TextEditingController();

  MaintenanceType _selectedType = MaintenanceType.repair;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _showAllTypes = false;

  // よく使うメンテナンスタイプ（初期表示）
  static const _commonTypes = [
    MaintenanceType.oilChange,
    MaintenanceType.legalInspection12,
    MaintenanceType.carInspection,
    MaintenanceType.tireChange,
    MaintenanceType.repair,
    MaintenanceType.partsReplacement,
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _shopNameController.dispose();
    _mileageController.dispose();
    _partNumberController.dispose();
    _partManufacturerController.dispose();
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
        // Phase 1.5 追加フィールド
        partNumber: _partNumberController.text.isEmpty
            ? null
            : _partNumberController.text,
        partManufacturer: _partManufacturerController.text.isEmpty
            ? null
            : _partManufacturerController.text,
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

  void _onTypeSelected(MaintenanceType type) {
    setState(() {
      _selectedType = type;
      // タイプに応じてタイトルを自動設定（空の場合のみ）
      if (_titleController.text.isEmpty) {
        _titleController.text = type.displayName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typesToShow = _showAllTypes ? MaintenanceType.values : _commonTypes;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'メンテナンスタイプ',
                      style: theme.textTheme.labelLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllTypes = !_showAllTypes;
                        });
                      },
                      child: Text(_showAllTypes ? '簡易表示' : 'すべて表示'),
                    ),
                  ],
                ),
                AppSpacing.verticalXs,

                if (_showAllTypes)
                  // カテゴリ別表示
                  ...MaintenanceType.groupedTypes.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: entry.value.map((type) {
                            return _buildTypeChip(type);
                          }).toList(),
                        ),
                      ],
                    );
                  })
                else
                  // よく使うタイプのみ表示
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: typesToShow.map((type) {
                      return _buildTypeChip(type);
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

                // 部品情報（消耗品交換などで表示）
                if (_selectedType.isPeriodicMaintenance) ...[
                  Text(
                    '部品情報（任意）',
                    style: theme.textTheme.labelLarge,
                  ),
                  AppSpacing.verticalXs,
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _partManufacturerController,
                          labelText: 'メーカー',
                          hintText: '例: WAKO\'S',
                        ),
                      ),
                      AppSpacing.horizontalSm,
                      Expanded(
                        child: AppTextField(
                          controller: _partNumberController,
                          labelText: '品番',
                          hintText: '例: E250',
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalMd,
                ],

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

  Widget _buildTypeChip(MaintenanceType type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type.icon,
            size: 16,
            color: isSelected ? Colors.white : type.color,
          ),
          AppSpacing.horizontalXs,
          Text(type.displayName),
        ],
      ),
      selected: isSelected,
      selectedColor: type.color,
      onSelected: (selected) {
        if (selected) {
          _onTypeSelected(type);
        }
      },
    );
  }
}
