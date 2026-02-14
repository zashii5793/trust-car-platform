import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../models/vehicle_master.dart';
import '../providers/vehicle_provider.dart';
import '../services/firebase_service.dart';
import '../services/vehicle_certificate_ocr_service.dart';
import '../services/vehicle_master_service.dart';
import '../core/di/service_locator.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/vehicle/vehicle_selector_fields.dart';
import 'package:uuid/uuid.dart';
import 'document_scanner_screen.dart';
import 'vehicle_certificate_result_screen.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // 基本情報 (選択式)
  VehicleMaker? _selectedMaker;
  VehicleModel? _selectedModel;
  VehicleGrade? _selectedGrade;
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();

  // Phase 1.5: 識別情報
  final _licensePlateController = TextEditingController();
  final _vinNumberController = TextEditingController();
  final _modelCodeController = TextEditingController();

  // Phase 1.5: 車検・保険
  DateTime? _inspectionExpiryDate;
  DateTime? _insuranceExpiryDate;

  // Phase 1.5: 詳細情報
  final _colorController = TextEditingController();
  final _engineDisplacementController = TextEditingController();
  FuelType? _selectedFuelType;
  DateTime? _purchaseDate;

  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _showAdvancedFields = false;
  bool _isOcrProcessing = false;

  // OCRサービス (DI経由)
  VehicleCertificateOcrService get _ocrService => sl.get<VehicleCertificateOcrService>();
  FirebaseService get _firebaseService => sl.get<FirebaseService>();
  VehicleMasterService get _masterService => sl.get<VehicleMasterService>();

  @override
  void dispose() {
    _yearController.dispose();
    _mileageController.dispose();
    _licensePlateController.dispose();
    _vinNumberController.dispose();
    _modelCodeController.dispose();
    _colorController.dispose();
    _engineDisplacementController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  /// 車検証をスキャンしてOCR処理
  Future<void> _scanVehicleCertificate() async {
    // カメラ/ギャラリーから画像を取得
    final imageFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentScannerScreen(
          documentType: DocumentType.vehicleCertificate,
        ),
      ),
    );

    if (imageFile == null || !mounted) return;

    setState(() {
      _isOcrProcessing = true;
    });

    try {
      // OCR処理
      final result = await _ocrService.extractFromImage(imageFile);

      if (!mounted) return;

      result.when(
        success: (ocrData) async {
          // 結果確認画面へ遷移
          final registrationData = await Navigator.push<VehicleRegistrationData>(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleCertificateResultScreen(
                imageFile: imageFile,
                ocrData: ocrData,
              ),
            ),
          );

          if (registrationData != null && mounted) {
            // フォームにデータを反映
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
  Future<void> _applyOcrData(VehicleRegistrationData data) async {
    // Try to match OCR maker name to master data
    if (data.maker.isNotEmpty) {
      final makersResult = await _masterService.getMakers();
      makersResult.when(
        success: (makers) {
          final matchedMaker = _findMatchingMaker(makers, data.maker);
          if (matchedMaker != null) {
            _selectedMaker = matchedMaker;
            // Try to load and match model
            _loadAndMatchModel(data.model);
          }
        },
        failure: (_) {},
      );
    }

    setState(() {
      if (data.year != null) {
        _yearController.text = data.year.toString();
      }
      if (data.licensePlate != null) {
        _licensePlateController.text = data.licensePlate!;
      }
      if (data.vinNumber != null) {
        _vinNumberController.text = data.vinNumber!;
      }
      if (data.modelCode != null) {
        _modelCodeController.text = data.modelCode!;
      }
      if (data.inspectionExpiryDate != null) {
        _inspectionExpiryDate = data.inspectionExpiryDate;
      }
      if (data.engineDisplacement != null) {
        _engineDisplacementController.text = data.engineDisplacement.toString();
      }
      if (data.fuelType != null) {
        _selectedFuelType = data.fuelType;
      }
      if (data.color != null) {
        _colorController.text = data.color!;
      }

      // 詳細フィールドにデータがある場合は展開
      if (data.color != null ||
          data.engineDisplacement != null ||
          data.fuelType != null) {
        _showAdvancedFields = true;
      }
    });

    // 成功メッセージ
    if (mounted) {
      showSuccessSnackBar(context, '車検証の情報を読み取りました');
    }
  }

  /// Find matching maker from OCR text
  VehicleMaker? _findMatchingMaker(List<VehicleMaker> makers, String ocrText) {
    final lowerText = ocrText.toLowerCase();
    for (final maker in makers) {
      if (maker.name.toLowerCase().contains(lowerText) ||
          maker.nameEn.toLowerCase().contains(lowerText) ||
          lowerText.contains(maker.name.toLowerCase()) ||
          lowerText.contains(maker.nameEn.toLowerCase())) {
        return maker;
      }
    }
    return null;
  }

  /// Load models for maker and try to match OCR model name
  Future<void> _loadAndMatchModel(String ocrModelName) async {
    if (_selectedMaker == null || ocrModelName.isEmpty) return;

    final modelsResult = await _masterService.getModelsForMaker(_selectedMaker!.id);
    modelsResult.when(
      success: (models) {
        final lowerText = ocrModelName.toLowerCase();
        for (final model in models) {
          if (model.name.toLowerCase().contains(lowerText) ||
              (model.nameEn?.toLowerCase().contains(lowerText) ?? false) ||
              lowerText.contains(model.name.toLowerCase())) {
            if (mounted) {
              setState(() {
                _selectedModel = model;
              });
            }
            break;
          }
        }
      },
      failure: (_) {},
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _selectDate({
    required String title,
    required DateTime? currentDate,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      helpText: title,
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _registerVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ナンバープレート重複チェック
      if (_licensePlateController.text.isNotEmpty) {
        final exists = await Provider.of<VehicleProvider>(context, listen: false)
            .isLicensePlateExists(_licensePlateController.text);
        if (exists && mounted) {
          setState(() {
            _isLoading = false;
          });
          showErrorSnackBar(context, 'このナンバープレートは既に登録されています');
          return;
        }
      }

      String? imageUrl;

      // 画像をアップロード
      if (_imageBytes != null) {
        final uuid = const Uuid().v4();
        final uploadResult = await _firebaseService.uploadImageBytes(
          _imageBytes!,
          'vehicles/$uuid.jpg',
        );
        imageUrl = uploadResult.getOrThrow();
      }

      // 車両データを作成
      final vehicle = Vehicle(
        id: '',
        userId: _firebaseService.currentUserId ?? '',
        maker: _selectedMaker?.name ?? '',
        model: _selectedModel?.name ?? '',
        year: int.parse(_yearController.text),
        grade: _selectedGrade?.name ?? '',
        mileage: int.parse(_mileageController.text),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
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

      // 車両を登録
      if (!mounted) return;
      final success = await Provider.of<VehicleProvider>(context, listen: false)
          .addVehicle(vehicle);

      if (success && mounted) {
        showSuccessSnackBar(context, '車両を登録しました');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '登録に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未設定';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('車両登録'),
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        message: '登録中...',
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
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: AppSpacing.borderRadiusMd,
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: AppSpacing.iconXl,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
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
                          ),
                  ),
                ),
                AppSpacing.verticalMd,

                // === 車検証スキャンボタン ===
                _buildOcrScanButton(theme),
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

                // メーカー（選択式）
                MakerSelectorField(
                  selectedMaker: _selectedMaker,
                  onChanged: (maker) {
                    setState(() {
                      _selectedMaker = maker;
                      // Reset model and grade when maker changes
                      _selectedModel = null;
                      _selectedGrade = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'メーカーを選択してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // 車種（選択式）
                ModelSelectorField(
                  makerId: _selectedMaker?.id,
                  selectedModel: _selectedModel,
                  onChanged: (model) {
                    setState(() {
                      _selectedModel = model;
                      // Reset grade when model changes
                      _selectedGrade = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return '車種を選択してください';
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
                      child: GradeSelectorField(
                        modelId: _selectedModel?.id,
                        selectedGrade: _selectedGrade,
                        onChanged: (grade) {
                          setState(() {
                            _selectedGrade = grade;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'グレードを選択';
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

                // 登録ボタン
                AppButton.primary(
                  label: '登録する',
                  onPressed: _registerVehicle,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  icon: Icons.check,
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
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 車検証スキャンボタン
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
          onTap: _isOcrProcessing ? null : _scanVehicleCertificate,
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
                          Icons.document_scanner,
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
                        '車検証をスキャン',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      AppSpacing.verticalXxs,
                      Text(
                        '車検証を撮影して自動入力',
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
                    'おすすめ',
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
