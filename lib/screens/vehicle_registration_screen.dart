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
  // ウィザード管理
  int _currentStep = 0;
  final PageController _pageController = PageController();
  final _formKeyStep1 = GlobalKey<FormState>();

  // 基本情報 (選択式)
  VehicleMaker? _selectedMaker;
  VehicleModel? _selectedModel;
  VehicleGrade? _selectedGrade;
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();

  // 識別情報
  final _licensePlateController = TextEditingController();
  final _vinNumberController = TextEditingController();
  final _modelCodeController = TextEditingController();

  // 車検・保険
  DateTime? _inspectionExpiryDate;
  DateTime? _insuranceExpiryDate;

  // 詳細情報
  final _colorController = TextEditingController();
  final _engineDisplacementController = TextEditingController();
  FuelType? _selectedFuelType;
  DateTime? _purchaseDate;

  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isOcrProcessing = false;

  VehicleCertificateOcrService get _ocrService =>
      sl.get<VehicleCertificateOcrService>();
  FirebaseService get _firebaseService => sl.get<FirebaseService>();
  VehicleMasterService get _masterService => sl.get<VehicleMasterService>();

  @override
  void dispose() {
    _pageController.dispose();
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

  // ---------------------------------------------------------------------------
  // ウィザードナビゲーション
  // ---------------------------------------------------------------------------

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return '基本情報を入力';
      case 1:
        return '車検・保険の情報';
      case 2:
        return '詳細情報（任意）';
      default:
        return '車両登録';
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OCR / 画像処理（ロジック変更なし）
  // ---------------------------------------------------------------------------

  Future<void> _scanVehicleCertificate() async {
    final imageFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentScannerScreen(
          documentType: DocumentType.vehicleCertificate,
        ),
      ),
    );

    if (imageFile == null || !mounted) return;

    setState(() => _isOcrProcessing = true);

    try {
      final result = await _ocrService.extractFromImage(imageFile);

      if (!mounted) return;

      result.when(
        success: (ocrData) async {
          final registrationData =
              await Navigator.push<VehicleRegistrationData>(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleCertificateResultScreen(
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
      if (mounted) setState(() => _isOcrProcessing = false);
    }
  }

  Future<void> _applyOcrData(VehicleRegistrationData data) async {
    if (data.maker.isNotEmpty) {
      final makersResult = await _masterService.getMakers();
      makersResult.when(
        success: (makers) {
          final matchedMaker = _findMatchingMaker(makers, data.maker);
          if (matchedMaker != null) {
            _selectedMaker = matchedMaker;
            _loadAndMatchModel(data.model);
          }
        },
        failure: (_) {},
      );
    }

    setState(() {
      if (data.year != null) _yearController.text = data.year.toString();
      if (data.licensePlate != null) {
        _licensePlateController.text = data.licensePlate!;
      }
      if (data.vinNumber != null) _vinNumberController.text = data.vinNumber!;
      if (data.modelCode != null) _modelCodeController.text = data.modelCode!;
      if (data.inspectionExpiryDate != null) {
        _inspectionExpiryDate = data.inspectionExpiryDate;
      }
      if (data.engineDisplacement != null) {
        _engineDisplacementController.text = data.engineDisplacement.toString();
      }
      if (data.fuelType != null) _selectedFuelType = data.fuelType;
      if (data.color != null) _colorController.text = data.color!;
    });

    if (mounted) showSuccessSnackBar(context, '車検証の情報を読み取りました');
  }

  VehicleMaker? _findMatchingMaker(
      List<VehicleMaker> makers, String ocrText) {
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

  Future<void> _loadAndMatchModel(String ocrModelName) async {
    if (_selectedMaker == null || ocrModelName.isEmpty) return;
    final modelsResult =
        await _masterService.getModelsForMaker(_selectedMaker!.id);
    modelsResult.when(
      success: (models) {
        final lowerText = ocrModelName.toLowerCase();
        for (final model in models) {
          if (model.name.toLowerCase().contains(lowerText) ||
              (model.nameEn?.toLowerCase().contains(lowerText) ?? false) ||
              lowerText.contains(model.name.toLowerCase())) {
            if (mounted) setState(() => _selectedModel = model);
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
      setState(() => _imageBytes = bytes);
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
    if (picked != null) onSelected(picked);
  }

  // ---------------------------------------------------------------------------
  // 登録処理（ロジック変更なし、フォームバリデーションを手動チェックに変更）
  // ---------------------------------------------------------------------------

  Future<void> _registerVehicle() async {
    // ステップ1は既に検証済みだが念のため確認
    if (_selectedMaker == null ||
        _selectedModel == null ||
        _selectedGrade == null ||
        _yearController.text.isEmpty ||
        _mileageController.text.isEmpty) {
      showErrorSnackBar(context, '基本情報が不足しています。最初のステップに戻って確認してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_licensePlateController.text.isNotEmpty) {
        final exists =
            await Provider.of<VehicleProvider>(context, listen: false)
                .isLicensePlateExists(_licensePlateController.text);
        if (exists && mounted) {
          setState(() => _isLoading = false);
          showErrorSnackBar(context, 'このナンバープレートは既に登録されています');
          return;
        }
      }

      String? imageUrl;
      if (_imageBytes != null) {
        final uuid = const Uuid().v4();
        final uploadResult = await _firebaseService.uploadImageBytes(
          _imageBytes!,
          'vehicles/$uuid.jpg',
        );
        imageUrl = uploadResult.getOrThrow();
      }

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
        licensePlate: _licensePlateController.text.isEmpty
            ? null
            : _licensePlateController.text,
        vinNumber: _vinNumberController.text.isEmpty
            ? null
            : _vinNumberController.text,
        modelCode: _modelCodeController.text.isEmpty
            ? null
            : _modelCodeController.text,
        inspectionExpiryDate: _inspectionExpiryDate,
        insuranceExpiryDate: _insuranceExpiryDate,
        color: _colorController.text.isEmpty ? null : _colorController.text,
        engineDisplacement: _engineDisplacementController.text.isEmpty
            ? null
            : int.tryParse(_engineDisplacementController.text),
        fuelType: _selectedFuelType,
        purchaseDate: _purchaseDate,
      );

      if (!mounted) return;
      final success =
          await Provider.of<VehicleProvider>(context, listen: false)
              .addVehicle(vehicle);

      if (success && mounted) {
        showSuccessSnackBar(context, '車両を登録しました');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '登録に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未設定';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // ビルド
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        message: '登録中...',
        child: Column(
          children: [
            _WizardStepIndicator(currentStep: _currentStep),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: 基本情報
  // ---------------------------------------------------------------------------

  Widget _buildStep1() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKeyStep1,
      child: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // OCR スキャンボタン（メインCTA）
            _buildOcrScanButton(theme),
            AppSpacing.verticalMd,

            // 写真選択（コンパクト）
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.backgroundLight,
                  borderRadius: AppSpacing.borderRadiusMd,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.border,
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: AppSpacing.iconLg,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                          AppSpacing.horizontalSm,
                          Text(
                            '車両の写真を追加（任意）',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            AppSpacing.verticalLg,

            _buildSectionHeader(theme, '車両情報', Icons.directions_car),
            AppSpacing.verticalXxs,
            Text(
              '* は必須項目です',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            AppSpacing.verticalSm,

            MakerSelectorField(
              selectedMaker: _selectedMaker,
              onChanged: (maker) {
                setState(() {
                  _selectedMaker = maker;
                  _selectedModel = null;
                  _selectedGrade = null;
                });
              },
              validator: (value) =>
                  value == null ? 'メーカーを選択してください' : null,
            ),
            AppSpacing.verticalMd,

            ModelSelectorField(
              makerId: _selectedMaker?.id,
              selectedModel: _selectedModel,
              onChanged: (model) {
                setState(() {
                  _selectedModel = model;
                  _selectedGrade = null;
                });
              },
              validator: (value) =>
                  value == null ? '車種を選択してください' : null,
            ),
            AppSpacing.verticalMd,

            Row(
              children: [
                Expanded(
                  child: AppTextField.number(
                    controller: _yearController,
                    labelText: '年式 *',
                    hintText: '例: 2023',
                    prefixIcon: const Icon(Icons.calendar_today),
                    validator: (value) {
                      if (value == null || value.isEmpty) return '年式を入力';
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
                    onChanged: (grade) => setState(() => _selectedGrade = grade),
                    validator: (value) =>
                        value == null ? 'グレードを選択' : null,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMd,

            AppTextField.number(
              controller: _mileageController,
              labelText: '走行距離 *',
              hintText: '例: 24500',
              prefixIcon: const Icon(Icons.speed),
              suffixText: 'km',
              validator: (value) {
                if (value == null || value.isEmpty) return '走行距離を入力してください';
                final mileage = int.tryParse(value);
                if (mileage == null || mileage < 0) return '正しい走行距離を入力してください';
                if (mileage > 2000000) return '走行距離が大きすぎます（200万km以下）';
                return null;
              },
            ),
            AppSpacing.verticalLg,
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: 車検・保険
  // ---------------------------------------------------------------------------

  Widget _buildStep2() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 情報バナー
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppColors.info, size: 20),
                AppSpacing.horizontalSm,
                Expanded(
                  child: Text(
                    '期限が近づくと自動でアプリが通知します。\n後から編集も可能です。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.verticalLg,

          _buildSectionHeader(theme, '車検・保険', Icons.verified,
              isImportant: true),
          AppSpacing.verticalSm,

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
              firstDate:
                  DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              onSelected: (d) =>
                  setState(() => _inspectionExpiryDate = d),
            ),
          ),
          AppSpacing.verticalSm,

          _buildDatePickerTile(
            context: context,
            title: '自賠責保険期限',
            icon: Icons.shield,
            date: _insuranceExpiryDate,
            hint: '自賠責保険証明書の期限',
            onTap: () => _selectDate(
              title: '自賠責保険期限を選択',
              currentDate: _insuranceExpiryDate,
              firstDate:
                  DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              onSelected: (d) =>
                  setState(() => _insuranceExpiryDate = d),
            ),
          ),
          AppSpacing.verticalLg,

          _buildSectionHeader(theme, 'ナンバープレート', Icons.confirmation_number),
          AppSpacing.verticalSm,

          AppTextField(
            controller: _licensePlateController,
            labelText: 'ナンバープレート',
            hintText: '例: 品川 300 あ 12-34',
            prefixIcon: const Icon(Icons.confirmation_number),
          ),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: 詳細情報（任意）
  // ---------------------------------------------------------------------------

  Widget _buildStep3() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 任意バッジ
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: AppColors.success),
                  AppSpacing.horizontalXs,
                  Text(
                    'すべて任意入力です。後から編集できます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.verticalLg,

          _buildSectionHeader(theme, '車両詳細', Icons.info_outline),
          AppSpacing.verticalSm,

          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _colorController,
                  labelText: '車体色',
                  hintText: '例: パールホワイト',
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

          _buildFuelTypeSelector(theme),
          AppSpacing.verticalLg,

          _buildSectionHeader(theme, '識別情報', Icons.badge),
          AppSpacing.verticalSm,

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
          AppSpacing.verticalMd,

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
              onSelected: (d) => setState(() => _purchaseDate = d),
            ),
          ),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ナビゲーションボタン（下部固定）
  // ---------------------------------------------------------------------------

  Widget _buildNavigationButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md,
        ),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: AppButton.secondary(
                  label: '戻る',
                  onPressed: _previousStep,
                  icon: Icons.arrow_back,
                  isFullWidth: true,
                ),
              ),
              AppSpacing.horizontalSm,
            ],
            Expanded(
              flex: 2,
              child: _currentStep < 2
                  ? AppButton.primary(
                      label: '次へ',
                      onPressed: _nextStep,
                      isFullWidth: true,
                      icon: Icons.arrow_forward,
                      size: AppButtonSize.large,
                    )
                  : AppButton.primary(
                      label: '登録する',
                      onPressed: _registerVehicle,
                      isFullWidth: true,
                      icon: Icons.check,
                      size: AppButtonSize.large,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 共通ウィジェットヘルパー
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    IconData icon, {
    bool isImportant = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isImportant ? AppColors.warning : theme.colorScheme.primary,
        ),
        AppSpacing.horizontalXs,
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isImportant ? AppColors.warning : null,
          ),
        ),
        if (isImportant) ...[
          AppSpacing.horizontalXs,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '重要',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.warning,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(
            color: isWarning
                ? AppColors.warning.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkTextTertiary : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isWarning ? AppColors.warning : theme.colorScheme.primary,
            ),
            AppSpacing.horizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (hint != null && date == null)
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6),
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
                    ? (isWarning
                        ? AppColors.warning
                        : theme.textTheme.bodySmall?.color)
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
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
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
                setState(() => _selectedFuelType = selected ? type : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isOcrProcessing ? null : _scanVehicleCertificate,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                      : const Icon(Icons.document_scanner,
                          color: AppColors.primary, size: 24),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '車検証をスキャンして自動入力',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      AppSpacing.verticalXxs,
                      Text(
                        '写真を撮るだけでフォームが自動入力されます',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
                AppSpacing.horizontalXs,
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

// ---------------------------------------------------------------------------
// ウィザードステップインジケーター
// ---------------------------------------------------------------------------

class _WizardStepIndicator extends StatelessWidget {
  final int currentStep;

  const _WizardStepIndicator({required this.currentStep});

  static const _labels = ['基本情報', '車検・保険', '詳細情報'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final inactiveColor =
        isDark ? AppColors.darkCard : AppColors.backgroundLight;
    final inactiveBorder =
        isDark ? AppColors.darkTextTertiary : AppColors.border;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs,
      ),
      child: Column(
        children: [
          // ステップ丸 + 接続線
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                _StepCircle(
                  index: i,
                  isDone: i < currentStep,
                  isCurrent: i == currentStep,
                  primaryColor: primaryColor,
                  inactiveColor: inactiveColor,
                  inactiveBorder: inactiveBorder,
                ),
                if (i < 2)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: i < currentStep ? primaryColor : inactiveColor,
                    ),
                  ),
              ],
            ],
          ),
          AppSpacing.verticalXs,
          // ラベル行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final isCurrent = i == currentStep;
              final isDone = i < currentStep;
              return SizedBox(
                width: 72,
                child: Text(
                  _labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == 2
                          ? TextAlign.right
                          : TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCurrent
                        ? primaryColor
                        : isDone
                            ? primaryColor.withValues(alpha: 0.55)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int index;
  final bool isDone;
  final bool isCurrent;
  final Color primaryColor;
  final Color inactiveColor;
  final Color inactiveBorder;

  const _StepCircle({
    required this.index,
    required this.isDone,
    required this.isCurrent,
    required this.primaryColor,
    required this.inactiveColor,
    required this.inactiveBorder,
  });

  @override
  Widget build(BuildContext context) {
    final filled = isDone || isCurrent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: filled ? primaryColor : inactiveColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? primaryColor : inactiveBorder,
          width: 2,
        ),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.white : AppColors.textTertiary,
                ),
              ),
      ),
    );
  }
}
