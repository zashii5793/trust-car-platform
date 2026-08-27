import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/shop_invite.dart';
import '../../services/shop_invite_service.dart';

/// Where the shop gets the code it hands to customers.
///
/// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §4。
///
/// **店がコードを配れないと、この仕組みは動かない。** 顧客側の入力画面だけ
/// あっても、渡すものが無ければ誰も使えない。
///
/// 車検の入庫時にカウンターで見せる／紙に書き写す使い方を想定している。
/// 画面に大きく出して、口頭でも伝えられる形にしてある。
class ShopInviteManageScreen extends StatefulWidget {
  final ShopInviteService service;
  final String shopId;
  final String shopName;
  final String shopOwnerId;

  const ShopInviteManageScreen({
    super.key,
    required this.service,
    required this.shopId,
    required this.shopName,
    required this.shopOwnerId,
  });

  @override
  State<ShopInviteManageScreen> createState() => _ShopInviteManageScreenState();
}

class _ShopInviteManageScreenState extends State<ShopInviteManageScreen> {
  ShopInvite? _invite;
  List<ShopCustomerLink> _customers = const [];
  bool _loading = true;
  bool _issuing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customers = await widget.service.customersOf(widget.shopId);
    if (!mounted) return;
    setState(() {
      _customers = customers.valueOrNull ?? const [];
      _loading = false;
    });
  }

  Future<void> _issue() async {
    setState(() {
      _issuing = true;
      _error = null;
    });

    final result = await widget.service.createInvite(
      shopId: widget.shopId,
      shopName: widget.shopName,
      shopOwnerId: widget.shopOwnerId,
    );

    if (!mounted) return;

    result.when(
      success: (invite) => setState(() {
        _invite = invite;
        _issuing = false;
      }),
      failure: (error) => setState(() {
        _error = error.message;
        _issuing = false;
      }),
    );
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('コードをコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = _invite;

    return Scaffold(
      appBar: AppBar(title: const Text('お客様に配るコード')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '車検や点検の入庫時に、このコードをお客様にお伝えください。',
              style: theme.textTheme.bodyMedium,
            ),
            AppSpacing.verticalXxs,
            Text(
              'お客様がアプリに入れると、車検のご案内が届くようになります。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            AppSpacing.verticalLg,
            if (invite == null)
              FilledButton.icon(
                key: const Key('issue_invite_button'),
                onPressed: _issuing ? null : _issue,
                icon: _issuing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('コードを発行する'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                ),
              )
            else
              _CodeCard(code: invite.code, onCopy: () => _copy(invite.code)),
            if (_error != null) ...[
              AppSpacing.verticalSm,
              Text(
                _error!,
                key: const Key('issue_invite_error'),
                style:
                    theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ],
            AppSpacing.verticalXl,
            const Divider(),
            AppSpacing.verticalMd,
            Text('コードを使ったお客様', style: theme.textTheme.titleSmall),
            AppSpacing.verticalXs,
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_customers.isEmpty)
              Padding(
                key: const Key('no_customers'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'まだいません。入庫のときにコードをお渡しください。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              Text(
                '${_customers.length} 名',
                key: const Key('customer_count'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 発行したコードを、口頭でも伝えられる大きさで出す。
class _CodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _CodeCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('invite_code_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              'お客様にお伝えするコード',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.verticalSm,
            SelectableText(
              code,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.verticalSm,
            Text(
              // 口頭で伝える場面があるので、読み間違えない作りだと明記する。
              '0とO、1とIは使っていません',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.verticalMd,
            OutlinedButton.icon(
              key: const Key('copy_invite_button'),
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('コピーする'),
            ),
          ],
        ),
      ),
    );
  }
}
