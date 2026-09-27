import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/maintenance_record.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_profile.dart';
import '../../services/vehicle_profile_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';

String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';

/// 愛車ページ（公開）。「クルマをアバターに」。
///
/// 人ではなく車を主役にし、その車の投稿・パーツ・公開ドライブ・（本人が
/// 選べば）整備の回数を1か所に集める。
class VehicleProfileScreen extends StatefulWidget {
  final VehicleProfileService service;
  final VehicleProfile profile;

  /// 本人が見ているとき、編集への入口を出すために渡す。
  final VoidCallback? onEdit;

  const VehicleProfileScreen({
    super.key,
    required this.service,
    required this.profile,
    this.onEdit,
  });

  @override
  State<VehicleProfileScreen> createState() => _VehicleProfileScreenState();
}

class _VehicleProfileScreenState extends State<VehicleProfileScreen> {
  VehicleProfileContents? _contents;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await widget.service.contents(widget.profile);
    if (!mounted) return;
    setState(() => _contents = c);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final theme = Theme.of(context);
    final c = _contents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('愛車ページ'),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              key: const Key('vehicle_profile_edit'),
              tooltip: '編集',
              icon: const Icon(Icons.edit_outlined),
              onPressed: widget.onEdit,
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    p.imageUrl == null ? null : NetworkImage(p.imageUrl!),
                child: p.imageUrl == null
                    ? const Icon(Icons.directions_car,
                        size: 32, color: AppColors.primary)
                    : null,
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: theme.textTheme.titleLarge),
                    Text(p.specLine, style: theme.textTheme.bodyMedium),
                    Text('オーナー: ${p.ownerName}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (!p.isPublic) ...[
            AppSpacing.verticalSm,
            const Text(
              'このページは非公開です（あなたにだけ見えています）。',
              key: Key('vehicle_profile_private_note'),
              style: TextStyle(color: AppColors.warning),
            ),
          ],
          if (p.bio != null) ...[
            AppSpacing.verticalMd,
            Text(p.bio!),
          ],
          if (p.showsMaintenance && p.maintenance.isNotEmpty) ...[
            AppSpacing.verticalLg,
            Text('整備の記録', style: theme.textTheme.titleMedium),
            AppSpacing.verticalXs,
            AppCard(
              child: Column(
                children: [
                  for (final m in p.maintenance.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text(m.type)),
                          Text('${m.count}回'),
                          AppSpacing.horizontalMd,
                          SizedBox(
                            width: 96,
                            child: Text(
                              '最後 ${_date(m.lastDate)}',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          AppSpacing.verticalLg,
          if (c == null)
            const AppLoadingCenter()
          else if (c.isEmpty)
            AppEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'まだこの車の投稿がありません',
              description: '投稿するときに「どの車の話か」を選ぶと、ここに集まります。'
                  'パーツのレビューや、公開にしたドライブも並びます。',
              buttonLabel: '戻る',
              onButtonPressed: () => Navigator.pop(context),
            )
          else ...[
            if (c.showcases.isNotEmpty) ...[
              Text('パーツ・装備（${c.showcases.length}）',
                  style: theme.textTheme.titleMedium),
              for (final s in c.showcases)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(
                      [if (s.brand != null) s.brand!, s.itemName].join(' ')),
                  subtitle: Text(s.category.displayName),
                  trailing: Text('★' * s.rating.clamp(0, 5)),
                ),
              AppSpacing.verticalMd,
            ],
            if (c.posts.isNotEmpty) ...[
              Text('投稿（${c.posts.length}）', style: theme.textTheme.titleMedium),
              for (final post in c.posts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_date(post.createdAt)),
                ),
              AppSpacing.verticalMd,
            ],
            if (c.driveLogs.isNotEmpty) ...[
              Text('ドライブ（${c.driveLogs.length}）',
                  style: theme.textTheme.titleMedium),
              for (final d in c.driveLogs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_outlined),
                  title: Text(d.title ?? 'ドライブ'),
                  subtitle: Text(
                    '${_date(d.startTime)}・'
                    '${d.statistics.totalDistance.toStringAsFixed(1)}km',
                  ),
                ),
            ],
          ],
          AppSpacing.verticalXl,
        ],
      ),
    );
  }
}

/// 本人が愛車ページを公開・編集する。保存したら、そのページを返して閉じる。
class VehicleProfileEditScreen extends StatefulWidget {
  final VehicleProfileService service;
  final Vehicle vehicle;
  final String ownerId;
  final String ownerName;
  final List<MaintenanceRecord> records;
  final VehicleProfile? existing;

  const VehicleProfileEditScreen({
    super.key,
    required this.service,
    required this.vehicle,
    required this.ownerId,
    required this.ownerName,
    required this.records,
    this.existing,
  });

  @override
  State<VehicleProfileEditScreen> createState() =>
      _VehicleProfileEditScreenState();
}

class _VehicleProfileEditScreenState extends State<VehicleProfileEditScreen> {
  late bool _public = widget.existing?.isPublic ?? true;
  late bool _maintenance = widget.existing?.showsMaintenance ?? false;
  late final _nickname = TextEditingController(text: widget.existing?.nickname);
  late final _bio = TextEditingController(text: widget.existing?.bio);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await widget.service.save(
      ownerId: widget.ownerId,
      ownerName: widget.ownerName,
      vehicle: widget.vehicle,
      isPublic: _public,
      showsMaintenance: _maintenance,
      records: widget.records,
      nickname: _nickname.text,
      bio: _bio.text,
    );
    if (!mounted) return;
    r.when(
      success: (p) => Navigator.pop(context, p),
      failure: (e) => setState(() {
        _error = e.userMessage;
        _saving = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tallies = MaintenanceTally.fromRecords(
      widget.records.where((r) => r.vehicleId == widget.vehicle.id).toList(),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('愛車ページを作る')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          const Text(
            'この車を主役にしたページです。投稿するときに選んだ車の話・'
            'パーツのレビュー・公開にしたドライブが集まります。'
            '走行距離・ナンバー・車検満了日・金額は載りません。',
          ),
          SwitchListTile(
            key: const Key('vehicle_profile_public'),
            contentPadding: EdgeInsets.zero,
            title: const Text('ほかの人にも見せる'),
            subtitle: const Text('オフにすると、あなたにだけ見えます'),
            value: _public,
            onChanged: (v) => setState(() => _public = v),
          ),
          TextField(
            key: const Key('vehicle_profile_nickname'),
            controller: _nickname,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: '呼び名（任意）',
              hintText: '例: 白いミニ（空なら「${widget.vehicle.displayName}」）',
              border: const OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalSm,
          TextField(
            controller: _bio,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ひとこと（任意）',
              hintText: '例: 休日は海沿いを走ります',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            key: const Key('vehicle_profile_maintenance'),
            contentPadding: EdgeInsets.zero,
            title: const Text('整備の記録も見せる'),
            subtitle: const Text('種類と回数、最後にやった日だけ。金額は出しません。'
                '修理の履歴は、売るときに不利になることもあります。'),
            value: _maintenance,
            onChanged: tallies.isEmpty
                ? null
                : (v) => setState(() => _maintenance = v),
          ),
          if (_maintenance)
            for (final t in tallies.take(8))
              Text('・${t.type} ${t.count}回（最後 ${_date(t.lastDate)}）'),
          if (_error != null) ...[
            AppSpacing.verticalSm,
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          AppSpacing.verticalLg,
          FilledButton(
            key: const Key('vehicle_profile_save'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
            ),
            child: Text(_saving ? '保存しています…' : '保存する'),
          ),
        ],
      ),
    );
  }
}
