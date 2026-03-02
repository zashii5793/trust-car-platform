import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../models/inquiry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// 問い合わせ送信画面
///
/// 設計思想:
/// - 問い合わせ起点はユーザー（ShopDetailScreenの「問い合わせる」ボタンから遷移）
/// - 送信後は確認画面なしでpop（シンプルに完結）
/// - スレッド表示は別途（今回スコープ外）
class InquiryScreen extends StatefulWidget {
  final Shop shop;
  final String? vehicleId;

  const InquiryScreen({
    super.key,
    required this.shop,
    this.vehicleId,
  });

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  InquiryType _selectedType = InquiryType.estimate;
  int _messageLength = 0;

  static const _maxMessageLength = 500;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() => _messageLength = _messageController.text.length);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final shopProvider = context.read<ShopProvider>();
    final userId = authProvider.firebaseUser?.uid;

    if (userId == null) {
      showErrorSnackBar(context, 'ログインが必要です');
      return;
    }

    final inquiry = await shopProvider.submitInquiry(
      userId: userId,
      shopId: widget.shop.id,
      type: _selectedType,
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
      vehicleId: widget.vehicleId,
    );

    if (!mounted) return;

    if (inquiry != null) {
      showSuccessSnackBar(context, '問い合わせを送信しました');
      Navigator.pop(context);
    } else {
      final error = shopProvider.error;
      if (error != null) {
        showAppErrorSnackBar(context, error);
      } else {
        showErrorSnackBar(context, '問い合わせの送信に失敗しました。再度お試しください。');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('問い合わせ'),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.paddingScreen,
              children: [
                // 送信先の工場ミニカード（誤送信防止）
                _ShopMiniCard(shop: widget.shop),
                AppSpacing.verticalMd,

                // 問い合わせ種別（ChoiceChip）
                _InquiryTypeChips(
                  selected: _selectedType,
                  onChanged: (type) => setState(() => _selectedType = type),
                ),
                AppSpacing.verticalMd,

                // 件名
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: '件名',
                    hintText: '例: 車検の見積もりについて',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '件名を入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // 本文（文字数カウンタ付き）
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'お問い合わせ内容',
                    hintText: '詳しい内容をご記入ください',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    counterText: '$_messageLength / $_maxMessageLength',
                    counterStyle: TextStyle(
                      color: _messageLength >= _maxMessageLength
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  maxLines: 6,
                  maxLength: _maxMessageLength,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null, // counterText に委譲するため null
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'お問い合わせ内容を入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalXs,

                // 車両情報（vehicleId指定時のみ）
                if (widget.vehicleId != null) ...[
                  AppSpacing.verticalXs,
                  _VehicleInfoBadge(vehicleId: widget.vehicleId!),
                ],

                AppSpacing.verticalLg,

                // 注意文（アイコン付き）
                _DisclaimerBox(),

                AppSpacing.verticalXl,
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                onPressed: provider.isSubmitting ? null : _submit,
                icon: provider.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(provider.isSubmitting ? '送信中...' : '送信する'),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 送信先工場ミニカード（誤送信防止 + 安心感）
// ---------------------------------------------------------------------------

class _ShopMiniCard extends StatelessWidget {
  final Shop shop;

  const _ShopMiniCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage:
                shop.logoUrl != null ? NetworkImage(shop.logoUrl!) : null,
            child: shop.logoUrl == null
                ? const Icon(Icons.store, size: 20)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '送信先',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (shop.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified, size: 14, color: Colors.blue),
                      ),
                  ],
                ),
                Text(
                  shop.type.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 問い合わせ種別（ChoiceChip）
// ---------------------------------------------------------------------------

class _InquiryTypeChips extends StatelessWidget {
  final InquiryType selected;
  final ValueChanged<InquiryType> onChanged;

  // 主要な問い合わせ種別（画面に表示する順序）
  static const _primaryTypes = [
    InquiryType.estimate,
    InquiryType.appointment,
    InquiryType.serviceInquiry,
    InquiryType.partInquiry,
    InquiryType.vehiclePurchase,
    InquiryType.vehicleSale,
    InquiryType.general,
  ];

  const _InquiryTypeChips({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '問い合わせの種別',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _primaryTypes.map((type) {
            final isSelected = type == selected;
            return ChoiceChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (_) => onChanged(type),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 車両情報バッジ
// ---------------------------------------------------------------------------

class _VehicleInfoBadge extends StatelessWidget {
  final String vehicleId;

  const _VehicleInfoBadge({required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_outlined, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '車両情報を添付して送信します',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 注意文ボックス
// ---------------------------------------------------------------------------

class _DisclaimerBox extends StatelessWidget {
  const _DisclaimerBox();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '通常1〜3営業日以内に返信いたします。\n緊急の場合は直接お電話ください。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
