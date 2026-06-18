import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../models/inquiry.dart';
import '../../models/user_plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/loading_indicator.dart';
import 'inquiry_thread_screen.dart';

/// 問い合わせ送信画面
///
/// 設計思想:
/// - 問い合わせ起点はユーザー（ShopDetailScreenの「問い合わせる」ボタンから遷移）
/// - 送信後は確認画面なしでpop（シンプルに完結）
/// - スレッド表示は別途（今回スコープ外）
class InquiryScreen extends StatefulWidget {
  final Shop shop;
  final String? vehicleId;

  /// Pre-fills the subject field. Used when navigating from an AI suggestion.
  final String? prefillSubject;

  /// Pre-fills the message body. Used when navigating from an AI suggestion.
  final String? prefillMessage;

  const InquiryScreen({
    super.key,
    required this.shop,
    this.vehicleId,
    this.prefillSubject,
    this.prefillMessage,
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

  // 写真添付（見積もり時の症状写真など。最大4枚）
  final List<Uint8List> _images = [];
  static const _maxImages = 4;
  bool _uploading = false;

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;
    final bytesList = <Uint8List>[];
    for (final x in picked.take(remaining)) {
      bytesList.add(await x.readAsBytes());
    }
    if (!mounted) return;
    setState(() => _images.addAll(bytesList));
  }

  void _removeImage(int i) => setState(() => _images.removeAt(i));

  @override
  void initState() {
    super.initState();
    if (widget.prefillSubject != null) {
      _subjectController.text = widget.prefillSubject!;
    }
    if (widget.prefillMessage != null) {
      _messageController.text = widget.prefillMessage!;
      _messageLength = widget.prefillMessage!.length;
    }
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

  void _showInquiryLimitDialog(int maxMonthly) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('今月の問い合わせ上限に達しました'),
        content: Text(
          'フリープランでは月$maxMonthly件まで問い合わせできます。\n'
          'プレミアムプランにアップグレードすると無制限になります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
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

    // Free-plan monthly limit pre-check (fail-open: a count failure must
    // never block submission — the server-side rule is the backstop).
    final maxMonthly =
        context.read<UserSubscriptionProvider>().maxMonthlyInquiries;
    if (maxMonthly != UserPlanLimits.unlimited) {
      final count = await shopProvider.countUserInquiriesThisMonth(userId);
      if (!mounted) return;
      if (count != null && count >= maxMonthly) {
        _showInquiryLimitDialog(maxMonthly);
        return;
      }
    }

    // 添付画像を Storage にアップロードして URL を得る
    final attachmentUrls = <String>[];
    if (_images.isNotEmpty) {
      setState(() => _uploading = true);
      final fb = sl.get<FirebaseService>();
      final base = 'inquiries/$userId/${DateTime.now().millisecondsSinceEpoch}';
      for (var i = 0; i < _images.length; i++) {
        final r = await fb.uploadImageBytes(_images[i], '$base/$i.jpg');
        final url = r.valueOrNull;
        if (url != null) attachmentUrls.add(url);
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    final inquiry = await shopProvider.submitInquiry(
      userId: userId,
      shopId: widget.shop.id,
      type: _selectedType,
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
      vehicleId: widget.vehicleId,
      attachmentUrls: attachmentUrls,
    );

    if (!mounted) return;

    if (inquiry != null) {
      // 送信後はスレッド画面へ遷移し、送信したメッセージと履歴を即座に見せる
      // （「送ったあとどうなるの？」という不安を解消する）。
      // SnackBar はルート差し替え前に出す（アプリ直下の ScaffoldMessenger に
      // 紐づくため、遷移後も表示が継続する）。
      showSuccessSnackBar(context, '問い合わせを送信しました。返信はこの画面で確認できます');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => InquiryThreadScreen(inquiry: inquiry),
        ),
      );
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
                AppSpacing.verticalMd,

                // 写真添付（任意・最大4枚）
                _PhotoPicker(
                  images: _images,
                  maxImages: _maxImages,
                  onAdd: _pickImages,
                  onRemove: _removeImage,
                ),

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
              child: Builder(builder: (context) {
                final busy = provider.isSubmitting || _uploading;
                return FilledButton.icon(
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _uploading
                        ? '画像を送信中...'
                        : provider.isSubmitting
                            ? '送信中...'
                            : '送信する',
                  ),
                );
              }),
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
            child:
                shop.logoUrl == null ? const Icon(Icons.store, size: 20) : null,
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
                        child:
                            Icon(Icons.verified, size: 14, color: Colors.blue),
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
// 写真ピッカー（横スクロールのサムネイル＋追加タイル）
// ---------------------------------------------------------------------------

class _PhotoPicker extends StatelessWidget {
  final List<Uint8List> images;
  final int maxImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoPicker({
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '写真を添付（任意・最大$maxImages枚）',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '症状や気になる箇所の写真を添えると、見積もりがスムーズです。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < images.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          images[i],
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (images.length < maxImages)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 2),
                        Text('追加',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
