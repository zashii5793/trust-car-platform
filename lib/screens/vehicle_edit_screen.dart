import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../models/vehicle_master.dart';
import '../providers/vehicle_provider.dart';
import '../services/firebase_service.dart';
import '../core/di/service_locator.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/vehicle/vehicle_selector_fields.dart';
import '../services/vehicle_master_service.dart';
import '../services/fleet_service.dart';
import '../services/vehicle_spec_service.dart';
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

  // 基本情報（選択式）
  VehicleMaker? _selectedMaker;
  VehicleModel? _selectedModel;
  VehicleGrade? _selectedGrade;
  VehicleSpecResult? _communitySpec;
  bool _masterDataLoading = true; // マスタ逆引き完了まで true
  late TextEditingController _yearController;
  late TextEditingController _mileageController;

  VehicleMasterService get _masterService => sl.get<VehicleMasterService>();
  VehicleSpecService get _specService => sl.get<VehicleSpecService>();

  // Phase 1.5: 識別情報
  late TextEditingController _licensePlateController;
  late TextEditingController _vinNumberController;
  late TextEditingController _modelCodeController;

  // Phase 1.5: 車検・保険
  DateTime? _inspectionExpiryDate;
  DateTime? _insuranceExpiryDate;

  // 任意保険
  late TextEditingController _voluntaryInsuranceCompanyController;
  DateTime? _voluntaryInsuranceExpiryDate;

  // リース情報
  late TextEditingController _lessorNameController;
  late TextEditingController _leaseMonthlyFeeController;
  late TextEditingController _maintenancePackController;
  DateTime? _leaseContractEndDate;

  // フリート参加
  late TextEditingController _fleetCodeController;
  bool _isJoiningFleet = false;

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

    // 基本情報（テキストコントローラー）
    _yearController = TextEditingController(text: v.year.toString());
    _mileageController = TextEditingController(text: v.mileage.toString());

    // Phase 1.5: 識別情報
    _licensePlateController = TextEditingController(text: v.licensePlate ?? '');
    _vinNumberController = TextEditingController(text: v.vinNumber ?? '');
    _modelCodeController = TextEditingController(text: v.modelCode ?? '');

    // Phase 1.5: 車検・保険
    _inspectionExpiryDate = v.inspectionExpiryDate;
    _insuranceExpiryDate = v.insuranceExpiryDate;

    // 任意保険
    _voluntaryInsuranceCompanyController = TextEditingController(
      text: v.voluntaryInsurance?.companyName ?? '',
    );
    _voluntaryInsuranceExpiryDate = v.voluntaryInsurance?.expiryDate;

    // リース情報
    _lessorNameController =
        TextEditingController(text: v.leaseInfo?.lessorName ?? '');
    _leaseMonthlyFeeController = TextEditingController(
      text: v.leaseInfo?.monthlyFee?.toString() ?? '',
    );
    _maintenancePackController = TextEditingController(
      text: v.leaseInfo?.maintenancePackDetails ?? '',
    );
    _leaseContractEndDate = v.leaseInfo?.contractEndDate;

    _fleetCodeController = TextEditingController();

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

    // 変更検知（テキストフィールドのみ）
    _yearController.addListener(_onFieldChanged);
    _mileageController.addListener(_onFieldChanged);
    _licensePlateController.addListener(_onFieldChanged);
    _vinNumberController.addListener(_onFieldChanged);
    _modelCodeController.addListener(_onFieldChanged);
    _colorController.addListener(_onFieldChanged);
    _engineDisplacementController.addListener(_onFieldChanged);
    _voluntaryInsuranceCompanyController.addListener(_onFieldChanged);
    _lessorNameController.addListener(_onFieldChanged);
    _leaseMonthlyFeeController.addListener(_onFieldChanged);
    _maintenancePackController.addListener(_onFieldChanged);

    // 既存車両データからマスタオブジェクトを逆引きしてセット
    _initMasterSelections();
  }

  /// Resolve existing vehicle's maker/model/grade names to master objects.
  /// Falls back gracefully: if a name is not found in master, leaves null
  /// and the save path uses widget.vehicle values as fallback.
  Future<void> _initMasterSelections() async {
    final v = widget.vehicle;

    // 1. メーカー逆引き
    final makersResult = await _masterService.getMakers();
    VehicleMaker? maker;
    makersResult.when(
      success: (makers) {
        // Unmatched maker must not throw — a renamed/removed master entry
        // would otherwise leave the screen stuck on the loading indicator.
        try {
          maker = makers.firstWhere(
            (m) =>
                m.name == v.maker ||
                m.nameEn.toLowerCase() == v.maker.toLowerCase(),
            orElse: () => makers.firstWhere(
              (m) => m.id == v.maker.toLowerCase(),
            ),
          );
        } catch (_) {}
      },
      failure: (_) {},
    );

    if (!mounted) return;

    // 2. 車種逆引き（メーカーが見つかった場合のみ）
    VehicleModel? model;
    if (maker != null) {
      final modelsResult = await _masterService.getModelsForMaker(maker!.id);
      modelsResult.when(
        success: (models) {
          try {
            model = models.firstWhere(
              (m) =>
                  m.name == v.model ||
                  (m.nameEn?.toLowerCase() == v.model.toLowerCase()),
            );
          } catch (_) {}
        },
        failure: (_) {},
      );
    }

    if (!mounted) return;

    // 3. グレード逆引き（車種が見つかった場合のみ）
    VehicleGrade? grade;
    if (model != null) {
      final gradesResult = await _masterService.getGradesForModel(model!.id);
      gradesResult.when(
        success: (grades) {
          try {
            grade = grades.firstWhere((g) => g.name == v.grade);
          } catch (_) {
            // マスタにないグレード（カスタム値）はその名前でGradeオブジェクトを作成
            if (v.grade.isNotEmpty) {
              grade = VehicleGrade(
                id: 'custom_${v.grade}',
                modelId: model!.id,
                name: v.grade,
              );
            }
          }
        },
        failure: (_) {},
      );
    }

    if (!mounted) return;

    setState(() {
      _selectedMaker = maker;
      _selectedModel = model;
      _selectedGrade = grade;
      _masterDataLoading = false;
    });
  }

  /// Asks for explicit consent before sharing the vehicle photo with the
  /// community. Defaults to NOT sharing (privacy-safe).
  Future<bool> _askPhotoShareConsent() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('実車写真の共有（任意）'),
        content: const Text(
            '車両の保存は完了しています。\n\n'
            'あなたの車の写真を、同じ車種を登録する他のユーザーへの参考写真として共有しますか？\n\n'
            'ナンバープレートや個人情報が写っている場合は「共有しない」を選んでください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('共有しない'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('共有する'),
          ),
        ],
      ),
    );
    return consent ?? false;
  }

  Future<void> _fetchCommunitySpec(VehicleGrade grade) async {
    final maker = _selectedMaker?.name;
    final model = _selectedModel?.name;
    final year = int.tryParse(_yearController.text);
    if (maker == null || model == null || year == null) { return; }

    final result = await _specService.fetchSpec(maker, model, year, grade.name);
    if (!mounted) { return; }

    result.when(
      success: (spec) {
        if (spec == null) { return; }
        // Fill only still-empty fields — the fetch is async and must never
        // overwrite values the user typed (or master data) in the meantime.
        var filled = false;
        setState(() {
          _communitySpec = spec;
          if (_engineDisplacementController.text.isEmpty &&
              spec.grade.engineDisplacement != null) {
            _engineDisplacementController.text =
                spec.grade.engineDisplacement.toString();
            _showAdvancedFields = true;
            filled = true;
          }
          if (_selectedFuelType == null) {
            final ft = FuelType.fromString(spec.grade.fuelType);
            if (ft != null) {
              _selectedFuelType = ft;
              _showAdvancedFields = true;
              filled = true;
            }
          }
        });
        if (filled) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(
                  'コミュニティのデータを自動入力しました（${spec.contributorCount}人が確認）'),
              duration: const Duration(seconds: 3),
            ));
        }
      },
      failure: (_) {},
    );
  }

  void _onFieldChanged() {
    final v = widget.vehicle;
    final changed = (_selectedMaker?.name ?? v.maker) != v.maker ||
        (_selectedModel?.name ?? v.model) != v.model ||
        (_selectedGrade?.name ?? v.grade) != v.grade ||
        _yearController.text != v.year.toString() ||
        _mileageController.text != v.mileage.toString() ||
        _licensePlateController.text != (v.licensePlate ?? '') ||
        _vinNumberController.text != (v.vinNumber ?? '') ||
        _modelCodeController.text != (v.modelCode ?? '') ||
        _colorController.text != (v.color ?? '') ||
        _engineDisplacementController.text !=
            (v.engineDisplacement?.toString() ?? '') ||
        _selectedFuelType != v.fuelType ||
        _inspectionExpiryDate != v.inspectionExpiryDate ||
        _insuranceExpiryDate != v.insuranceExpiryDate ||
        _voluntaryInsuranceCompanyController.text !=
            (v.voluntaryInsurance?.companyName ?? '') ||
        _voluntaryInsuranceExpiryDate != v.voluntaryInsurance?.expiryDate ||
        _lessorNameController.text != (v.leaseInfo?.lessorName ?? '') ||
        _leaseMonthlyFeeController.text !=
            (v.leaseInfo?.monthlyFee?.toString() ?? '') ||
        _maintenancePackController.text !=
            (v.leaseInfo?.maintenancePackDetails ?? '') ||
        _leaseContractEndDate != v.leaseInfo?.contractEndDate ||
        _purchaseDate != v.purchaseDate ||
        _newImageBytes != null;

    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  /// Builds the LeaseInfo to save; returns null when every field is empty
  /// so non-leased vehicles don't store an empty object.
  LeaseInfo? _buildLeaseInfo() {
    final lease = LeaseInfo(
      lessorName: _lessorNameController.text.isEmpty
          ? null
          : _lessorNameController.text,
      monthlyFee: _leaseMonthlyFeeController.text.isEmpty
          ? null
          : int.tryParse(_leaseMonthlyFeeController.text),
      contractStartDate: widget.vehicle.leaseInfo?.contractStartDate,
      contractEndDate: _leaseContractEndDate,
      maintenancePackDetails: _maintenancePackController.text.isEmpty
          ? null
          : _maintenancePackController.text,
    );
    return lease.hasAnyValue ? lease : null;
  }

  @override
  void dispose() {
    _yearController.dispose();
    _mileageController.dispose();
    _licensePlateController.dispose();
    _vinNumberController.dispose();
    _modelCodeController.dispose();
    _colorController.dispose();
    _engineDisplacementController.dispose();
    _voluntaryInsuranceCompanyController.dispose();
    _lessorNameController.dispose();
    _leaseMonthlyFeeController.dispose();
    _maintenancePackController.dispose();
    _fleetCodeController.dispose();
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
        final exists =
            await Provider.of<VehicleProvider>(context, listen: false)
                .isLicensePlateExists(
          _licensePlateController.text,
          excludeVehicleId: widget.vehicle.id,
        );
        if (!mounted) return;
        if (exists) {
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
        final uploadUid = _firebaseService.currentUserId;
        if (uploadUid == null) {
          if (mounted) {
            showErrorSnackBar(context, 'ログインセッションが切れました。再ログインしてください');
            setState(() => _isLoading = false);
          }
          return;
        }
        final uuid = const Uuid().v4();
        // Path includes the owner uid so Storage rules can enforce
        // write access per user.
        final uploadResult = await _firebaseService.uploadImageBytes(
          _newImageBytes!,
          'vehicles/$uploadUid/$uuid.jpg',
        );
        imageUrl = uploadResult.getOrThrow();
      }

      // 更新データを作成
      final updatedVehicle = Vehicle(
        id: widget.vehicle.id,
        userId: widget.vehicle.userId,
        maker: _selectedMaker?.name ?? widget.vehicle.maker,
        model: _selectedModel?.name ?? widget.vehicle.model,
        year: int.parse(_yearController.text),
        grade: _selectedGrade?.name ?? widget.vehicle.grade,
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
        // 任意保険（証券番号等の未編集フィールドは既存値を引き継ぐ）
        voluntaryInsurance: VoluntaryInsurance(
          companyName: _voluntaryInsuranceCompanyController.text.isEmpty
              ? null
              : _voluntaryInsuranceCompanyController.text,
          expiryDate: _voluntaryInsuranceExpiryDate,
          policyNumber: widget.vehicle.voluntaryInsurance?.policyNumber,
          coverageType: widget.vehicle.voluntaryInsurance?.coverageType,
          agentName: widget.vehicle.voluntaryInsurance?.agentName,
          agentPhone: widget.vehicle.voluntaryInsurance?.agentPhone,
        ),
        // リース情報（契約開始日は未編集なら既存値を引き継ぐ）
        leaseInfo: _buildLeaseInfo(),
        // Phase 1.5: 詳細情報
        color: _colorController.text.isEmpty ? null : _colorController.text,
        engineDisplacement: _engineDisplacementController.text.isEmpty
            ? null
            : int.tryParse(_engineDisplacementController.text),
        fuelType: _selectedFuelType,
        purchaseDate: _purchaseDate,
        // Phase 5: preserve existing values (not editable in this screen)
        firstRegistrationDate: widget.vehicle.firstRegistrationDate,
        driveType: widget.vehicle.driveType,
        transmissionType: widget.vehicle.transmissionType,
        vehicleWeight: widget.vehicle.vehicleWeight,
        seatingCapacity: widget.vehicle.seatingCapacity,
        // Fleet: preserve existing fleet membership
        companyId: widget.vehicle.companyId,
        assigneeId: widget.vehicle.assigneeId,
        assigneeName: widget.vehicle.assigneeName,
      );

      // 車両を更新
      if (!mounted) return;
      final success = await Provider.of<VehicleProvider>(context, listen: false)
          .updateVehicle(widget.vehicle.id, updatedVehicle);

      if (success && mounted) {
        // Contribute spec data to the community collection (fire-and-forget).
        // Skipped entirely when this user already contributed — repeat saves
        // must not re-show the consent dialog nor inflate the badge count.
        // The photo is only shared with explicit user consent — vehicle
        // photos may contain license plates or other personal information.
        final uid = _firebaseService.currentUserId;
        if (uid != null &&
            (updatedVehicle.engineDisplacement != null ||
                updatedVehicle.fuelType != null)) {
          final spec = (await _specService.fetchSpec(
                  updatedVehicle.maker,
                  updatedVehicle.model,
                  updatedVehicle.year,
                  updatedVehicle.grade))
              .valueOrNull;
          if (spec == null || !spec.isContributor(uid)) {
            String? imageToShare;
            if (updatedVehicle.imageUrl != null &&
                (spec == null || spec.sampleImageUrl == null) &&
                mounted) {
              imageToShare = await _askPhotoShareConsent()
                  ? updatedVehicle.imageUrl
                  : null;
            }
            _specService.saveSpec(
              updatedVehicle.maker,
              updatedVehicle.model,
              updatedVehicle.year,
              updatedVehicle.grade,
              VehicleGrade(
                id: '',
                modelId: '',
                name: updatedVehicle.grade,
                engineDisplacement: updatedVehicle.engineDisplacement,
                fuelType: updatedVehicle.fuelType?.name,
                seatingCapacity: updatedVehicle.seatingCapacity,
                vehicleWeight: updatedVehicle.vehicleWeight,
              ),
              contributorId: uid,
              imageUrl: imageToShare,
            );
          }
        }
        if (!mounted) return;
        showSuccessSnackBar(context, '車両情報を更新しました');
        Navigator.pop(context, updatedVehicle);
      } else if (mounted) {
        final provider =
            Provider.of<VehicleProvider>(context, listen: false);
        showErrorSnackBar(
            context, provider.errorMessage ?? '更新に失敗しました。通信環境をご確認ください');
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
      } else if (mounted) {
        final provider =
            Provider.of<VehicleProvider>(context, listen: false);
        showErrorSnackBar(
            context, provider.errorMessage ?? '削除に失敗しました。通信環境をご確認ください');
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

                  // マスタデータ読み込み中インジケーター
                  if (_masterDataLoading) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('車両情報を読み込み中...'),
                        ],
                      ),
                    ),
                  ],

                  // メーカー（選択式）
                  MakerSelectorField(
                    selectedMaker: _selectedMaker,
                    onChanged: (maker) {
                      setState(() {
                        _selectedMaker = maker;
                        _selectedModel = null;
                        _selectedGrade = null;
                      });
                      _onFieldChanged();
                    },
                    validator: (value) {
                      // 逆引き失敗 or 読み込み中は既存値を使うため null でもOK
                      if (value == null &&
                          _selectedMaker == null &&
                          !_masterDataLoading) {
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
                        _selectedGrade = null;
                      });
                      _onFieldChanged();
                    },
                    validator: (value) {
                      if (value == null &&
                          _selectedModel == null &&
                          !_masterDataLoading) {
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
                              _communitySpec = null;
                              // Auto-fill specs from grade master data
                              if (grade != null) {
                                if (grade.engineDisplacement != null) {
                                  _engineDisplacementController.text =
                                      grade.engineDisplacement.toString();
                                  _showAdvancedFields = true;
                                }
                                final ft = FuelType.fromString(grade.fuelType);
                                if (ft != null) {
                                  _selectedFuelType = ft;
                                  _showAdvancedFields = true;
                                }
                                _fetchCommunitySpec(grade);
                              }
                            });
                            _onFieldChanged();
                          },
                          validator: (value) {
                            if (value == null &&
                                _selectedGrade == null &&
                                !_masterDataLoading) {
                              return 'グレードを選択';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  // Grade spec preview card
                  if (_selectedGrade != null &&
                      (_selectedGrade!.hasSpecData || _communitySpec != null))
                    _GradeSpecCard(
                      grade: _selectedGrade!,
                      communitySpec: _communitySpec,
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
                  _buildSectionHeader(theme, '車検・保険', Icons.verified,
                      isImportant: true),
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
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
                      onSelected: (date) =>
                          setState(() => _inspectionExpiryDate = date),
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
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
                      onSelected: (date) =>
                          setState(() => _insuranceExpiryDate = date),
                    ),
                  ),
                  AppSpacing.verticalSm,

                  // 任意保険（会社名・満期日）
                  AppTextField(
                    controller: _voluntaryInsuranceCompanyController,
                    labelText: '任意保険会社（任意）',
                    hintText: '例: ○○損害保険',
                    prefixIcon: const Icon(Icons.security),
                  ),
                  AppSpacing.verticalSm,
                  _buildDatePickerTile(
                    context: context,
                    title: '任意保険満期日',
                    icon: Icons.shield_outlined,
                    date: _voluntaryInsuranceExpiryDate,
                    hint: '任意保険証券に記載の満期日',
                    onTap: () => _selectDate(
                      title: '任意保険満期日を選択',
                      currentDate: _voluntaryInsuranceExpiryDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
                      onSelected: (date) =>
                          setState(() => _voluntaryInsuranceExpiryDate = date),
                    ),
                  ),
                  AppSpacing.verticalLg,

                  // === リース情報セクション（リース車両のみ入力） ===
                  _buildSectionHeader(theme, 'リース情報', Icons.assignment),
                  AppSpacing.verticalSm,
                  AppTextField(
                    controller: _lessorNameController,
                    labelText: 'リース会社（リース車両の場合）',
                    hintText: '例: ○○オートリース',
                    prefixIcon: const Icon(Icons.business),
                  ),
                  AppSpacing.verticalSm,
                  AppTextField.number(
                    controller: _leaseMonthlyFeeController,
                    labelText: '月額リース料（円）',
                    hintText: '例: 45000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  AppSpacing.verticalSm,
                  _buildDatePickerTile(
                    context: context,
                    title: 'リース契約満了日',
                    icon: Icons.event_busy,
                    date: _leaseContractEndDate,
                    hint: '返却・再リースの判断時期をお知らせします',
                    onTap: () => _selectDate(
                      title: 'リース契約満了日を選択',
                      currentDate: _leaseContractEndDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 7)),
                      onSelected: (date) =>
                          setState(() => _leaseContractEndDate = date),
                    ),
                  ),
                  AppSpacing.verticalSm,
                  AppTextField(
                    controller: _maintenancePackController,
                    labelText: 'メンテナンスパック内容',
                    hintText: '例: オイル交換・タイヤローテーション込み',
                    prefixIcon: const Icon(Icons.build_outlined),
                    maxLines: 3,
                  ),
                  AppSpacing.verticalLg,

                  // === フリート参加セクション ===
                  _buildSectionHeader(
                      theme, 'フリート管理', Icons.business_center_outlined),
                  AppSpacing.verticalSm,
                  if (widget.vehicle.companyId != null)
                    _buildFleetStatusTile(theme)
                  else
                    _buildFleetJoinSection(theme),
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
                        onSelected: (date) =>
                            setState(() => _purchaseDate = date),
                      ),
                    ),
                  ],

                  AppSpacing.verticalXl,

                  // 更新ボタン
                  AppButton.primary(
                    label: '更新する',
                    onPressed:
                        (_hasChanges && !_isLoading) ? _updateVehicle : null,
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
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Colors.orange, size: 20),
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

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon,
      {bool isImportant = false}) {
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
                        ? Colors.orange
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
    if (widget.vehicle.imageUrl != null &&
        widget.vehicle.imageUrl!.isNotEmpty) {
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

  Widget _buildFleetStatusTile(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          AppSpacing.horizontalSm,
          Expanded(
            child: Text(
              'フリートに参加中',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: _isJoiningFleet ? null : _leaveFleet,
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('離脱'),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetJoinSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'フリートコードを入力すると、管理者の車両一覧に追加されます。',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        AppSpacing.verticalSm,
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _fleetCodeController,
                labelText: 'フリートコード',
                hintText: '管理者から共有されたコードを入力',
                prefixIcon: const Icon(Icons.qr_code),
              ),
            ),
            AppSpacing.horizontalSm,
            ElevatedButton(
              onPressed: _isJoiningFleet ? null : _joinFleet,
              child: _isJoiningFleet
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Text('参加'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _joinFleet() async {
    final code = _fleetCodeController.text.trim();
    if (code.isEmpty) {
      showErrorSnackBar(context, 'フリートコードを入力してください');
      return;
    }
    setState(() => _isJoiningFleet = true);
    try {
      final userId = sl.get<FirebaseService>().currentUserId;
      if (userId == null) {
        if (mounted) showErrorSnackBar(context, 'ログインが必要です');
        return;
      }
      final result = await sl.get<FleetService>().joinFleetByCode(
            code,
            widget.vehicle.id,
            userId,
          );
      if (!mounted) return;
      result.when(
        success: (_) {
          showSuccessSnackBar(context, 'フリートに参加しました');
          // Reflect in UI by navigating back with an updated vehicle
          final updated = widget.vehicle.copyWith(companyId: code);
          Navigator.pop(context, updated);
        },
        failure: (e) => showErrorSnackBar(context, e.message),
      );
    } finally {
      if (mounted) setState(() => _isJoiningFleet = false);
    }
  }

  Future<void> _leaveFleet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('フリートから離脱'),
        content: const Text('この車両をフリートから外しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('離脱する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isJoiningFleet = true);
    try {
      final userId = sl.get<FirebaseService>().currentUserId;
      if (userId == null) {
        if (mounted) showErrorSnackBar(context, 'ログインが必要です');
        return;
      }
      final result =
          await sl.get<FleetService>().leaveFleet(widget.vehicle.id, userId);
      if (!mounted) return;
      result.when(
        success: (_) {
          showSuccessSnackBar(context, 'フリートから離脱しました');
          // Clear companyId by rebuilding Vehicle without it
          Navigator.pop(
            context,
            Vehicle(
              id: widget.vehicle.id,
              userId: widget.vehicle.userId,
              maker: widget.vehicle.maker,
              model: widget.vehicle.model,
              year: widget.vehicle.year,
              grade: widget.vehicle.grade,
              mileage: widget.vehicle.mileage,
              imageUrl: widget.vehicle.imageUrl,
              createdAt: widget.vehicle.createdAt,
              updatedAt: DateTime.now(),
              licensePlate: widget.vehicle.licensePlate,
              vinNumber: widget.vehicle.vinNumber,
              modelCode: widget.vehicle.modelCode,
              inspectionExpiryDate: widget.vehicle.inspectionExpiryDate,
              insuranceExpiryDate: widget.vehicle.insuranceExpiryDate,
              voluntaryInsurance: widget.vehicle.voluntaryInsurance,
              leaseInfo: widget.vehicle.leaseInfo,
              color: widget.vehicle.color,
              engineDisplacement: widget.vehicle.engineDisplacement,
              fuelType: widget.vehicle.fuelType,
              purchaseDate: widget.vehicle.purchaseDate,
              firstRegistrationDate: widget.vehicle.firstRegistrationDate,
              driveType: widget.vehicle.driveType,
              transmissionType: widget.vehicle.transmissionType,
              vehicleWeight: widget.vehicle.vehicleWeight,
              seatingCapacity: widget.vehicle.seatingCapacity,
              // companyId intentionally omitted to clear it
            ),
          );
        },
        failure: (e) => showErrorSnackBar(context, e.message),
      );
    } finally {
      if (mounted) setState(() => _isJoiningFleet = false);
    }
  }
}

// ── グレードスペックプレビューカード ─────────────────────────────────────────

class _GradeSpecCard extends StatelessWidget {
  final VehicleGrade grade;
  final VehicleSpecResult? communitySpec;
  const _GradeSpecCard({required this.grade, this.communitySpec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final community = communitySpec;
    final specs = <String>[];
    if (grade.engineDisplacement != null) {
      specs.add('排気量: ${grade.engineDisplacement}cc');
    }
    if (grade.fuelType != null) {
      final ft = FuelType.fromString(grade.fuelType);
      if (ft != null) specs.add('燃料: ${ft.displayName}');
    }
    if (grade.driveType != null) {
      final dt = DriveType.fromString(grade.driveType);
      if (dt != null) specs.add('駆動: ${dt.displayName}');
    }
    if (grade.transmissionType != null) {
      final tt = TransmissionType.fromString(grade.transmissionType);
      if (tt != null) specs.add('変速: ${tt.displayName}');
    }
    if (grade.seatingCapacity != null) {
      specs.add('定員: ${grade.seatingCapacity}名');
    }
    if (grade.vehicleWeight != null) {
      specs.add('重量: ${grade.vehicleWeight}kg');
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: AppColors.info),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'グレードスペック（マスタより自動入力）',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.info),
                ),
              ),
              if (community != null && community.isVerified)
                Container(
                  key: const Key('grade_spec_verified_badge'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 2),
                      Text(
                        '${community.contributorCount}人が確認',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.success),
                      ),
                    ],
                  ),
                )
              else if (community != null)
                Text(
                  '${community.contributorCount}人が確認',
                  key: const Key('grade_spec_contributor_count'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
          // Community-contributed photo of an actual vehicle of this grade
          if (community?.sampleImageUrl != null) ...[
            AppSpacing.verticalXs,
            ClipRRect(
              key: const Key('grade_spec_sample_image'),
              borderRadius: AppSpacing.borderRadiusSm,
              child: Image.network(
                community!.sampleImageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            AppSpacing.verticalXxs,
            Text(
              'オーナー提供の実車写真',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (specs.isNotEmpty) ...[
            AppSpacing.verticalXs,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: specs
                  .map((s) => Chip(
                        label: Text(s,
                            style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          if (grade.standardEquipment.isNotEmpty) ...[
            AppSpacing.verticalXs,
            Text(
              '標準装備',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.verticalXxs,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: grade.standardEquipment
                  .map((e) => Chip(
                        label: Text(e,
                            style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
