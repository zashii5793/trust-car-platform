import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../models/shop.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_card.dart';

/// Shop registration and edit form screen.
///
/// Used for both new registration and editing an existing shop.
/// Pass [existingShop] to switch to edit mode.
class ShopRegistrationScreen extends StatefulWidget {
  final Shop? existingShop;

  const ShopRegistrationScreen({super.key, this.existingShop});

  @override
  State<ShopRegistrationScreen> createState() => _ShopRegistrationScreenState();
}

class _ShopRegistrationScreenState extends State<ShopRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _prefectureController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;

  late ShopType _selectedType;
  late Set<ServiceCategory> _selectedServices;
  late ShopPlanType _selectedPlan;

  bool get _isEditMode => widget.existingShop != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingShop;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _websiteController = TextEditingController(text: s?.website ?? '');
    _prefectureController = TextEditingController(text: s?.prefecture ?? '');
    _cityController = TextEditingController(text: s?.city ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _selectedType = s?.type ?? ShopType.maintenanceShop;
    _selectedServices = s != null ? Set.from(s.services) : {};
    _selectedPlan = s?.planType ?? ShopPlanType.free;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    final provider = context.read<ShopProvider>();

    final success = await provider.saveMyShop(
      Shop(
        id: widget.existingShop?.id ?? uid,
        name: _nameController.text.trim(),
        type: _selectedType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        prefecture: _prefectureController.text.trim().isEmpty
            ? null
            : _prefectureController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        services: _selectedServices.toList(),
        planType: _selectedPlan,
        ownerId: uid,
        imageUrls: widget.existingShop?.imageUrls ?? [],
        supportedMakerIds: widget.existingShop?.supportedMakerIds ?? [],
        businessHours: widget.existingShop?.businessHours ?? {},
        isVerified: widget.existingShop?.isVerified ?? false,
        isFeatured: widget.existingShop?.isFeatured ?? false,
        isActive: true,
        rating: widget.existingShop?.rating,
        reviewCount: widget.existingShop?.reviewCount ?? 0,
        createdAt: widget.existingShop?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      final err = provider.submitError ?? '保存に失敗しました';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditMode ? '掲載情報を編集' : '店舗を登録'),
            actions: [
              if (provider.isSubmitting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _submit,
                  child: const Text('保存'),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.paddingScreen,
              children: [
                // Section 1: Basic info
                _SectionHeader(title: '基本情報'),
                AppSpacing.verticalSm,
                _LabeledField(
                  label: '店舗名',
                  isRequired: true,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: '例: トラスト自動車整備工場',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '店舗名を入力してください' : null,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalMd,
                _LabeledField(
                  label: '業種',
                  isRequired: true,
                  child: DropdownButtonFormField<ShopType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(),
                    items: ShopType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedType = v);
                    },
                  ),
                ),
                AppSpacing.verticalMd,
                _LabeledField(
                  label: '説明文',
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: '店舗の特徴・強みなどを記入してください（最大500文字）',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalXl,

                // Section 2: Contact
                _SectionHeader(title: '連絡先'),
                AppSpacing.verticalSm,
                _LabeledField(
                  label: '電話番号',
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      hintText: '例: 03-1234-5678',
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalMd,
                _LabeledField(
                  label: 'メールアドレス',
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: '例: info@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalMd,
                _LabeledField(
                  label: 'ウェブサイト',
                  child: TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      hintText: '例: https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalXl,

                // Section 3: Location
                _SectionHeader(title: '所在地'),
                AppSpacing.verticalSm,
                _LabeledField(
                  label: '都道府県',
                  child: TextFormField(
                    controller: _prefectureController,
                    decoration: const InputDecoration(
                      hintText: '例: 東京都',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalMd,
                _LabeledField(
                  label: '市区町村',
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      hintText: '例: 渋谷区',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalMd,
                _LabeledField(
                  label: '住所',
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: '例: 〇〇町1-2-3 〇〇ビル1F',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                AppSpacing.verticalXl,

                // Section 4: Services
                _SectionHeader(title: 'サービス'),
                AppSpacing.verticalSm,
                Text(
                  '提供しているサービスをすべて選択してください',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                AppSpacing.verticalSm,
                _ServiceMultiSelect(
                  selectedServices: _selectedServices,
                  onChanged: (services) =>
                      setState(() => _selectedServices = services),
                ),
                AppSpacing.verticalXl,

                // Section 5: Plan
                _SectionHeader(title: 'プラン選択'),
                AppSpacing.verticalSm,
                _PlanCard(
                  plan: ShopPlanType.free,
                  price: '0円',
                  features: const [
                    '基本情報を掲載',
                    '問い合わせ受付',
                  ],
                  selected: _selectedPlan == ShopPlanType.free,
                  onTap: () =>
                      setState(() => _selectedPlan = ShopPlanType.free),
                ),
                AppSpacing.verticalSm,
                _PlanCard(
                  plan: ShopPlanType.standard,
                  price: '9,800円 / 月',
                  features: const [
                    '画像10枚まで掲載',
                    'フィーチャー表示',
                    '優先検索表示',
                  ],
                  selected: _selectedPlan == ShopPlanType.standard,
                  onTap: () =>
                      setState(() => _selectedPlan = ShopPlanType.standard),
                ),
                AppSpacing.verticalSm,
                _PlanCard(
                  plan: ShopPlanType.premium,
                  price: '29,800円 / 月',
                  features: const [
                    '画像30枚まで掲載',
                    'トップページ固定表示',
                    '専任サポート担当',
                    '月次分析レポート',
                  ],
                  selected: _selectedPlan == ShopPlanType.premium,
                  onTap: () =>
                      setState(() => _selectedPlan = ShopPlanType.premium),
                ),
                AppSpacing.verticalXl,

                // Save button (bottom)
                FilledButton(
                  onPressed: provider.isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(AppSpacing.tapTargetRecommended),
                  ),
                  child: Text(provider.isSubmitting ? '保存中...' : '保存する'),
                ),
                AppSpacing.verticalLg,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Labeled field wrapper
// ---------------------------------------------------------------------------

class _LabeledField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final Widget child;

  const _LabeledField({
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: AppSpacing.xxs),
              const Text(
                '*',
                style: TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Service multi-select chips
// ---------------------------------------------------------------------------

class _ServiceMultiSelect extends StatelessWidget {
  final Set<ServiceCategory> selectedServices;
  final ValueChanged<Set<ServiceCategory>> onChanged;

  const _ServiceMultiSelect({
    required this.selectedServices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: ServiceCategory.values.map((category) {
        final isSelected = selectedServices.contains(category);
        return FilterChip(
          label: Text(category.displayName),
          selected: isSelected,
          onSelected: (selected) {
            final next = Set<ServiceCategory>.from(selectedServices);
            if (selected) {
              next.add(category);
            } else {
              next.remove(category);
            }
            onChanged(next);
          },
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan selection card
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final ShopPlanType plan;
  final String price;
  final List<String> features;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.price,
    required this.features,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        backgroundColor:
            selected ? AppColors.primary.withValues(alpha: 0.06) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _planIcon,
                AppSpacing.horizontalSm,
                Text(
                  _planLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
                const Spacer(),
                Text(
                  price,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                AppSpacing.horizontalSm,
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.textTertiary,
                ),
              ],
            ),
            AppSpacing.verticalSm,
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: AppSpacing.iconSm,
                      color:
                          selected ? AppColors.primary : AppColors.textTertiary,
                    ),
                    AppSpacing.horizontalXs,
                    Text(
                      f,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected ? null : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _planLabel => switch (plan) {
        ShopPlanType.free => 'Free',
        ShopPlanType.standard => 'Standard',
        ShopPlanType.premium => 'Premium',
        ShopPlanType.enterprise => 'Enterprise',
      };

  Widget get _planIcon {
    final (icon, color) = switch (plan) {
      ShopPlanType.free => (Icons.store_outlined, AppColors.textTertiary),
      ShopPlanType.standard => (
          Icons.workspace_premium_outlined,
          AppColors.info
        ),
      ShopPlanType.premium => (Icons.diamond_outlined, AppColors.accentCustom),
      ShopPlanType.enterprise => (Icons.corporate_fare, AppColors.primary),
    };
    return Icon(icon, size: AppSpacing.iconMd, color: color);
  }
}
