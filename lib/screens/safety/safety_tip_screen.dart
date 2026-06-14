import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/safety_tip.dart';
import '../../services/safety_tip_service.dart';

/// 安全運転情報画面
///
/// JAF・警察庁・国土交通省等の公式機関の情報のみ表示する。
/// 免責条項（[SafetyTip.disclaimer]）を常時表示する法的要件あり。
class SafetyTipScreen extends StatefulWidget {
  const SafetyTipScreen({super.key});

  @override
  State<SafetyTipScreen> createState() => _SafetyTipScreenState();
}

class _SafetyTipScreenState extends State<SafetyTipScreen>
    with SingleTickerProviderStateMixin {
  late final SafetyTipService _service;
  late final TabController _tabController;

  static final _tabs = <SafetyTipCategory?>[
    null,
    ...SafetyTipCategory.values,
  ];

  @override
  void initState() {
    super.initState();
    _service = sl.get<SafetyTipService>();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('安全運転情報'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: '全て'),
            for (final c in SafetyTipCategory.values) Tab(text: c.displayName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final cat in _tabs)
                  _SafetyTipList(service: _service, category: cat),
              ],
            ),
          ),
          const _DisclaimerBanner(),
        ],
      ),
    );
  }
}

// ── タブごとのリスト ────────────────────────────────────────────────────────

class _SafetyTipList extends StatefulWidget {
  final SafetyTipService service;
  final SafetyTipCategory? category;

  const _SafetyTipList({required this.service, this.category});

  @override
  State<_SafetyTipList> createState() => _SafetyTipListState();
}

class _SafetyTipListState extends State<_SafetyTipList>
    with AutomaticKeepAliveClientMixin {
  List<SafetyTip>? _tips;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _tips = null;
        _error = null;
      });
    }
    final result = await widget.service.getTips(category: widget.category);
    if (!mounted) return;
    result.when(
      success: (tips) => setState(() => _tips = tips),
      failure: (e) => setState(() => _error = e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_tips == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _load, child: const Text('再読み込み')),
          ],
        ),
      );
    }
    if (_tips!.isEmpty) {
      return Center(
        key: const Key('safety_tips_empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.shield_outlined,
                size: 48, color: AppColors.textTertiary),
            SizedBox(height: AppSpacing.md),
            Text(
              'この分類の情報はまだありません',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _tips!.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _SafetyTipCard(tip: _tips![i]),
      ),
    );
  }
}

// ── 安全情報カード ──────────────────────────────────────────────────────────

class _SafetyTipCard extends StatelessWidget {
  final SafetyTip tip;
  const _SafetyTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('safety_tip_${tip.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SourceBadge(source: tip.source),
                const SizedBox(width: AppSpacing.xs),
                _CategoryBadge(category: tip.category),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tip.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tip.body,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              key: Key('official_link_${tip.id}'),
              onPressed: () => _openUrl(context, tip.sourceUrl),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('公式サイトへ'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.info,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクを開けませんでした')),
      );
    }
  }
}

class _SourceBadge extends StatelessWidget {
  final SafetyTipSource source;
  const _SourceBadge({required this.source});

  static const _palette = <SafetyTipSource, Color>{
    SafetyTipSource.jaf: Color(0xFFF57C00),
    SafetyTipSource.npa: Color(0xFF1565C0),
    SafetyTipSource.mlit: Color(0xFF2E7D32),
    SafetyTipSource.fdma: Color(0xFFC62828),
    SafetyTipSource.itarda: Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    final color = _palette[source] ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        source.displayName,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final SafetyTipCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.displayName,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── 免責条項バナー ──────────────────────────────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.textTertiary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                SafetyTip.disclaimer,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
