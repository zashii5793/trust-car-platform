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

/// 車両編集画面
class VehicleEditScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleEditScreen({super.key, required this.vehicle});

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _makerController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _gradeController;
  late TextEditingController _mileageController;

  Uint8List? _newImageBytes;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _makerController = TextEditingController(text: widget.vehicle.maker);
    _modelController = TextEditingController(text: widget.vehicle.model);
    _yearController = TextEditingController(text: widget.vehicle.year.toString());
    _gradeController = TextEditingController(text: widget.vehicle.grade);
    _mileageController = TextEditingController(text: widget.vehicle.mileage.toString());

    // 変更検知
    _makerController.addListener(_onFieldChanged);
    _modelController.addListener(_onFieldChanged);
    _yearController.addListener(_onFieldChanged);
    _gradeController.addListener(_onFieldChanged);
    _mileageController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final changed = _makerController.text != widget.vehicle.maker ||
        _modelController.text != widget.vehicle.model ||
        _yearController.text != widget.vehicle.year.toString() ||
        _gradeController.text != widget.vehicle.grade ||
        _mileageController.text != widget.vehicle.mileage.toString() ||
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

  Future<void> _updateVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = FirebaseService();
      String? imageUrl = widget.vehicle.imageUrl;

      // 新しい画像があればアップロード
      if (_newImageBytes != null) {
        final uuid = const Uuid().v4();
        imageUrl = await firebaseService.uploadImageBytes(
          _newImageBytes!,
          'vehicles/$uuid.jpg',
        );
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

                  // 更新ボタン
                  AppButton.primary(
                    label: '更新する',
                    onPressed: _hasChanges ? _updateVehicle : null,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                    icon: Icons.save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
