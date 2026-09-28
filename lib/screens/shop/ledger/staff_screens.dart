import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../services/shop_staff_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'ledger_format.dart';

/// 店主がスタッフを増やす・外す。
class StaffManageScreen extends StatefulWidget {
  final ShopStaffService service;
  final String shopId;
  final String shopName;
  final String ownerUid;

  const StaffManageScreen({
    super.key,
    required this.service,
    required this.shopId,
    required this.shopName,
    required this.ownerUid,
  });

  @override
  State<StaffManageScreen> createState() => _StaffManageScreenState();
}

class _StaffManageScreenState extends State<StaffManageScreen> {
  List<ShopStaffMember>? _members;
  StaffInvite? _invite;
  bool _issuing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.service.members(widget.shopId);
    if (!mounted) return;
    setState(() {
      _members = r.valueOrNull ?? const [];
      _error = r.errorOrNull?.userMessage;
    });
  }

  Future<void> _issue() async {
    setState(() {
      _issuing = true;
      _error = null;
    });
    final r = await widget.service.issue(
      shopId: widget.shopId,
      shopName: widget.shopName,
      issuedBy: widget.ownerUid,
    );
    if (!mounted) return;
    setState(() {
      _invite = r.valueOrNull;
      _error = r.errorOrNull?.userMessage;
      _issuing = false;
    });
  }

  Future<void> _remove(ShopStaffMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${m.displayName} さんを外しますか？'),
        content: const Text('外すと、この店の顧客台帳を開けなくなります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる'),
          ),
          TextButton(
            key: const Key('staff_remove_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('外す'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.service.remove(shopId: widget.shopId, uid: m.uid);
    if (!mounted) return;
    if (r.isFailure) {
      setState(() => _error = r.errorOrNull!.userMessage);
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = _members;
    final invite = _invite;
    return Scaffold(
      appBar: AppBar(title: const Text('スタッフ')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('スタッフを増やす', style: theme.textTheme.titleMedium),
                AppSpacing.verticalXs,
                const Text('コードを発行して、スタッフに伝えてください。スタッフは'
                    '自分のアプリの「掲載管理」でコードを入れると、この店の'
                    '顧客台帳を開けるようになります。コードは1回限り・7日間有効です。'),
                AppSpacing.verticalSm,
                if (invite != null) ...[
                  Center(
                    child: SelectableText(
                      invite.code,
                      key: const Key('staff_invite_code'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  Center(
                    child: Text('${ledgerDate(invite.expiresAt)} まで有効',
                        style: theme.textTheme.bodySmall),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: invite.code)),
                      icon: const Icon(Icons.copy),
                      label: const Text('コピー'),
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  key: const Key('staff_issue'),
                  onPressed: _issuing ? null : _issue,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(invite == null ? 'コードを発行する' : '別のコードを発行する'),
                ),
              ],
            ),
          ),
          AppSpacing.verticalLg,
          Text('いまのスタッフ', style: theme.textTheme.titleMedium),
          if (members == null)
            const AppLoadingCenter()
          else if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('まだスタッフはいません（店主のアカウントだけで使っています）。'),
            )
          else
            for (final m in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(m.displayName),
                subtitle: Text([
                  m.isOwner ? '店主' : 'スタッフ',
                  if (m.addedAt != null) '${ledgerDate(m.addedAt!)} から',
                ].join('・')),
                trailing: m.isOwner || m.uid == widget.ownerUid
                    ? null
                    : TextButton(
                        key: Key('staff_remove_${m.uid}'),
                        onPressed: () => _remove(m),
                        child: const Text('外す'),
                      ),
              ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ),
    );
  }
}

/// スタッフがコードを入れて店に入る。入れたら、その店の情報を返して閉じる。
class StaffJoinScreen extends StatefulWidget {
  final ShopStaffService service;
  final String uid;
  final String displayName;

  const StaffJoinScreen({
    super.key,
    required this.service,
    required this.uid,
    required this.displayName,
  });

  @override
  State<StaffJoinScreen> createState() => _StaffJoinScreenState();
}

class _StaffJoinScreenState extends State<StaffJoinScreen> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    final r = await widget.service.redeem(
      code: _code.text,
      uid: widget.uid,
      displayName: widget.displayName,
    );
    if (!mounted) return;
    r.when(
      success: (link) => Navigator.pop(context, link),
      failure: (e) => setState(() {
        _error = e.userMessage;
        _joining = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('スタッフとして参加する')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          const Text('店主から受け取った6文字のコードを入れてください。'),
          AppSpacing.verticalMd,
          TextField(
            key: const Key('staff_join_code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'コード',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              key: const Key('staff_join_error'),
              style: const TextStyle(color: AppColors.error),
            ),
          AppSpacing.verticalMd,
          FilledButton(
            key: const Key('staff_join_submit'),
            onPressed: _joining ? null : _join,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
            ),
            child: Text(_joining ? '確認しています…' : '参加する'),
          ),
        ],
      ),
    );
  }
}
