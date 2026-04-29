import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/shop.dart';
import '../../providers/subscription_provider.dart';
import '../../services/shop_subscription_service.dart';
import '../../widgets/common/loading_indicator.dart';

/// BtoB shop plan upgrade screen.
///
/// Displays all 4 plan tiers with pricing and features.
/// Purchase flow requires RevenueCat integration (Phase 7 Week 2).
class ShopPlanScreen extends StatelessWidget {
  final String shopId;
  final ShopPlanType currentPlan;

  const ShopPlanScreen({
    super.key,
    required this.shopId,
    required this.currentPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プランを選択'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.verticalLg,
            Text(
              '店舗ビジネスを成長させましょう',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalXs,
            Text(
              '30日間の無料トライアルから始められます',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalXxl,
            _PlanCard(
              planType: ShopPlanType.free,
              currentPlan: currentPlan,
              shopId: shopId,
            ),
            AppSpacing.verticalMd,
            _PlanCard(
              planType: ShopPlanType.standard,
              currentPlan: currentPlan,
              shopId: shopId,
              isRecommended: currentPlan == ShopPlanType.free,
            ),
            AppSpacing.verticalMd,
            _PlanCard(
              planType: ShopPlanType.premium,
              currentPlan: currentPlan,
              shopId: shopId,
            ),
            AppSpacing.verticalMd,
            _PlanCard(
              planType: ShopPlanType.enterprise,
              currentPlan: currentPlan,
              shopId: shopId,
            ),
            AppSpacing.verticalXxl,
            Text(
              '※ 課金はApp Store / Google Playを通じて処理されます。\n'
              'サブスクリプションはいつでもキャンセルできます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalLg,
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ShopPlanType planType;
  final ShopPlanType currentPlan;
  final String shopId;
  final bool isRecommended;

  const _PlanCard({
    required this.planType,
    required this.currentPlan,
    required this.shopId,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limits = ShopSubscriptionService().getPlanLimits(planType);
    final isCurrent = planType == currentPlan;
    final isDowngrade = planType.index < currentPlan.index;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: isRecommended ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isRecommended ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan header
                Row(
                  children: [
                    Text(
                      planType.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? AppColors.primary : null,
                      ),
                    ),
                    if (isCurrent) ...[
                      AppSpacing.horizontalSm,
                      Chip(
                        label: const Text('現在のプラン'),
                        labelStyle: const TextStyle(fontSize: 11),
                        backgroundColor:
                            AppColors.primary.withAlpha((0.15 * 255).round()),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    const Spacer(),
                    if (planType.monthlyPrice != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '¥${_formatPrice(planType.monthlyPrice!)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/月',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      )
                    else
                      Text(
                        '無料',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),

                const Divider(height: AppSpacing.lg),

                // Feature list
                _FeatureRow(
                  icon: Icons.mail_outline,
                  label: limits.maxMonthlyInquiries < 0
                      ? '問い合わせ受信: 無制限'
                      : '問い合わせ受信: 月${limits.maxMonthlyInquiries}件まで',
                ),
                _FeatureRow(
                  icon: Icons.photo_library_outlined,
                  label: limits.maxPhotos < 0
                      ? '写真: 無制限'
                      : '写真: ${limits.maxPhotos}枚まで',
                ),
                if (limits.hasPriorityDisplay)
                  const _FeatureRow(
                    icon: Icons.star_outline,
                    label: '検索結果での優先表示',
                    highlight: true,
                  ),
                if (limits.hasMonthlyReport)
                  const _FeatureRow(
                    icon: Icons.bar_chart,
                    label: '月次レポート（問い合わせ数・閲覧数）',
                    highlight: true,
                  ),
                if (planType == ShopPlanType.enterprise) ...[
                  const _FeatureRow(
                    icon: Icons.store_outlined,
                    label: '複数店舗管理（最大5店舗）',
                    highlight: true,
                  ),
                  const _FeatureRow(
                    icon: Icons.support_agent,
                    label: '専任サポート担当',
                    highlight: true,
                  ),
                ],

                AppSpacing.verticalMd,

                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: _PlanButton(
                    planType: planType,
                    isCurrent: isCurrent,
                    isDowngrade: isDowngrade,
                    shopId: shopId,
                    currentPlan: currentPlan,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isRecommended)
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'おすすめ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _FeatureRow({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? AppColors.primary : null,
          ),
          AppSpacing.horizontalSm,
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: highlight ? AppColors.primary : null,
                    fontWeight: highlight ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanButton extends StatefulWidget {
  final ShopPlanType planType;
  final ShopPlanType currentPlan;
  final bool isCurrent;
  final bool isDowngrade;
  final String shopId;

  const _PlanButton({
    required this.planType,
    required this.currentPlan,
    required this.isCurrent,
    required this.isDowngrade,
    required this.shopId,
  });

  @override
  State<_PlanButton> createState() => _PlanButtonState();
}

class _PlanButtonState extends State<_PlanButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (widget.isCurrent || _isLoading) {
      return;
    }

    if (widget.planType == ShopPlanType.free && widget.currentPlan != ShopPlanType.free) {
      await _confirmDowngrade();
      return;
    }

    await _startPurchase();
  }

  Future<void> _confirmDowngrade() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('無料プランに変更'),
        content: const Text(
          'フリープランに変更すると、現在のサブスクリプションは期間終了時にキャンセルされます。\n'
          '変更しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('変更する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _applyPlanChange(
        ShopPlanType.free,
        ShopSubscriptionStatus.free,
      );
    }
  }

  Future<void> _startPurchase() async {
    // TODO(phase7-week2): RevenueCat purchase flow
    // final packageId = _productIdFor(widget.planType);
    // final result = await Purchases.purchasePackage(package);
    // On success, Cloud Functions webhook updates Firestore automatically.

    showSuccessSnackBar(
      context,
      'RevenueCat連携後に課金処理が有効になります（Phase 7 Week 2）',
    );
  }

  Future<void> _applyPlanChange(
    ShopPlanType newPlan,
    ShopSubscriptionStatus status,
  ) async {
    setState(() => _isLoading = true);

    final provider = context.read<SubscriptionProvider>();
    final success = await provider.updatePlan(
      shopId: widget.shopId,
      newPlan: newPlan,
      subscriptionStatus: status,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showSuccessSnackBar(context, 'プランを変更しました');
      Navigator.of(context).pop();
    } else {
      showSuccessSnackBar(context, 'プランの変更に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCurrent) {
      return OutlinedButton(
        onPressed: null,
        child: const Text('現在のプラン'),
      );
    }

    if (_isLoading) {
      return ElevatedButton(
        onPressed: null,
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.isDowngrade) {
      return OutlinedButton(
        onPressed: _handleTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
        ),
        child: const Text('ダウングレード'),
      );
    }

    return ElevatedButton(
      onPressed: _handleTap,
      child: widget.planType == ShopPlanType.standard ||
              widget.planType == ShopPlanType.premium
          ? const Text('30日間無料で始める')
          : const Text('アップグレード'),
    );
  }
}
