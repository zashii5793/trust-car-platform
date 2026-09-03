import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/shop_invite.dart';
import '../../models/vehicle.dart';
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

  /// 車検の満了日をお店に伝えるために渡す。**この画面から店へ出て行くのは
  /// 満了日と台数だけ**で、車種も走行距離も整備履歴も渡らない
  /// （`docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2 案A）。
  final List<Vehicle> vehicles;

  const ShopInviteScreen({
    super.key,
    required this.service,
    required this.userId,
    this.vehicles = const [],
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

    // 開いたときに最新の満了日を送っておく。車検を受けて満了日が延びても、
    // 店の画面が古い日付のままだと案内の意味がない。
    if (result.valueOrNull != null) await _syncExpiries();
  }

  /// 車検満了日だけを店に渡す。共有を切っていればサービス側で何もしない。
  Future<void> _syncExpiries() async {
    await widget.service.shareInspectionExpiries(
      userId: widget.userId,
      expiryDates: _activeVehicles.map((v) => v.inspectionExpiryDate).toList(),
      vehicleCount: _activeVehicles.length,
    );
    final refreshed = await widget.service.linkedShopFor(widget.userId);
    if (!mounted) return;
    setState(() => _linked = refreshed.valueOrNull ?? _linked);
  }

  /// 手放した車は数えない。**店の「満了を迎える台数」が水増しになる。**
  List<Vehicle> get _activeVehicles =>
      widget.vehicles.where((v) => !v.status.isRetired).toList();

  Future<void> _toggleSharing(bool enabled) async {
    setState(() => _busy = true);

    final result = await widget.service.setExpirySharing(
      userId: widget.userId,
      enabled: enabled,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _linked = result.valueOrNull ?? _linked;
    });

    if (enabled) await _syncExpiries();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? '車検満了日をお店に伝えます' : 'お店への共有を止めました。伝えていた満了日も消しました',
        ),
      ),
    );
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
        _syncExpiries();
      },
      failure: (error) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      },
    );
  }

  /// いま何を渡しているかを、そのまま書く。
  String _sharedSummary(ShopCustomerLink linked) {
    final shared = linked.inspectionExpiries.length;
    final total = linked.vehicleCount;

    if (total == 0) return '伝えている満了日はまだありません。';

    final missing = total - shared;
    final at = linked.expiryUpdatedAt;
    final when = at == null ? '' : '（${at.year}年${at.month}月${at.day}日に更新）';

    if (missing > 0) {
      return '$total 台のうち $shared 台の満了日を伝えています。'
          '残り $missing 台は満了日が未入力です。$when';
    }
    return '$total 台の満了日を伝えています。$when';
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
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.store, color: AppColors.primary),
                      title: const Text('いまのかかりつけ'),
                      subtitle: Text(linked.shopName),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      key: const Key('share_expiry_switch'),
                      value: linked.sharesInspectionExpiry,
                      onChanged: _busy ? null : _toggleSharing,
                      secondary: const Icon(Icons.event_available),
                      title: const Text('車検の満了日を伝える'),
                      subtitle: Text(
                        // 何が出て行って、何が出て行かないかを両方書く。
                        // 片方だけだと、どこまで見られているか分からない。
                        '伝わるのは満了日と台数だけです。'
                        '車種・走行距離・整備の記録は伝わりません。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (linked.sharesInspectionExpiry)
                      Padding(
                        key: const Key('shared_expiry_summary'),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _sharedSummary(linked),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                  ],
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
              '整備の記録をお店から受け取ることもできます。\n'
              'お店に伝わるのは車検の満了日と台数だけです。あとから止められます。',
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
