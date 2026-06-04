import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../models/shop.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import 'shop_inquiry_list_screen.dart';
import 'shop_plan_screen.dart';
import 'shop_registration_screen.dart';
import '../newsletter/newsletter_list_screen.dart';

/// Shop owner hub screen.
///
/// Shows two states:
/// - Unregistered: invitation to list the shop with plan overview
/// - Registered: shop summary card, edit/upgrade/delete actions
class ShopOwnerScreen extends StatefulWidget {
  const ShopOwnerScreen({super.key});

  @override
  State<ShopOwnerScreen> createState() => _ShopOwnerScreenState();
}

class _ShopOwnerScreenState extends State<ShopOwnerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = context.read<AuthProvider>().firebaseUser?.uid;
      if (uid == null) return;

      final provider = context.read<ShopProvider>();
      await provider.loadMyShop(uid);

      // Start real-time inquiry count stream once the shop is known
      if (!mounted) return;
      if (provider.myShop != null) {
        provider.startWatchingInquiries(provider.myShop!.id);
      }
    });
  }

  @override
  void dispose() {
    context.read<ShopProvider>().stopWatchingInquiries();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('掲載管理')),
            body: const AppLoadingCenter(message: '店舗情報を読み込み中...'),
          );
        }

        final shop = provider.myShop;

        return Scaffold(
          appBar: AppBar(title: const Text('掲載管理')),
          body: shop == null
              ? _UnregisteredBody(provider: provider)
              : _RegisteredBody(shop: shop, provider: provider),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unregistered state
// ---------------------------------------------------------------------------

class _UnregisteredBody extends StatelessWidget {
  final ShopProvider provider;

  const _UnregisteredBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.verticalLg,
          // Hero icon
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.store_outlined,
                size: AppSpacing.iconXl,
                color: AppColors.primary,
              ),
            ),
          ),
          AppSpacing.verticalLg,
          Text(
            'あなたの店舗を掲載しましょう',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalSm,
          Text(
            '整備工場・ディーラー・パーツショップなど\n車に関わるあらゆるビジネスを無料で掲載できます。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalXl,
          Text(
            'プランを選択',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.verticalMd,
          // Plan cards
          _PlanSummaryCard(
            plan: ShopPlanType.free,
            price: '0円',
            description: 'まずは無料で試してみましょう',
            features: const [
              '基本情報を掲載',
              '問い合わせ受付',
            ],
            isHighlighted: false,
          ),
          AppSpacing.verticalSm,
          _PlanSummaryCard(
            plan: ShopPlanType.standard,
            price: '9,800円 / 月',
            description: '成長期のショップにおすすめ',
            features: const [
              '画像10枚まで掲載',
              'フィーチャー表示',
              '優先検索表示',
            ],
            isHighlighted: true,
          ),
          AppSpacing.verticalSm,
          _PlanSummaryCard(
            plan: ShopPlanType.premium,
            price: '29,800円 / 月',
            description: '最大限の集客を目指すなら',
            features: const [
              '画像30枚まで掲載',
              'トップページ固定表示',
              '専任サポート担当',
              '月次分析レポート',
            ],
            isHighlighted: false,
          ),
          AppSpacing.verticalXl,
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopRegistrationScreen(),
              ),
            ),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('無料で掲載を始める'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetRecommended),
            ),
          ),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }
}

/// Compact plan summary card for the unregistered state
class _PlanSummaryCard extends StatelessWidget {
  final ShopPlanType plan;
  final String price;
  final String description;
  final List<String> features;
  final bool isHighlighted;

