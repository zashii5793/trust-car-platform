import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/part_listing.dart';
import '../../models/user_part_listing.dart';
import '../../services/part_listing_service.dart';

/// Screen for creating or editing a user-submitted part listing.
///
/// Pass [existingListing] to open in edit mode; omit (null) for new listing.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key, this.existingListing});

  /// When non-null, the screen opens in edit mode pre-filled with this data.
  final UserPartListing? existingListing;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _compatibleVehicleController = TextEditingController();

  PartCategory _selectedCategory = PartCategory.other;
  PartCondition _selectedCondition = PartCondition.goodCondition;
  ShippingMethod _selectedShippingMethod = ShippingMethod.includedInPrice;

  /// Existing image URLs loaded from the listing being edited. Kept as-is on save.
  final List<String> _existingImageUrls = [];

  /// Newly selected image files to upload on save.
  final List<File> _newImages = [];

  bool _isSubmitting = false;

  static const int _maxImages = 5;
  static const int _maxDescriptionLength = 1000;

  bool get _isEditMode => widget.existingListing != null;

  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields when editing an existing listing
    final existing = widget.existingListing;
    if (existing != null) {
      _titleController.text = existing.title;
      _priceController.text = existing.price.toString();
      _descriptionController.text = existing.description;
      _compatibleVehicleController.text = existing.compatibleVehicle ?? '';
      _selectedCategory = existing.category;
      _selectedCondition = existing.condition;
      _selectedShippingMethod = existing.shippingMethod;
      // Load existing image URLs so they are preserved on save.
      _existingImageUrls.addAll(existing.imageUrls);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _compatibleVehicleController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Computed helpers
  // -----------------------------------------------------------------------

  int get _price => int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;

  int get _payout => calculatePayout(_price);

  bool get _canSubmit {
    final titleOk = _titleController.text.trim().isNotEmpty;
    final priceOk = _price > 0;
    return titleOk && priceOk && !_isSubmitting;
  }

  // -----------------------------------------------------------------------
  // Image picker
  // -----------------------------------------------------------------------

  Future<void> _pickImage() async {
    if (_totalImageCount >= _maxImages) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _newImages.add(File(picked.path));
    });
  }

  /// Removes an image by unified index (existing URLs first, then new files).
  void _removeImage(int index) {
    setState(() {
      if (index < _existingImageUrls.length) {
        _existingImageUrls.removeAt(index);
      } else {
        _newImages.removeAt(index - _existingImageUrls.length);
      }
    });
  }

  // -----------------------------------------------------------------------
  // Submit
  // -----------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    final service = ServiceLocator.instance.get<PartListingService>();
    final compatibleVehicle = _compatibleVehicleController.text.trim().isEmpty
        ? null
        : _compatibleVehicleController.text.trim();

    Result<dynamic, AppError> result;

    if (_isEditMode) {
      result = await service.updateListing(
        UpdatePartListingInput(
          listingId: widget.existingListing!.id,
          title: _titleController.text.trim(),
          category: _selectedCategory,
          condition: _selectedCondition,
          price: _price,
          description: _descriptionController.text.trim(),
          compatibleVehicle: compatibleVehicle,
          existingImageUrls: List.unmodifiable(_existingImageUrls),
          newImages: List.unmodifiable(_newImages),
          shippingMethod: _selectedShippingMethod,
        ),
      );
    } else {
      result = await service.createListing(
        CreatePartListingInput(
          title: _titleController.text.trim(),
          category: _selectedCategory,
          condition: _selectedCondition,
          price: _price,
          description: _descriptionController.text.trim(),
          compatibleVehicle: compatibleVehicle,
          images: List.unmodifiable(_newImages),
          shippingMethod: _selectedShippingMethod,
        ),
      );
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? '更新しました' : '出品しました')),
        );
        Navigator.of(context).pop(true);
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '出品を編集' : '出品する'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditMode ? '更新' : '出品'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            // Image picker section
            _SectionLabel(label: '商品画像（最大$_maxImages枚）'),
            AppSpacing.verticalXs,
            _ImagePickerRow(
              existingUrls: _existingImageUrls,
              newImages: _newImages,
              maxImages: _maxImages,
              onAdd: _pickImage,
              onRemove: _removeImage,
            ),
            AppSpacing.verticalLg,

            // Title
            _SectionLabel(label: '商品名', required: true),
            AppSpacing.verticalXs,
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '例: BLITZ 車高調 ZZ-R',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '商品名を入力してください';
                return null;
              },
            ),
            AppSpacing.verticalLg,

            // Category
            _SectionLabel(label: 'カテゴリ', required: true),
            AppSpacing.verticalXs,
            _CategoryDropdown(
              value: _selectedCategory,
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            AppSpacing.verticalLg,

            // Condition
            _SectionLabel(label: '商品の状態', required: true),
            AppSpacing.verticalXs,
            _ConditionDropdown(
              value: _selectedCondition,
              onChanged: (v) => setState(() => _selectedCondition = v!),
            ),
            AppSpacing.verticalLg,

            // Price
            _SectionLabel(label: '販売価格', required: true),
            AppSpacing.verticalXs,
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                prefixText: '¥',
                hintText: '0',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return '価格を入力してください';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return '1円以上の価格を入力してください';
                return null;
              },
            ),
            // Commission hint
            if (_price > 0) ...[
              AppSpacing.verticalXs,
              _CommissionHint(price: _price, payout: _payout),
            ],
            AppSpacing.verticalLg,

            // Description
            _SectionLabel(label: '商品説明'),
            AppSpacing.verticalXs,
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              maxLength: _maxDescriptionLength,
              decoration: const InputDecoration(
                hintText: '状態の詳細、購入時期、使用期間など',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            AppSpacing.verticalLg,

            // Compatible vehicle
            _SectionLabel(label: '対応車種（任意）'),
            AppSpacing.verticalXs,
            TextFormField(
              controller: _compatibleVehicleController,
              decoration: const InputDecoration(
                hintText: '例: トヨタ 86 / スバル BRZ（ZN6/ZC6系）',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            AppSpacing.verticalLg,

            // Shipping method
            _SectionLabel(label: '取引方法', required: true),
            AppSpacing.verticalXs,
            _ShippingDropdown(
              value: _selectedShippingMethod,
              onChanged: (v) => setState(() => _selectedShippingMethod = v!),
            ),
            AppSpacing.verticalXl,

            // Submit button (bottom)
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.tapTargetRecommended),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditMode ? '更新する' : '出品する'),
            ),
            AppSpacing.verticalXl,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _SectionLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            '必須',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image picker row
