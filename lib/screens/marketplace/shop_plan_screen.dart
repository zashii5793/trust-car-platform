import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../core/error/app_error.dart';
import '../../models/shop.dart';
import '../../models/shop_plan_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_plan_request_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/revenue_cat_service.dart';
import '../../services/shop_plan_request_service.dart';
import '../../services/shop_subscription_service.dart';
import '../../widgets/common/loading_indicator.dart';

/// 店舗プランをアプリ内課金（RevenueCat）で売るか。
///
/// 2026-09-29 のオーナー判断で、店舗プランは当面、請求書払い（銀行振込）。
/// 既定は false で、有料プランは「請求書払いで申し込む」流れになる
/// （shops/{shopId}/plan_requests）。10店舗程度になってクレジット決済を
/// 足すときに、Remote Config の `shop_in_app_purchase` で戻せるよう、
/// 購入処理は消さずに残してある。
bool get _useInAppPurchase => isFeatureEnabled(FeatureFlag.shopInAppPurchase);

/// BtoB shop plan screen.
///
/// Displays all 4 plan tiers with pricing and features.
/// 既定は請求書払いの申し込み。プランの切り替え（planType・
/// subscriptionStatus）は、入金を確かめてから運営者がサーバ側で行う。
class ShopPlanScreen extends StatefulWidget {
  final String shopId;
  final ShopPlanType currentPlan;

  /// 請求書の宛名の初期値（店名）。
  final String? shopName;

  const ShopPlanScreen({
    super.key,
    required this.shopId,
    required this.currentPlan,
    this.shopName,
  });

  @override
  State<ShopPlanScreen> createState() => _ShopPlanScreenState();
}

class _ShopPlanScreenState extends State<ShopPlanScreen> {
  @override
  void initState() {
    super.initState();
    if (!_useInAppPurchase) {
      // 受付中の申し込みがあれば、画面の上に出す
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ShopPlanRequestProvider>().loadPending(widget.shopId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useIap = _useInAppPurchase;
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

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
            // 「30日間の無料トライアル」は 2026-09-30 に外した。特商法・利用規約
            // （請求書払い）に試用期間の定めがなく、約束できないため。
            if (!useIap) ...[
              AppSpacing.verticalXs,
              Text(
                'お支払いは請求書払い（銀行振込）です',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalMd,
              _PendingRequestBanner(shopId: widget.shopId),
            ],
            AppSpacing.verticalXxl,
            for (final plan in ShopPlanType.values) ...[
              if (plan != ShopPlanType.free) AppSpacing.verticalMd,
              _PlanCard(
                planType: plan,
                currentPlan: widget.currentPlan,
                shopId: widget.shopId,
                shopName: widget.shopName,
                isRecommended: plan == ShopPlanType.standard &&
                    widget.currentPlan == ShopPlanType.free,
              ),
            ],
            AppSpacing.verticalXxl,
            if (useIap) ...[
              Text(
                '※ 課金はApp Store / Google Playを通じて処理されます。\n'
                'サブスクリプションはいつでもキャンセルできます。',
                style: mutedStyle,
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalSm,
              // App Store ガイドライン 3.1.1: サブスクは購入復元の導線が必須
              const _RestorePurchasesButton(),
            ] else
              Text(
                '※ 店舗プランのお支払いは、毎月お送りする請求書による銀行振込です'
                '（振込手数料はご負担ください）。\n'
                'プランは、担当が申し込みを確かめ、入金を確認してから切り替わります。\n'
                '解約・プランの変更も、この画面から申し込めます。',
                style: mutedStyle,
                textAlign: TextAlign.center,
              ),
            AppSpacing.verticalLg,
          ],
        ),
      ),
    );
  }
}

/// 受付中の申し込みの表示。
class _PendingRequestBanner extends StatelessWidget {
  final String shopId;

