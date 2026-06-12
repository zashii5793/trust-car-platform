import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/post.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/firebase_service.dart';

/// Post creation screen
///
/// Supports category selection, text input, image attachment (up to 3),
/// and optional vehicle tag from the current user's vehicle list.
class PostCreateScreen extends StatefulWidget {
  /// Pre-filled content (e.g. from a maintenance record share).
  final String? initialContent;

  /// Pre-selected vehicle ID (matched against VehicleProvider).
  final String? initialVehicleId;

  /// Pre-selected category.
  final PostCategory? initialCategory;

  const PostCreateScreen({
    super.key,
    this.initialContent,
    this.initialVehicleId,
    this.initialCategory,
  });

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _contentController = TextEditingController();

  PostCategory _selectedCategory = PostCategory.general;

  /// Visibility setting for this post
  PostVisibility _selectedVisibility = PostVisibility.public;

  /// Selected vehicle for tagging
  Vehicle? _selectedVehicle;

  /// Images selected for upload (max 3)
  final List<Uint8List> _pickedImages = [];
  bool _isUploadingImages = false;

  static const int _maxLength = 500;
  static const int _maxImages = 3;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    // Pre-select vehicle after first frame (VehicleProvider may not be ready yet)
    if (widget.initialVehicleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vehicles = context.read<VehicleProvider>().vehicles;
        final match = vehicles
            .where((v) => v.id == widget.initialVehicleId)
            .firstOrNull;
        if (match != null) {
          setState(() => _selectedVehicle = match);
        }
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    if (_pickedImages.length >= _maxImages) return;

    final picker = ImagePicker();
    final remaining = _maxImages - _pickedImages.length;
    final picked = await picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
      limit: remaining,
    );

    if (picked.isEmpty) return;

    final newBytes = <Uint8List>[];
    for (final xFile in picked) {
      newBytes.add(await xFile.readAsBytes());
    }

    setState(() => _pickedImages.addAll(newBytes));
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
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

    // Upload images to Firebase Storage if any are selected.
    List<String> imageUrls = [];
    if (_pickedImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      final firebaseService = ServiceLocator.instance.get<FirebaseService>();
      final basePath =
          'post_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}';
      int uploadFailCount = 0;

      for (int i = 0; i < _pickedImages.length; i++) {
        final result = await firebaseService.uploadImageBytes(
          _pickedImages[i],
          '$basePath/image_$i.jpg',
        );
        if (result.isSuccess && result.valueOrNull != null) {
          imageUrls.add(result.valueOrNull!);
        } else {
          uploadFailCount++;
        }
      }

      if (!mounted) return;
      setState(() => _isUploadingImages = false);

      // Notify the user if any images failed to upload
      if (uploadFailCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$uploadFailCount枚の画像のアップロードに失敗しました'),
            backgroundColor: AppColors.error,
          ),
        );
        if (imageUrls.isEmpty) return; // All images failed — abort post
      }
    }

    final success = await postProvider.createPost(
      userId: user.uid,
      content: content,
      category: _selectedCategory,
      visibility: _selectedVisibility,
      userDisplayName: user.displayName,
      userPhotoUrl: user.photoURL,
      imageUrls: imageUrls,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました')),
      );
    } else {
      final msg = postProvider.submitErrorMessage ?? '投稿に失敗しました。もう一度お試しください。';
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
                  final canSubmit =
                      value.text.trim().isNotEmpty && !_isUploadingImages;
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

          // ── Visibility selector ───────────────────────────────────────────
          _SectionLabel(label: '公開範囲'),
          AppSpacing.verticalSm,
          _VisibilitySelector(
            selected: _selectedVisibility,
            onChanged: (v) => setState(() => _selectedVisibility = v),
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
          _SectionLabel(label: '画像（任意・最大3枚）'),
          AppSpacing.verticalSm,
          _ImageAttachmentPicker(
            images: _pickedImages,
            maxImages: _maxImages,
            isUploading: _isUploadingImages,
            onAdd: _pickImages,
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
                  final isBusy = provider.isSubmitting || _isUploadingImages;
                  final canSubmit = value.text.trim().isNotEmpty && !isBusy;
                  return FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _isUploadingImages
                          ? '画像をアップロード中...'
                          : provider.isSubmitting
                              ? '投稿中...'
                              : '投稿する',
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
// Visibility selector
// ---------------------------------------------------------------------------

class _VisibilitySelector extends StatelessWidget {
  final PostVisibility selected;
  final ValueChanged<PostVisibility> onChanged;

  const _VisibilitySelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PostVisibility>(
      segments: const [
        ButtonSegment(
          value: PostVisibility.public,
          icon: Icon(Icons.public, size: 16),
          label: Text('全体公開'),
        ),
        ButtonSegment(
          value: PostVisibility.followers,
          icon: Icon(Icons.group, size: 16),
          label: Text('フォロワーのみ'),
        ),
        ButtonSegment(
          value: PostVisibility.private_,
          icon: Icon(Icons.lock, size: 16),
          label: Text('自分のみ'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
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
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
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
// Image attachment picker
// ---------------------------------------------------------------------------

class _ImageAttachmentPicker extends StatelessWidget {
  final List<Uint8List> images;
  final int maxImages;
  final bool isUploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImageAttachmentPicker({
    required this.images,
    required this.maxImages,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = images.length < maxImages && !isUploading;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Thumbnail previews with remove button
        ...images.asMap().entries.map((entry) {
          final index = entry.key;
          final bytes = entry.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  bytes,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),

        // Add button (hidden when limit reached)
        if (canAdd)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 28,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
