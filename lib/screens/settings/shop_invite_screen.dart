import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/shop_invite.dart';
import '../../services/shop_invite_service.dart';

/// Where a customer types the code their shop handed them.
///
/// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §4。
///
/// **既存客の大半は、自分でアプリを探して自分で店を見つけたりしない。**
/// 車検の入庫時に紙やQRでコードを渡し、ここに入れてもらう。
class ShopInviteScreen extends StatefulWidget {
  final ShopInviteService service;
  final String userId;

  const ShopInviteScreen({
    super.key,
    required this.service,
    required this.userId,
  });

  @override
  State<ShopInviteScreen> createState() => _ShopInviteScreenState();
}

class _ShopInviteScreenState extends State<ShopInviteScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  ShopCustomerLink? _linked;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final result = await widget.service.linkedShopFor(widget.userId);
    if (!mounted) return;
    setState(() => _linked = result.valueOrNull);
  }

  Future<void> _submit() async {
    final input = _controller.text;
    final normalized = InviteCode.normalize(input);

    if (normalized.isEmpty) {
      setState(() => _error = 'コードを入力してください');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.service.redeem(
      code: normalized,
      userId: widget.userId,
    );

    if (!mounted) return;

    result.when(
      success: (link) {
        setState(() {
          _busy = false;
          _linked = link;
          _controller.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${link.shopName} をかかりつけに登録しました')),
        );
      },
      failure: (error) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linked = _linked;

    return Scaffold(
      appBar: AppBar(title: const Text('お店のコードを入れる')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (linked != null) ...[
              Card(
                key: const Key('linked_shop_card'),
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.store, color: AppColors.primary),
                  title: const Text('いまのかかりつけ'),
                  subtitle: Text(linked.shopName),
                ),
              ),
              AppSpacing.verticalLg,
            ],
            Text(
              'お店から渡されたコードを入れてください',
              style: theme.textTheme.titleMedium,
            ),
            AppSpacing.verticalXs,
            Text(
              '車検や点検のご案内が届くようになります。'
              '整備の記録をお店から受け取ることもできます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            AppSpacing.verticalMd,
            TextField(
              key: const Key('invite_code_field'),
              controller: _controller,
              autocorrect: false,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '例: ABC234',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            AppSpacing.verticalXs,
            Text(
              // 実際に紙で渡されるので、書き方のゆれを先に許すと伝えておく。
              '小文字・全角・ハイフン入りでも大丈夫です',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.verticalLg,
            FilledButton(
              key: const Key('invite_submit_button'),
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('かかりつけに登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
