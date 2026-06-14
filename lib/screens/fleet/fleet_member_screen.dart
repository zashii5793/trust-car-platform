import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/fleet_member.dart';
import '../../services/fleet_member_service.dart';

/// Screen for managing fleet members (roles, invitations, removals).
///
/// [FleetRole.owner] and [FleetRole.admin] users see edit controls.
/// Admins cannot manage the owner (add/remove/update-role).
class FleetMemberScreen extends StatefulWidget {
  final String companyId;
  final String currentUserId;

  const FleetMemberScreen({
    super.key,
    required this.companyId,
    required this.currentUserId,
  });

  @override
  State<FleetMemberScreen> createState() => _FleetMemberScreenState();
}

class _FleetMemberScreenState extends State<FleetMemberScreen> {
  late final FleetMemberService _service;
  List<FleetMember> _members = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOwner = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _service = sl.get<FleetMemberService>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _service.getMembers(widget.companyId);
    if (!mounted) return;

    result.when(
      success: (members) {
        final role = members
            .where((m) => m.userId == widget.currentUserId)
            .map((m) => m.role)
            .firstOrNull;
        setState(() {
          _members = members;
          _isOwner = role == FleetRole.owner;
          _isAdmin = role == FleetRole.admin;
          _isLoading = false;
        });
      },
      failure: (e) => setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _addMember() async {
    final result = await showDialog<_MemberInput?>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (result == null) return;

    final addResult = await _service.addMember(
      companyId: widget.companyId,
      userId: result.userId,
      role: result.role,
      requesterId: widget.currentUserId,
    );
    if (!mounted) return;

    addResult.when(
      success: (_) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンバーを追加しました')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  Future<void> _updateRole(FleetMember member, FleetRole newRole) async {
    final result = await _service.updateRole(
      companyId: widget.companyId,
      userId: member.userId,
      newRole: newRole,
      requesterId: widget.currentUserId,
    );
    if (!mounted) return;

    result.when(
      success: (_) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ロールを更新しました')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  Future<void> _removeMember(FleetMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メンバーを削除'),
        content: Text(
          '${member.displayName ?? member.userId} をフリートから削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.removeMember(
      companyId: widget.companyId,
      userId: member.userId,
      requesterId: widget.currentUserId,
    );
    if (!mounted) return;

    result.when(
      success: (_) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンバーを削除しました')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: (_isOwner || _isAdmin)
          ? FloatingActionButton.extended(
              key: const Key('add_member_fab'),
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('メンバーを追加'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!,
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _load, child: const Text('再読み込み')),
          ],
        ),
      );
    }
    if (_members.isEmpty) {
      return const Center(
        key: Key('fleet_members_empty'),
        child:
            Text('メンバーがいません', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final member = _members[index];
          final isSelf = member.userId == widget.currentUserId;
          // Admin cannot manage the owner
          final targetIsOwner = member.role == FleetRole.owner;
          final canManageTarget =
              (_isOwner || _isAdmin) && !isSelf && !(_isAdmin && targetIsOwner);
          return _MemberCard(
            member: member,
            isSelf: isSelf,
            isOwner: _isOwner,
            onRoleChanged: canManageTarget
                ? (role) => _updateRole(member, role)
                : null,
            onRemove: canManageTarget ? () => _removeMember(member) : null,
          );
        },
      ),
    );
  }
}

// ── Member card ───────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final FleetMember member;
  final bool isSelf;
  final bool isOwner;
  final void Function(FleetRole)? onRoleChanged;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.member,
    required this.isSelf,
    required this.isOwner,
    this.onRoleChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('member_card_${member.userId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                (member.displayName ?? member.userId).isNotEmpty
                    ? (member.displayName ?? member.userId)[0].toUpperCase()
                    : '?',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.displayName ?? member.userId,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Text(
                          '（あなた）',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (member.displayName != null)
                    Text(
                      member.userId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Role selector or badge
            if (onRoleChanged != null)
              _RoleDropdown(
                currentRole: member.role,
                onChanged: onRoleChanged!,
              )
            else
              _RoleBadge(role: member.role),
            if (onRemove != null)
              IconButton(
                key: Key('remove_member_${member.userId}'),
                icon: const Icon(Icons.person_remove_outlined, size: 20),
                color: AppColors.error,
                tooltip: '削除',
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final FleetRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      FleetRole.owner => ('オーナー', AppColors.primary),
      FleetRole.admin => ('総務担当', AppColors.info),
      FleetRole.manager => ('管理者', AppColors.secondary),
      FleetRole.staff => ('スタッフ', AppColors.warning),
      FleetRole.viewer => ('閲覧', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final FleetRole currentRole;
  final void Function(FleetRole) onChanged;

  const _RoleDropdown({required this.currentRole, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<FleetRole>(
      value: currentRole,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: FleetRole.values
          .where((r) => r != FleetRole.owner)
          .map((r) => DropdownMenuItem(
                value: r,
                child:
                    Text(_roleLabel(r), style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (r) {
        if (r != null && r != currentRole) onChanged(r);
      },
    );
  }

  String _roleLabel(FleetRole r) => switch (r) {
        FleetRole.owner => 'オーナー',
        FleetRole.admin => '総務担当',
        FleetRole.manager => '管理者',
        FleetRole.staff => 'スタッフ',
        FleetRole.viewer => '閲覧',
      };
}

// ── Add member dialog ─────────────────────────────────────────────────────────

class _MemberInput {
  final String userId;
  final FleetRole role;
  _MemberInput({required this.userId, required this.role});
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _controller = TextEditingController();
  FleetRole _role = FleetRole.staff;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('メンバーを追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('add_member_user_id_field'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'ユーザーID',
              hintText: 'Firebase Auth UID',
            ),
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'ロール'),
            child: DropdownButton<FleetRole>(
              key: const Key('add_member_role_dropdown'),
              value: _role,
              isDense: true,
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: [FleetRole.manager, FleetRole.staff, FleetRole.viewer]
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_roleLabel(r)),
                      ))
                  .toList(),
              onChanged: (r) {
                if (r != null) setState(() => _role = r);
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('add_member_confirm_button'),
          onPressed: () {
            final uid = _controller.text.trim();
            if (uid.isEmpty) return;
            Navigator.pop(context, _MemberInput(userId: uid, role: _role));
          },
          child: const Text('追加'),
        ),
      ],
    );
  }

  String _roleLabel(FleetRole r) => switch (r) {
        FleetRole.owner => 'オーナー',
        FleetRole.admin => '総務担当',
        FleetRole.manager => '管理者',
        FleetRole.staff => 'スタッフ',
        FleetRole.viewer => '閲覧',
      };
}
