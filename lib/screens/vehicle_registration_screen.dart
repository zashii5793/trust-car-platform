import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../services/firebase_service.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/loading_indicator.dart';
import 'package:uuid/uuid.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makerController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _gradeController = TextEditingController();
  final _mileageController = TextEditingController();

  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _makerController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _gradeController.dispose();
    _mileageController.dispose();
    super.dispose();
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

  Future<void> _registerVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = FirebaseService();
      String? imageUrl;

      // 画像をアップロード
      if (_imageBytes != null) {
        final uuid = const Uuid().v4();
        imageUrl = await firebaseService.uploadImageBytes(
          _imageBytes!,
          'vehicles/$uuid.jpg',
        );
      }

      // 車両データを作成
      final vehicle = Vehicle(
        id: '',
        userId: firebaseService.currentUserId ?? '',
        maker: _makerController.text,
        model: _modelController.text,
        year: int.parse(_yearController.text),
        grade: _gradeController.text,
        mileage: int.parse(_mileageController.text),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
                AppSpacing.verticalLg,

                // メーカー
                AppTextField(
                  controller: _makerController,
                  labelText: 'メーカー',
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
                  labelText: '車種',
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

                // 年式
                AppTextField.number(
                  controller: _yearController,
                  labelText: '年式',
                  hintText: '例: 2023',
                  prefixIcon: const Icon(Icons.calendar_today),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '年式を入力してください';
                    }
                    final year = int.tryParse(value);
                    if (year == null ||
                        year < 1900 ||
                        year > DateTime.now().year) {
                      return '正しい年式を入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // グレード
                AppTextField(
                  controller: _gradeController,
                  labelText: 'グレード',
                  hintText: '例: G',
                  prefixIcon: const Icon(Icons.star_outline),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'グレードを入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // 走行距離
                AppTextField.number(
                  controller: _mileageController,
                  labelText: '走行距離',
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
                    return null;
                  },
                ),
                AppSpacing.verticalXl,

                // 登録ボタン
                AppButton.primary(
                  label: '登録する',
                  onPressed: _registerVehicle,
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
