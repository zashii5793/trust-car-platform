import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/post.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/vehicle_provider.dart';

/// Post creation screen
///
/// Supports category selection, text input, image attachment (up to 3),
/// and optional vehicle tag from the current user's vehicle list.
class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();

  PostCategory _selectedCategory = PostCategory.general;

  /// Selected image files (max 3)
  final List<XFile> _selectedImages = [];

  /// Selected vehicle for tagging
  Vehicle? _selectedVehicle;

  static const int _maxLength = 500;
  static const int _maxImages = 3;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (_selectedImages.length >= _maxImages) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      _selectedImages.add(picked);
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final postProvider = context.read<PostProvider>();
    final user = authProvider.firebaseUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    // NOTE: Image upload to Firebase Storage is not yet implemented.
    // The imageUrls list is passed as empty until upload logic is added.
    final success = await postProvider.createPost(
      userId: user.uid,
      content: content,
      category: _selectedCategory,
      userDisplayName: user.displayName,
      userPhotoUrl: user.photoURL,
      imageUrls: const [],
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました')),
      );
    } else {
      final msg =
          postProvider.submitErrorMessage ?? '投稿に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Vehicle selection dialog ──────────────────────────────────────────────

  Future<void> _showVehiclePicker(List<Vehicle> vehicles) async {
    final selected = await showModalBottomSheet<Vehicle>(
      context: context,
      builder: (ctx) => _VehiclePickerSheet(
        vehicles: vehicles,
        selectedId: _selectedVehicle?.id,
      ),
    );

    if (selected != null) {
      setState(() => _selectedVehicle = selected);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新規投稿'),
        actions: [
          Consumer<PostProvider>(
            builder: (context, provider, _) {
              if (provider.isSubmitting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: _contentController,
                builder: (_, value, __) {
                  final canSubmit = value.text.trim().isNotEmpty;
                  return TextButton(
                    onPressed: canSubmit ? _submit : null,
                    child: const Text('投稿'),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          // ── Category selection (horizontal scroll chips) ──────────────────
          _SectionLabel(label: 'カテゴリ'),
          AppSpacing.verticalSm,
          _CategoryChipRow(
            selected: _selectedCategory,
            onSelected: (cat) => setState(() => _selectedCategory = cat),
          ),

          AppSpacing.verticalLg,

          // ── Text input area ───────────────────────────────────────────────
          _SectionLabel(label: '本文'),
          AppSpacing.verticalSm,
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _contentController,
            builder: (_, value, __) {
              final count = value.text.length;
              final isOver = count >= _maxLength;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 10,
                    minLines: 5,
                    maxLength: _maxLength,
                    decoration: const InputDecoration(
                      hintText: '車やドライブについて投稿しましょう...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count / $_maxLength',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOver ? AppColors.error : AppColors.textTertiary,
                    ),
                  ),
                ],
              );
            },
          ),

          AppSpacing.verticalLg,

          // ── Image attachment area ─────────────────────────────────────────
          _SectionLabel(label: '画像（任意）'),
          AppSpacing.verticalSm,
          _ImageAttachmentArea(
            images: _selectedImages,
            maxImages: _maxImages,
            onAdd: _pickImage,
            onRemove: _removeImage,
          ),

          AppSpacing.verticalLg,

          // ── Vehicle tag ───────────────────────────────────────────────────
          _SectionLabel(label: '車両タグ（任意）'),
          AppSpacing.verticalSm,
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, _) {
              final vehicles = vehicleProvider.vehicles;
              return _VehicleTagArea(
                vehicles: vehicles,
                selected: _selectedVehicle,
                onTap: () => _showVehiclePicker(vehicles),
                onRemove: () => setState(() => _selectedVehicle = null),
              );
            },
          ),

          AppSpacing.verticalXxl,

          // ── Submit button ─────────────────────────────────────────────────
          Consumer<PostProvider>(
            builder: (context, provider, _) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: _contentController,
                builder: (_, value, __) {
                  final canSubmit =
                      value.text.trim().isNotEmpty && !provider.isSubmitting;
                  return FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      provider.isSubmitting ? '投稿中...' : '投稿する',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chip row (horizontal scroll)
// ---------------------------------------------------------------------------

class _CategoryChipRow extends StatelessWidget {
  final PostCategory selected;
  final ValueChanged<PostCategory> onSelected;

  const _CategoryChipRow({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PostCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = PostCategory.values[index];
          final isSelected = cat == selected;
          return ChoiceChip(
            label: Text(
              cat.displayName,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(cat),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image attachment area
// ---------------------------------------------------------------------------

class _ImageAttachmentArea extends StatelessWidget {
  final List<XFile> images;
  final int maxImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImageAttachmentArea({
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = images.length < maxImages;

    return Row(
      children: [
        // Add button
        if (canAdd)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 28),
                  SizedBox(height: 4),
                  Text('画像を追加', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        // Thumbnails
        ...List.generate(images.length, (i) {
          return _ImageThumbnail(
            file: File(images[i].path),
            onRemove: () => onRemove(i),
          );
        }),
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ImageThumbnail({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle tag area
// ---------------------------------------------------------------------------

class _VehicleTagArea extends StatelessWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _VehicleTagArea({
    required this.vehicles,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return Text(
        '登録済みの車両がありません',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
      );
    }

    if (selected != null) {
      return Wrap(
        spacing: 8,
        children: [
          Chip(
            avatar: const Icon(Icons.directions_car_outlined, size: 16),
            label: Text('${selected!.displayName} (${selected!.year}年式)'),
            onDeleted: onRemove,
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.directions_car_outlined, size: 18),
      label: const Text('車両を選択'),
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle picker bottom sheet
// ---------------------------------------------------------------------------

class _VehiclePickerSheet extends StatelessWidget {
  final List<Vehicle> vehicles;
  final String? selectedId;

  const _VehiclePickerSheet({
    required this.vehicles,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '車両を選択',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...vehicles.map((v) {
            final isSelected = v.id == selectedId;
            return ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: Text(v.displayName),
              subtitle: Text('${v.year}年式'),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.success)
                  : null,
              onTap: () => Navigator.pop(context, v),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
