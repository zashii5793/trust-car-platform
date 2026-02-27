import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_record.dart';
import '../providers/maintenance_provider.dart';
import '../services/firebase_service.dart';
import '../services/invoice_ocr_service.dart';
import '../core/di/service_locator.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/loading_indicator.dart';
import 'document_scanner_screen.dart';
import 'invoice_result_screen.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final String vehicleId;
  final int? currentVehicleMileage; // 現在の車両走行距離（整合性チェック用）
  final MaintenanceRecord? existingRecord; // null = 新規, non-null = 編集

  const AddMaintenanceScreen({
    super.key,
    required this.vehicleId,
    this.currentVehicleMileage,
    this.existingRecord,
  });

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
  bool _isOcrProcessing = false;

  bool get _isEditMode => widget.existingRecord != null;

  // OCRサービス (DI経由)
  InvoiceOcrService get _invoiceOcrService => sl.get<InvoiceOcrService>();
  FirebaseService get _firebaseService => sl.get<FirebaseService>();

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
  void initState() {
    super.initState();
    final record = widget.existingRecord;
    if (record != null) {
      _selectedType = record.type;
      _titleController.text = record.title;
      _selectedDate = record.date;
      _costController.text = record.cost.toString();
      if (record.shopName != null) _shopNameController.text = record.shopName!;
      if (record.mileageAtService != null) {
        _mileageController.text = record.mileageAtService.toString();
      }
      if (record.partNumber != null) _partNumberController.text = record.partNumber!;
      if (record.partManufacturer != null) {
        _partManufacturerController.text = record.partManufacturer!;
      }
      if (record.description != null) _descriptionController.text = record.description!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _shopNameController.dispose();
    _mileageController.dispose();
    _partNumberController.dispose();
    _partManufacturerController.dispose();
    _invoiceOcrService.dispose();
    super.dispose();
  }

  /// 請求書をスキャンしてOCR処理
  Future<void> _scanInvoice() async {
    final imageFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentScannerScreen(
          documentType: DocumentType.invoice,
        ),
      ),
    );

    if (imageFile == null || !mounted) return;

    setState(() {
      _isOcrProcessing = true;
    });

    try {
      final result = await _invoiceOcrService.extractFromImage(imageFile);

      if (!mounted) return;

      result.when(
        success: (ocrData) async {
          final registrationData = await Navigator.push<MaintenanceRegistrationData>(
            context,
            MaterialPageRoute(
              builder: (context) => InvoiceResultScreen(
                imageFile: imageFile,
                ocrData: ocrData,
              ),
            ),
          );

          if (registrationData != null && mounted) {
            _applyOcrData(registrationData);
          }
        },
        failure: (error) {
          showErrorSnackBar(context, error.userMessage);
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOcrProcessing = false;
        });
      }
    }
  }

  /// OCRデータをフォームに反映
  void _applyOcrData(MaintenanceRegistrationData data) {
    setState(() {
      _selectedType = data.type;
      _titleController.text = data.type.displayName;
      _selectedDate = data.date;

      if (data.cost != null) {
        _costController.text = data.cost.toString();
      }
      if (data.mileage != null) {
        _mileageController.text = data.mileage.toString();
      }
      if (data.shopName != null) {
        _shopNameController.text = data.shopName!;
      }
      if (data.description != null) {
        _descriptionController.text = data.description!;
      }
    });

    showSuccessSnackBar(context, '請求書の情報を読み取りました');
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final existing = widget.existingRecord;
      final record = MaintenanceRecord(
        id: existing?.id ?? '',
        vehicleId: widget.vehicleId,
        userId: existing?.userId ?? _firebaseService.currentUserId ?? '',
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
        createdAt: existing?.createdAt ?? DateTime.now(),
        partNumber: _partNumberController.text.isEmpty
            ? null
            : _partNumberController.text,
        partManufacturer: _partManufacturerController.text.isEmpty
            ? null
            : _partManufacturerController.text,
      );

      final provider =
          Provider.of<MaintenanceProvider>(context, listen: false);
      final bool success;
      if (_isEditMode) {
        success = await provider.updateMaintenanceRecord(existing!.id, record);
      } else {
        success = await provider.addMaintenanceRecord(record);
      }

      if (success && mounted) {
        showSuccessSnackBar(
          context,
          _isEditMode ? 'メンテナンス履歴を更新しました' : 'メンテナンス履歴を追加しました',
        );
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
        title: Text(_isEditMode ? 'メンテナンス履歴を編集' : 'メンテナンス履歴を追加'),
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
                // 請求書スキャンボタン
                _buildOcrScanButton(theme),
                AppSpacing.verticalLg,

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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null; // 任意フィールド
                    }
                    final mileage = int.tryParse(value);
                    if (mileage == null || mileage < 0) {
                      return '正しい走行距離を入力してください';
                    }
                    // 走行距離の上限チェック
                    if (mileage > 2000000) {
                      return '走行距離が大きすぎます（200万km以下）';
                    }
                    // 現在の車両走行距離より大きい場合は警告（将来の記録は不可）
                    if (widget.currentVehicleMileage != null &&
                        mileage > widget.currentVehicleMileage!) {
                      return '車両の現在走行距離(${widget.currentVehicleMileage}km)を超えています';
                    }
                    return null;
                  },
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
                  label: _isEditMode ? '更新する' : '保存する',
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

  /// 請求書スキャンボタン
  Widget _buildOcrScanButton(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isOcrProcessing ? null : _scanInvoice,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isOcrProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.receipt_long,
                          color: AppColors.primary,
                          size: 24,
                        ),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '請求書をスキャン',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      AppSpacing.verticalXxs,
                      Text(
                        '請求書を撮影して自動入力',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '便利',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AppSpacing.horizontalSm,
                Icon(
                  Icons.chevron_right,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
