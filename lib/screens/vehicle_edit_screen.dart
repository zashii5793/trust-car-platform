import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../services/firebase_service.dart';
import '../core/di/service_locator.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/loading_indicator.dart';
import 'package:uuid/uuid.dart';

/// 車両編集画面
class VehicleEditScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleEditScreen({super.key, required this.vehicle});

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // 基本情報
  late TextEditingController _makerController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _gradeController;
  late TextEditingController _mileageController;

  // Phase 1.5: 識別情報
  late TextEditingController _licensePlateController;
  late TextEditingController _vinNumberController;
  late TextEditingController _modelCodeController;

  // Phase 1.5: 車検・保険
  DateTime? _inspectionExpiryDate;
  DateTime? _insuranceExpiryDate;

  // Phase 1.5: 詳細情報
  late TextEditingController _colorController;
  late TextEditingController _engineDisplacementController;
  FuelType? _selectedFuelType;
  DateTime? _purchaseDate;

  Uint8List? _newImageBytes;
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _showAdvancedFields = false;

  // Service (DI経由)
  FirebaseService get _firebaseService => sl.get<FirebaseService>();

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;

    // 基本情報
    _makerController = TextEditingController(text: v.maker);
    _modelController = TextEditingController(text: v.model);
    _yearController = TextEditingController(text: v.year.toString());
    _gradeController = TextEditingController(text: v.grade);
    _mileageController = TextEditingController(text: v.mileage.toString());

    // Phase 1.5: 識別情報
    _licensePlateController = TextEditingController(text: v.licensePlate ?? '');
    _vinNumberController = TextEditingController(text: v.vinNumber ?? '');
    _modelCodeController = TextEditingController(text: v.modelCode ?? '');

    // Phase 1.5: 車検・保険
    _inspectionExpiryDate = v.inspectionExpiryDate;
    _insuranceExpiryDate = v.insuranceExpiryDate;

    // Phase 1.5: 詳細情報
    _colorController = TextEditingController(text: v.color ?? '');
    _engineDisplacementController = TextEditingController(
      text: v.engineDisplacement?.toString() ?? '',
    );
    _selectedFuelType = v.fuelType;
    _purchaseDate = v.purchaseDate;

    // 詳細情報が既に設定されている場合は展開
    if (v.licensePlate != null ||
        v.vinNumber != null ||
        v.modelCode != null ||
        v.color != null ||
        v.engineDisplacement != null ||
        v.fuelType != null ||
        v.purchaseDate != null) {
      _showAdvancedFields = true;
    }

    // 変更検知
    _makerController.addListener(_onFieldChanged);
    _modelController.addListener(_onFieldChanged);
    _yearController.addListener(_onFieldChanged);
    _gradeController.addListener(_onFieldChanged);
    _mileageController.addListener(_onFieldChanged);
    _licensePlateController.addListener(_onFieldChanged);
    _vinNumberController.addListener(_onFieldChanged);
    _modelCodeController.addListener(_onFieldChanged);
    _colorController.addListener(_onFieldChanged);
    _engineDisplacementController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final v = widget.vehicle;
    final changed = _makerController.text != v.maker ||
        _modelController.text != v.model ||
        _yearController.text != v.year.toString() ||
        _gradeController.text != v.grade ||
        _mileageController.text != v.mileage.toString() ||
        _licensePlateController.text != (v.licensePlate ?? '') ||
        _vinNumberController.text != (v.vinNumber ?? '') ||
        _modelCodeController.text != (v.modelCode ?? '') ||
        _colorController.text != (v.color ?? '') ||
        _engineDisplacementController.text != (v.engineDisplacement?.toString() ?? '') ||
        _selectedFuelType != v.fuelType ||
        _inspectionExpiryDate != v.inspectionExpiryDate ||
        _insuranceExpiryDate != v.insuranceExpiryDate ||
        _purchaseDate != v.purchaseDate ||
        _newImageBytes != null;

    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  @override
  void dispose() {
    _makerController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _gradeController.dispose();
    _mileageController.dispose();
    _licensePlateController.dispose();
    _vinNumberController.dispose();
    _modelCodeController.dispose();
    _colorController.dispose();
    _engineDisplacementController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _newImageBytes = bytes;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectDate({
    required String title,
    required DateTime? currentDate,
    required ValueChanged<DateTime?> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
    bool allowClear = true,
  }) async {
    if (allowClear && currentDate != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text('日付を変更しますか、それともクリアしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'clear'),
              child: const Text('クリア'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'change'),
              child: const Text('変更'),
            ),
          ],
        ),
      );

      if (action == 'clear') {
        onSelected(null);
        _onFieldChanged();
        return;
      } else if (action != 'change') {
        return;
      }
    }

    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      helpText: title,
    );
    if (picked != null) {
      onSelected(picked);
      _onFieldChanged();
    }
  }

  Future<void> _updateVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ナンバープレート重複チェック（変更があった場合のみ）
      if (_licensePlateController.text.isNotEmpty &&
          _licensePlateController.text != widget.vehicle.licensePlate) {
        final exists = await Provider.of<VehicleProvider>(context, listen: false)
            .isLicensePlateExists(
          _licensePlateController.text,
          excludeVehicleId: widget.vehicle.id,
        );
        if (exists && mounted) {
          setState(() {
            _isLoading = false;
          });
          showErrorSnackBar(context, 'このナンバープレートは既に登録されています');
          return;
        }
      }

      String? imageUrl = widget.vehicle.imageUrl;

      // 新しい画像があればアップロード
      if (_newImageBytes != null) {
        final uuid = const Uuid().v4();
        final uploadResult = await _firebaseService.uploadImageBytes(
          _newImageBytes!,
          'vehicles/$uuid.jpg',
        );
        imageUrl = uploadResult.getOrThrow();
      }

      // 更新データを作成
      final updatedVehicle = Vehicle(
        id: widget.vehicle.id,
        userId: widget.vehicle.userId,
        maker: _makerController.text,
        model: _modelController.text,
        year: int.parse(_yearController.text),
        grade: _gradeController.text,
        mileage: int.parse(_mileageController.text),
        imageUrl: imageUrl,
        createdAt: widget.vehicle.createdAt,
        updatedAt: DateTime.now(),
        // Phase 1.5: 識別情報
        licensePlate: _licensePlateController.text.isEmpty
            ? null
            : _licensePlateController.text,
        vinNumber: _vinNumberController.text.isEmpty
            ? null
            : _vinNumberController.text,
        modelCode: _modelCodeController.text.isEmpty
            ? null
            : _modelCodeController.text,
        // Phase 1.5: 車検・保険
        inspectionExpiryDate: _inspectionExpiryDate,
        insuranceExpiryDate: _insuranceExpiryDate,
        // Phase 1.5: 詳細情報
        color: _colorController.text.isEmpty ? null : _colorController.text,
        engineDisplacement: _engineDisplacementController.text.isEmpty
            ? null
            : int.tryParse(_engineDisplacementController.text),
        fuelType: _selectedFuelType,
        purchaseDate: _purchaseDate,
      );

      // 車両を更新
      if (!mounted) return;
      final success = await Provider.of<VehicleProvider>(context, listen: false)
          .updateVehicle(widget.vehicle.id, updatedVehicle);

      if (success && mounted) {
        showSuccessSnackBar(context, '車両情報を更新しました');
        Navigator.pop(context, updatedVehicle);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '更新に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteVehicle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('車両を削除'),
        content: Text(
          '${widget.vehicle.maker} ${widget.vehicle.model}を削除しますか？\n'
          'この操作は取り消せません。関連する整備記録も削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final success = await Provider.of<VehicleProvider>(context, listen: false)
          .deleteVehicle(widget.vehicle.id);

      if (success && mounted) {
        showSuccessSnackBar(context, '車両を削除しました');
        // 2つ前の画面（ホーム）に戻る
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '削除に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('変更を破棄しますか？'),
        content: const Text('保存されていない変更があります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未設定';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('車両編集'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteVehicle,
              tooltip: '削除',
            ),
          ],
        ),
        body: AppLoadingOverlay(
          isLoading: _isLoading,
          message: '処理中...',
          child: SingleChildScrollView(
            padding: AppSpacing.paddingScreen,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 画像選択
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.backgroundLight,
                        borderRadius: AppSpacing.borderRadiusMd,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: _buildImageContent(isDark, theme),
                    ),
                  ),
                  AppSpacing.verticalLg,

                  // === 基本情報セクション ===
                  _buildSectionHeader(theme, '基本情報', Icons.directions_car),
                  AppSpacing.verticalXxs,
                  Text(
                    '* は必須項目です',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  AppSpacing.verticalSm,

                  // メーカー
                  AppTextField(
                    controller: _makerController,
                    labelText: 'メーカー *',
                    hintText: '例: トヨタ',
                    prefixIcon: const Icon(Icons.business),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'メーカーを入力してください';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.verticalMd,

                  // 車種
                  AppTextField(
                    controller: _modelController,
                    labelText: '車種 *',
                    hintText: '例: RAV4',
                    prefixIcon: const Icon(Icons.directions_car),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '車種を入力してください';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.verticalMd,

                  // 年式とグレード（横並び）
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField.number(
                          controller: _yearController,
                          labelText: '年式 *',
                          hintText: '例: 2023',
                          prefixIcon: const Icon(Icons.calendar_today),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '年式を入力';
                            }
                            final year = int.tryParse(value);
                            if (year == null ||
                                year < 1900 ||
                                year > DateTime.now().year + 1) {
                              return '正しい年式';
                            }
                            return null;
                          },
                        ),
                      ),
                      AppSpacing.horizontalSm,
                      Expanded(
                        child: AppTextField(
                          controller: _gradeController,
                          labelText: 'グレード *',
                          hintText: '例: G',
                          prefixIcon: const Icon(Icons.star_outline),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'グレードを入力';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalMd,

                  // 走行距離
                  AppTextField.number(
                    controller: _mileageController,
                    labelText: '走行距離 *',
                    hintText: '例: 24500',
                    prefixIcon: const Icon(Icons.speed),
                    suffixText: 'km',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '走行距離を入力してください';
                      }
                      final mileage = int.tryParse(value);
                      if (mileage == null || mileage < 0) {
                        return '正しい走行距離を入力してください';
                      }
                      // 走行距離の上限チェック（200万kmを超えることはほぼない）
                      if (mileage > 2000000) {
                        return '走行距離が大きすぎます（200万km以下）';
                      }
                      // 走行距離の減少チェック（P0-3: 整合性チェック）
                      if (mileage < widget.vehicle.mileage) {
                        return '走行距離は前回(${widget.vehicle.mileage}km)より小さくできません';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.verticalLg,

                  // === 車検・保険セクション ===
                  _buildSectionHeader(theme, '車検・保険', Icons.verified, isImportant: true),
                  AppSpacing.verticalSm,

                  // 車検満了日
                  _buildDatePickerTile(
                    context: context,
                    title: '車検満了日',
                    icon: Icons.event_available,
                    date: _inspectionExpiryDate,
                    hint: '車検証に記載の有効期間の満了日',
                    isWarning: _inspectionExpiryDate == null,
                    onTap: () => _selectDate(
                      title: '車検満了日を選択',
                      currentDate: _inspectionExpiryDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                      onSelected: (date) => setState(() => _inspectionExpiryDate = date),
                    ),
                  ),
                  AppSpacing.verticalSm,

                  // 自賠責保険期限
                  _buildDatePickerTile(
                    context: context,
                    title: '自賠責保険期限',
                    icon: Icons.shield,
                    date: _insuranceExpiryDate,
                    hint: '自賠責保険証明書の期限',
                    onTap: () => _selectDate(
                      title: '自賠責保険期限を選択',
                      currentDate: _insuranceExpiryDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                      onSelected: (date) => setState(() => _insuranceExpiryDate = date),
                    ),
                  ),
                  AppSpacing.verticalLg,

                  // === 詳細情報（折りたたみ） ===
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showAdvancedFields = !_showAdvancedFields;
                      });
                    },
                    borderRadius: AppSpacing.borderRadiusSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvancedFields
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: theme.colorScheme.primary,
                          ),
                          AppSpacing.horizontalXs,
                          Text(
                            '詳細情報を${_showAdvancedFields ? '隠す' : '表示'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showAdvancedFields) ...[
                    AppSpacing.verticalMd,

                    // === 識別情報セクション ===
                    _buildSectionHeader(theme, '識別情報', Icons.badge),
                    AppSpacing.verticalSm,

                    // ナンバープレート
                    AppTextField(
                      controller: _licensePlateController,
                      labelText: 'ナンバープレート',
                      hintText: '例: 品川 300 あ 12-34',
                      prefixIcon: const Icon(Icons.confirmation_number),
                    ),
                    AppSpacing.verticalMd,

                    // 車台番号と型式（横並び）
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _vinNumberController,
                            labelText: '車台番号',
                            hintText: '例: ZVW50-1234567',
                            prefixIcon: const Icon(Icons.pin),
                          ),
                        ),
                        AppSpacing.horizontalSm,
                        Expanded(
                          child: AppTextField(
                            controller: _modelCodeController,
                            labelText: '型式',
                            hintText: '例: DBA-ZVW50',
                            prefixIcon: const Icon(Icons.text_fields),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalLg,

                    // === 車両詳細セクション ===
                    _buildSectionHeader(theme, '車両詳細', Icons.info_outline),
                    AppSpacing.verticalSm,

                    // 車体色と排気量（横並び）
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _colorController,
                            labelText: '車体色',
                            hintText: '例: ホワイトパールクリスタルシャイン',
                            prefixIcon: const Icon(Icons.palette),
                          ),
                        ),
                        AppSpacing.horizontalSm,
                        Expanded(
                          child: AppTextField.number(
                            controller: _engineDisplacementController,
                            labelText: '排気量',
                            hintText: '例: 1800',
                            prefixIcon: const Icon(Icons.local_gas_station),
                            suffixText: 'cc',
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalMd,

                    // 燃料タイプ
                    _buildFuelTypeSelector(theme),
                    AppSpacing.verticalMd,

                    // 購入日
                    _buildDatePickerTile(
                      context: context,
                      title: '購入日・納車日',
                      icon: Icons.shopping_cart,
                      date: _purchaseDate,
                      hint: '購入または納車された日',
                      onTap: () => _selectDate(
                        title: '購入日を選択',
                        currentDate: _purchaseDate,
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                        onSelected: (date) => setState(() => _purchaseDate = date),
                      ),
                    ),
                  ],

                  AppSpacing.verticalXl,

                  // 更新ボタン
                  AppButton.primary(
                    label: '更新する',
                    onPressed: _hasChanges ? _updateVehicle : null,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                    icon: Icons.save,
                  ),

                  // 車検日未設定の警告
                  if (_inspectionExpiryDate == null) ...[
                    AppSpacing.verticalMd,
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.borderRadiusSm,
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          AppSpacing.horizontalSm,
                          Expanded(
                            child: Text(
                              '車検満了日を登録すると、期限が近づいた時に通知を受け取れます',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  AppSpacing.verticalLg,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon, {bool isImportant = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isImportant ? Colors.orange : theme.colorScheme.primary,
        ),
        AppSpacing.horizontalXs,
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isImportant ? Colors.orange : null,
          ),
        ),
        if (isImportant) ...[
          AppSpacing.horizontalXs,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '重要',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePickerTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
    String? hint,
    bool isWarning = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(
            color: isWarning
                ? Colors.orange.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkTextTertiary : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isWarning ? Colors.orange : theme.colorScheme.primary,
            ),
            AppSpacing.horizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hint != null && date == null)
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _formatDate(date),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: date == null
                    ? (isWarning ? Colors.orange : theme.textTheme.bodySmall?.color)
                    : theme.colorScheme.primary,
              ),
            ),
            AppSpacing.horizontalXs,
            Icon(
              Icons.chevron_right,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '燃料タイプ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalXs,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: FuelType.values.map((type) {
            final isSelected = _selectedFuelType == type;
            return ChoiceChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFuelType = selected ? type : null;
                  _onFieldChanged();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageContent(bool isDark, ThemeData theme) {
    // 新しい画像が選択されている場合
    if (_newImageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusMd,
            child: Image.memory(
              _newImageBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: AppSpacing.borderRadiusXs,
              ),
              child: const Text(
                '新しい画像',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }

    // 既存の画像がある場合
    if (widget.vehicle.imageUrl != null && widget.vehicle.imageUrl!.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusMd,
            child: Image.network(
              widget.vehicle.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _buildPlaceholder(isDark, theme),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: AppSpacing.borderRadiusXs,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '変更',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 画像がない場合
    return _buildPlaceholder(isDark, theme);
  }

  Widget _buildPlaceholder(bool isDark, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: AppSpacing.iconXl,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
        AppSpacing.verticalXs,
        Text(
          '車両の写真を追加',
          style: theme.textTheme.bodyMedium,
        ),
        AppSpacing.verticalXxs,
        Text(
          'タップして選択',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