  const _PlanSummaryCard({
    required this.plan,
    required this.price,
    required this.description,
    required this.features,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      backgroundColor: isHighlighted
          ? AppColors.primary.withValues(alpha: 0.05)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PlanBadge(plan: plan),
              const Spacer(),
              Text(
                price,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isHighlighted ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          AppSpacing.verticalXs,
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalXs,
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: AppSpacing.iconSm,
                    color: AppColors.success,
                  ),
                  AppSpacing.horizontalXs,
                  Text(f, style: theme.textTheme.bodySmall),
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
// Registered state
// ---------------------------------------------------------------------------

class _RegisteredBody extends StatelessWidget {
  final Shop shop;
  final ShopProvider provider;

  const _RegisteredBody({required this.shop, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFree = shop.planType == ShopPlanType.free;

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop summary card
          _ShopSummaryCard(shop: shop),
          AppSpacing.verticalMd,
          // Inquiry count badge (tappable → ShopInquiryListScreen)
          _InquiryCountBadge(provider: provider, shopId: shop.id),
          AppSpacing.verticalMd,
          // Newsletter management button
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsletterListScreen(
                  authorId: shop.id,
                  authorName: shop.name,
                ),
              ),
            ),
            icon: const Icon(Icons.mail_outline),
            label: const Text('ニュースレター管理'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
            ),
          ),
          AppSpacing.verticalMd,
          // Edit button
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopRegistrationScreen(existingShop: shop),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('掲載情報を編集'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
            ),
          ),
          // Free plan upgrade banner
          if (isFree) ...[
            AppSpacing.verticalMd,
            _UpgradeBanner(shop: shop),
          ],
          AppSpacing.verticalLg,
          Divider(color: theme.dividerColor),
          AppSpacing.verticalMd,
          // Delete listing button
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              '掲載を削除',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
            ),
          ),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('掲載を削除しますか?'),
        content: const Text(
          'この操作は取り消せません。\n掲載情報・問い合わせ履歴はすべて削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final uid =
        context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    final success = await context.read<ShopProvider>().deleteMyShop(uid);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('掲載を削除しました')),
      );
    } else {
      final err = context.read<ShopProvider>().submitError ?? '削除に失敗しました';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

/// Shop summary card shown in the registered state
class _ShopSummaryCard extends StatelessWidget {
  final Shop shop;

  const _ShopSummaryCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          // Logo
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.backgroundLight,
            backgroundImage:
                shop.logoUrl != null ? NetworkImage(shop.logoUrl!) : null,
            child: shop.logoUrl == null
                ? const Icon(Icons.store, size: 32, color: AppColors.textTertiary)
                : null,
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.verticalXxs,
                Row(
                  children: [
                    _PlanBadge(plan: shop.planType),
                    if (shop.rating != null) ...[
                      AppSpacing.horizontalSm,
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        shop.rating!.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                if (shop.prefecture != null || shop.city != null) ...[
                  AppSpacing.verticalXxs,
                  Text(
                    [shop.prefecture, shop.city]
                        .whereType<String>()
                        .join(' '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge showing inquiry count for the shop owner.
///
/// Tapping navigates to [ShopInquiryListScreen].
class _InquiryCountBadge extends StatelessWidget {
  final ShopProvider provider;
  final String shopId;

  const _InquiryCountBadge({
    required this.provider,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = provider.inquiryTotal;
    final unread = provider.inquiryUnread;
    final hasUnread = unread > 0;

    return InkWell(
      borderRadius: AppSpacing.borderRadiusMd,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShopInquiryListScreen(shopId: shopId),
        ),
      ),
      child: AppCard(
      backgroundColor: hasUnread
          ? AppColors.primary.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            Icons.mail_outline,
            color: hasUnread ? AppColors.info : AppColors.textTertiary,
            size: AppSpacing.iconMd,
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '問い合わせ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasUnread)
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: '全 $total 件',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const TextSpan(text: '（'),
                        TextSpan(
                          text: '未読 $unread 件',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: '）'),
                      ],
                    ),
                  )
                else
                  Text(
                    '問い合わせ $total 件',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
      ),
    );
  }
}

/// Upgrade banner shown only for free plan users
class _UpgradeBanner extends StatelessWidget {
  final Shop shop;

  const _UpgradeBanner({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      backgroundColor: AppColors.warning.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(
            Icons.upgrade_outlined,
            color: AppColors.warning,
            size: AppSpacing.iconMd,
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'プランをアップグレードしませんか?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Standardプランで画像掲載・優先表示が可能になります。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopPlanScreen(
                  shopId: shop.id,
                  currentPlan: shop.planType,
                ),
              ),
            ),
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared: plan badge
// ---------------------------------------------------------------------------

class _PlanBadge extends StatelessWidget {
  final ShopPlanType plan;

  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (plan) {
      ShopPlanType.free => ('Free', AppColors.textTertiary),
      ShopPlanType.standard => ('Standard', AppColors.info),
      ShopPlanType.premium => ('Premium', AppColors.accentCustom),
      ShopPlanType.enterprise => ('Enterprise', AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