// ---------------------------------------------------------------------------

class _ImagePickerRow extends StatelessWidget {
  /// URLs of images already saved (from an existing listing).
  final List<String> existingUrls;

  /// Newly picked local files (not yet uploaded).
  final List<File> newImages;

  final int maxImages;
  final VoidCallback onAdd;

  /// Unified remove callback: indices 0..existingUrls.length-1 map to
  /// existing URLs; higher indices map to newImages.
  final void Function(int index) onRemove;

  const _ImagePickerRow({
    required this.existingUrls,
    required this.newImages,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  int get _total => existingUrls.length + newImages.length;

  Widget _removeButton(int index) {
    return Positioned(
      top: 2,
      right: 2,
      child: GestureDetector(
        onTap: () => onRemove(index),
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing URL thumbnails (network images)
          ...existingUrls.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusSm,
                    child: Image.network(
                      entry.value,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 90,
                        height: 90,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  _removeButton(entry.key),
                ],
              ),
            );
          }),

          // Newly picked file thumbnails
          ...newImages.asMap().entries.map((entry) {
            final unifiedIndex = existingUrls.length + entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusSm,
                    child: Image.file(
                      entry.value,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  _removeButton(unifiedIndex),
                ],
              ),
            );
          }),

          // Add button (only when under the limit)
          if (_total < maxImages)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1.5,
                  ),
                  borderRadius: AppSpacing.borderRadiusSm,
                  color: theme.colorScheme.surfaceContainerLowest,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_total/$maxImages',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category dropdown
// ---------------------------------------------------------------------------

class _CategoryDropdown extends StatelessWidget {
  final PartCategory value;
  final ValueChanged<PartCategory?> onChanged;

  // Categories shown in the selector (subset matching the task spec)
  static const _categories = [
    PartCategory.performance,  // エンジン系
    PartCategory.suspension,   // 足回り
    PartCategory.exterior,     // 外装
    PartCategory.interior,     // 内装
    PartCategory.navigation,   // 電装
    PartCategory.tire,         // タイヤ
    PartCategory.wheel,        // ホイール
    PartCategory.exhaust,      // マフラー
    PartCategory.brake,        // ブレーキ
    PartCategory.aero,         // エアロ
    PartCategory.lighting,     // ライト
    PartCategory.audio,        // オーディオ
    PartCategory.maintenance,  // メンテナンス
    PartCategory.accessory,    // アクセサリー
    PartCategory.other,        // その他
  ];

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PartCategory>(
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _categories.map((cat) {
        return DropdownMenuItem(
          value: cat,
          child: Text(cat.displayName),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Condition dropdown
// ---------------------------------------------------------------------------

class _ConditionDropdown extends StatelessWidget {
  final PartCondition value;
  final ValueChanged<PartCondition?> onChanged;

  const _ConditionDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PartCondition>(
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: PartCondition.values.map((cond) {
        return DropdownMenuItem(
          value: cond,
          child: Text(cond.displayName),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Shipping method dropdown
// ---------------------------------------------------------------------------

class _ShippingDropdown extends StatelessWidget {
  final ShippingMethod value;
  final ValueChanged<ShippingMethod?> onChanged;

  const _ShippingDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ShippingMethod>(
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: ShippingMethod.values.map((method) {
        return DropdownMenuItem(
          value: method,
          child: Text(method.displayName),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Commission hint widget
// ---------------------------------------------------------------------------

class _CommissionHint extends StatelessWidget {
  final int price;
  final int payout;

  const _CommissionHint({required this.price, required this.payout});

  String _formatPrice(int v) {
    return v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusXs,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '販売手数料 8%（最低100円）が差し引かれます',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '受取金額: ¥${_formatPrice(payout)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
