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
            title: Text('${widget.shop.name}への問い合わせ'),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.paddingScreen,
              children: [
                // 問い合わせ種別
                _InquiryTypeSelector(
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

                // 本文
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: '本文',
                    hintText: 'お問い合わせ内容をご記入ください',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '本文を入力してください';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalMd,

                // 車両情報（vehicleId指定時のみ）
                if (widget.vehicleId != null)
                  _VehicleInfoBadge(vehicleId: widget.vehicleId!),

                AppSpacing.verticalLg,

                // 注意文
                Container(
                  padding: AppSpacing.paddingCard,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: const Text(
                    '返信まで数日かかる場合があります。\n'
                    '緊急の場合は直接お電話ください。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
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
// 問い合わせ種別セレクター
// ---------------------------------------------------------------------------

class _InquiryTypeSelector extends StatelessWidget {
  final InquiryType selected;
  final ValueChanged<InquiryType> onChanged;

  const _InquiryTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '問い合わせ種別',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<InquiryType>(
          value: selected,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          items: InquiryType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.displayName),
            );
          }).toList(),
          onChanged: (type) {
            if (type != null) onChanged(type);
          },
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