  const _PendingRequestBanner({required this.shopId});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<ShopPlanRequestProvider>().pending;
    if (pending == null || pending.shopId != shopId) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      key: const Key('plan_request_pending'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined, color: AppColors.info),
          AppSpacing.horizontalSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending.isQuote
                      ? '${pending.plan.displayName}の見積もりのご相談を受け付けています'
                      : '${pending.plan.displayName}の申し込みを受け付けています',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.verticalXxs,
                Text(
                  _acceptedMessage(pending),
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

/// 受け付けたあとの案内文。
String _acceptedMessage(ShopPlanRequest req) {
  if (req.isQuote) {
    return '担当から個別にお見積もりをお送りします。';
  }
  if (req.plan.index < req.currentPlan.index) {
    return '担当が確認し、プランの変更についてご連絡します。';
  }
  return '担当から請求書をお送りします。プランは入金の確認後に切り替わります。';
}

/// 「購入を復元」ボタン。
///
/// 機種変更・再インストール時に既存サブスクリプションを復元する。
/// App Store ガイドライン 3.1.1 で非消耗型/サブスクには必須。
class _RestorePurchasesButton extends StatefulWidget {
  const _RestorePurchasesButton();

  @override
  State<_RestorePurchasesButton> createState() =>
      _RestorePurchasesButtonState();
}

class _RestorePurchasesButtonState extends State<_RestorePurchasesButton> {
  bool _isLoading = false;

  Future<void> _restore() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid ?? '';
    final rcService = ServiceLocator.instance.get<RevenueCatService>();
    final result = await rcService.restorePurchases(userId: userId);

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.when(
      success: (restore) {
        showSuccessSnackBar(
          context,
          restore.activeEntitlements.isNotEmpty
              ? '購入情報を復元しました'
              : '復元できる購入はありませんでした',
        );
      },
      failure: (error) {
        final msg = error.userMessage;
        showSuccessSnackBar(
          context,
          msg.isNotEmpty ? msg : '購入の復元に失敗しました',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isLoading ? null : _restore,
      child: _isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('購入を復元'),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ShopPlanType planType;
  final ShopPlanType currentPlan;
  final String shopId;
  final String? shopName;
  final bool isRecommended;

  const _PlanCard({
    required this.planType,
    required this.currentPlan,
    required this.shopId,
    this.shopName,
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
                            '¥${_formatYen(planType.monthlyPrice!)}',
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
                        planType.isCustomQuote ? '個別見積もり' : '無料',
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
                    shopName: shopName,
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
  final String? shopName;

  const _PlanButton({
    required this.planType,
    required this.currentPlan,
    required this.isCurrent,
    required this.isDowngrade,
    required this.shopId,
    this.shopName,
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

    if (!_useInAppPurchase) {
      await _openInvoiceRequest();
      return;
    }

    if (widget.planType == ShopPlanType.free &&
        widget.currentPlan != ShopPlanType.free) {
      await _confirmDowngrade();
      return;
    }

    await _startPurchase();
  }

  // ---------------------------------------------------------------------------
  // 請求書払いの申し込み（既定）
  // ---------------------------------------------------------------------------

  Future<void> _openInvoiceRequest() async {
    final accepted = await showModalBottomSheet<ShopPlanRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanRequestSheet(
        shopId: widget.shopId,
        plan: widget.planType,
        currentPlan: widget.currentPlan,
        shopName: widget.shopName,
      ),
    );
    if (accepted == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accepted.isQuote ? 'ご相談を受け付けました' : '申し込みを受け付けました'),
        content: Text(
          '${_acceptedMessage(accepted)}\n'
          'ご連絡は ${accepted.contactEmail} にお送りします。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // アプリ内課金（FeatureFlag.shopInAppPurchase を開けたときだけ）
  // ---------------------------------------------------------------------------

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
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid ?? '';

    final rcService = ServiceLocator.instance.get<RevenueCatService>();
    final result =
        await rcService.purchasePlan(widget.planType, userId: userId);

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.when(
      success: (_) async {
        // Cloud Functions webhook will update subscriptionStatus automatically.
        // We optimistically update planType and show success to the user.
        await _applyPlanChange(
          widget.planType,
          ShopSubscriptionStatus.active,
        );
      },
      failure: (error) {
        final msg = error.userMessage;
        if (msg.isNotEmpty) {
          showSuccessSnackBar(context, msg);
        }
      },
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

  String get _upgradeLabel {
    if (_useInAppPurchase) return 'アップグレード';
    return widget.planType.isCustomQuote ? '見積もりを相談する' : '請求書払いで申し込む';
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
      child: Text(_upgradeLabel),
    );
  }
}

/// 請求書払いの申し込みフォーム（ボトムシート）。
///
/// 受け付けたら、その申し込みを返して閉じる。
class _PlanRequestSheet extends StatefulWidget {
  final String shopId;
  final ShopPlanType plan;
  final ShopPlanType currentPlan;
  final String? shopName;

  const _PlanRequestSheet({
    required this.shopId,
    required this.plan,
    required this.currentPlan,
    this.shopName,
  });

  @override
  State<_PlanRequestSheet> createState() => _PlanRequestSheetState();
}

class _PlanRequestSheetState extends State<_PlanRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _billingNameController;
  late final TextEditingController _emailController;
  final _noteController = TextEditingController();

  bool get _isQuote => widget.plan.isCustomQuote;
  bool get _isDowngrade => widget.plan.index < widget.currentPlan.index;

  @override
  void initState() {
    super.initState();
    _billingNameController = TextEditingController(text: widget.shopName ?? '');
    _emailController = TextEditingController(
      text: context.read<AuthProvider>().firebaseUser?.email ?? '',
    );
  }

  @override
  void dispose() {
    _billingNameController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _title {
    final name = widget.plan.displayName;
    if (_isQuote) return '$nameの見積もりを相談する';
    if (_isDowngrade) return '$nameへの変更を申し込む';
    return '$nameを請求書払いで申し込む';
  }

  String get _summary {
    final price = widget.plan.monthlyPrice;
    final lines = <String>[
      if (_isQuote)
        '料金は、店舗数やご利用の内容に合わせて個別にお見積もりします。'
      else if (price != null)
        '月額 ¥${_formatYen(price)}（税込）・請求書払い（銀行振込）'
      else
        'フリープランは無料です。',
      // 利用規約 第11条6: 解約後も満了日までは有料プランの機能を使える
      if (_isDowngrade) '契約期間の満了日まで、いまのプランの機能をお使いいただけます。',
    ];
    return lines.join('\n');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    if (uid.isEmpty) {
      showErrorSnackBar(context, 'ログインしてください');
      return;
    }

    final provider = context.read<ShopPlanRequestProvider>();
    final ok = await provider.submit(
      shopId: widget.shopId,
      requesterUid: uid,
      plan: widget.plan,
      currentPlan: widget.currentPlan,
      contactEmail: _emailController.text,
      billingName: _billingNameController.text,
      note: _noteController.text,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(provider.pending);
    } else {
      showErrorSnackBar(
        context,
        provider.error is PermissionError
            ? 'プランを申し込めるのは店主だけです'
            : '申し込みを送れませんでした。時間をおいてもう一度お試しください',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitting = context.watch<ShopPlanRequestProvider>().isSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.verticalSm,
              Text(_summary, style: theme.textTheme.bodyMedium),
              AppSpacing.verticalLg,
              TextFormField(
                key: const Key('plan_request_billing_name'),
                controller: _billingNameController,
                decoration: const InputDecoration(
                  labelText: '請求書の宛名',
                  hintText: '例: 株式会社タカヤモーター',
                ),
                maxLength: ShopPlanRequestService.maxBillingNameLength,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '請求書の宛名を入力してください' : null,
              ),
              AppSpacing.verticalSm,
              TextFormField(
                key: const Key('plan_request_email'),
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '連絡先メールアドレス',
                  helperText: '請求書・お見積もりはこのアドレスにお送りします',
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) => ShopPlanRequestService.isValidEmail(v ?? '')
                    ? null
                    : 'メールアドレスを確認してください',
              ),
              AppSpacing.verticalSm,
              TextFormField(
                key: const Key('plan_request_note'),
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'ご要望（任意）',
                  hintText: _isQuote ? '店舗数・ご希望の開始時期など' : 'ご希望の開始時期など',
                ),
                maxLines: 3,
                maxLength: ShopPlanRequestService.maxNoteLength,
              ),
              AppSpacing.verticalMd,
              FilledButton(
                key: const Key('plan_request_submit'),
                onPressed: isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(AppSpacing.tapTargetRecommended),
                ),
                child: Text(
                  isSubmitting ? '送信中...' : (_isQuote ? '相談を送る' : '申し込む'),
                ),
              ),
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatYen(int price) {
  return price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
