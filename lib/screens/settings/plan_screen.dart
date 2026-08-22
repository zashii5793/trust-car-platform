import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/user_plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_subscription_provider.dart';

/// プラン画面
///
/// フリー / プレミアムの違いを一覧で示し、その場でアップグレードできる。
/// 以前は「データをエクスポート」を押したときのダイアログが唯一の導線で、
/// 何がフリーで何が有料かを確認する場所がどこにも無かった。
///
/// 比較表は UserPlanLimits.forPlan() から組み立てるので、
/// プラン定義を変えたときに表示だけ古いまま残ることがない。
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = context.watch<UserSubscriptionProvider>();
    final isPremium = subscription.isPremium;

    final free = UserPlanLimits.forPlan(UserPlanType.free);
    final premium = UserPlanLimits.forPlan(UserPlanType.premium);
    final rows = _buildRows(free, premium);

    return Scaffold(
      appBar: AppBar(title: const Text('プラン')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _CurrentPlanCard(
            isPremium: isPremium,
            expiresAt: subscription.planExpiresAt,
          ),
          const SizedBox(height: 24),
          Text(
            'できることの比較',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _ComparisonTable(rows: rows, isPremium: isPremium),
          const SizedBox(height: 24),
          if (!isPremium) ...[
            _UpgradeButton(),
            const SizedBox(height: 12),
            Text(
              'お支払いは App Store / Google Play を通じて行われます。'
              '解約はそれぞれのサブスクリプション設定から行えます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ] else
            Text(
              '解約は App Store / Google Play のサブスクリプション設定から行えます。'
              '解約後も期間終了までプレミアム機能をご利用いただけます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 比較表の行。値は UserPlanLimits から取り出すので定義とずれない。
  static List<_PlanRow> _buildRows(
      UserPlanLimits free, UserPlanLimits premium) {
    String count(int v, String unit) =>
        v >= UserPlanLimits.unlimited ? '無制限' : '$v$unit';

    return [
      _PlanRow(
        label: '車両の登録',
        free: count(free.maxVehicles, '台まで'),
        premium: count(premium.maxVehicles, '台まで'),
      ),
      _PlanRow(
        label: '整備記録の登録',
        free: '無制限',
        premium: '無制限',
        sameForBoth: true,
      ),
      _PlanRow(
        label: '工場への問い合わせ',
        free: count(free.maxMonthlyInquiries, '件 / 月'),
        premium: count(premium.maxMonthlyInquiries, '件 / 月'),
      ),
      _PlanRow(
        label: 'ドライブログの保存',
        free: count(free.driveLogRetentionDays, '日間'),
        premium: count(premium.driveLogRetentionDays, '日間'),
      ),
      _PlanRow(
        label: '愛車カルテのPDF出力',
        free: free.canExportPdf ? '○' : '—',
        premium: premium.canExportPdf ? '○' : '—',
      ),
      _PlanRow(
        label: '整備履歴を工場に共有',
        free: count(free.maxHistorySharingGrants, '件'),
        premium: count(premium.maxHistorySharingGrants, '件'),
      ),
      _PlanRow(
        label: '同車種のコミュニティ傾向',
        free: free.canAccessCommunityTrends ? '○' : '—',
        premium: premium.canAccessCommunityTrends ? '○' : '—',
      ),
      _PlanRow(
        label: 'AIによる整備トレンド分析',
        free: free.canAccessMaintenanceTrends ? '○' : '—',
        premium: premium.canAccessMaintenanceTrends ? '○' : '—',
      ),
      _PlanRow(
        label: '質問への工場からの回答',
        free: free.canAllowShopFaqResponse ? '○' : '—',
        premium: premium.canAllowShopFaqResponse ? '○' : '—',
      ),
    ];
  }
}

class _PlanRow {
  final String label;
  final String free;
  final String premium;
  final bool sameForBoth;

  const _PlanRow({
    required this.label,
    required this.free,
    required this.premium,
    this.sameForBoth = false,
  });
}

class _CurrentPlanCard extends StatelessWidget {
  final bool isPremium;
  final DateTime? expiresAt;

  const _CurrentPlanCard({required this.isPremium, this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              isPremium ? Icons.workspace_premium : Icons.person_outline,
              size: 32,
              color: isPremium ? AppColors.warning : theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '現在のプラン',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    isPremium ? 'プレミアムプラン' : 'フリープラン',
                    key: const Key('plan_current_label'),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (isPremium && expiresAt != null)
                    Text(
                      '${expiresAt!.year}年${expiresAt!.month}月${expiresAt!.day}日まで',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<_PlanRow> rows;
  final bool isPremium;

  const _ComparisonTable({required this.rows, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = BorderSide(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ヘッダー行。現在のプラン側を強調する。
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Expanded(flex: 4, child: SizedBox()),
                Expanded(
                  flex: 3,
                  child: Text(
                    'フリー',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPremium ? null : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'プレミアム',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPremium ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: divider)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(row.label, style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.free,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: row.free == '—'
                              ? theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.premium,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: row.sameForBoth
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
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

class _UpgradeButton extends StatefulWidget {
  @override
  State<_UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends State<_UpgradeButton> {
  bool _busy = false;

  Future<void> _purchase() async {
    final subscription = context.read<UserSubscriptionProvider>();
    final uid = context.read<AuthProvider>().appUser?.id ?? '';
    if (uid.isEmpty) return;

    setState(() => _busy = true);
    final result = await subscription.purchasePremium(userId: uid);
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プレミアムプランへの登録が完了しました'),
          backgroundColor: AppColors.success,
        ),
      ),
      failure: (err) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.userMessage)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('plan_upgrade_button'),
      onPressed: _busy ? null : _purchase,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.workspace_premium),
      label: Text(_busy ? '処理中…' : 'プレミアムプランに登録する'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}
