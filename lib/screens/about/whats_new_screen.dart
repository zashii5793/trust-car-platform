import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../core/error/app_error.dart';
import '../../core/result/result.dart';
import '../../models/app_release_note.dart';
import '../../services/release_notes_service.dart';

/// アップデート情報（What's New）画面
///
/// アプリ同梱の更新履歴を新しいバージョン順に表示する。先頭バージョンには
/// プロダクトの売り（どの店舗でも車両管理情報を引き継げる点）を大きく打ち出す。
class WhatsNewScreen extends StatefulWidget {
  /// テスト用にサービスを差し替え可能。本番では ServiceLocator から取得する。
  final ReleaseNotesService? service;

  const WhatsNewScreen({super.key, this.service});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  late final ReleaseNotesService _service;
  List<AppReleaseNote>? _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? sl.get<ReleaseNotesService>();
    // Bundled data resolves synchronously; assign directly on first build
    // (no setState during initState).
    _apply(_service.getReleaseNotes());
  }

  void _apply(Result<List<AppReleaseNote>, AppError> result) {
    result.when(
      success: (notes) {
        _notes = notes;
        _error = null;
      },
      failure: (e) => _error = e.userMessage,
    );
  }

  void _reload() {
    setState(() => _apply(_service.getReleaseNotes()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アップデート情報')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        key: const Key('whats_new_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _reload, child: const Text('再読み込み')),
          ],
        ),
      );
    }

    final notes = _notes;
    if (notes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notes.isEmpty) {
      return const Center(
        key: Key('whats_new_empty'),
        child: Text(
          '更新情報はまだありません',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xl),
      itemBuilder: (_, i) => _ReleaseNoteSection(
        note: notes[i],
        isLatest: i == 0,
      ),
    );
  }
}

// ── バージョンごとのセクション ──────────────────────────────────────────────

class _ReleaseNoteSection extends StatelessWidget {
  final AppReleaseNote note;
  final bool isLatest;

  const _ReleaseNoteSection({required this.note, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: Key('release_note_${note.version}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // バージョン見出し
        Row(
          children: [
            Text(
              'v${note.version}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (isLatest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                ),
                child: const Text(
                  '最新',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Spacer(),
            Text(
              _formatDate(note.releasedAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 売りを打ち出すヘッドライン
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.celebration_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  note.headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // ハイライト一覧
        for (final highlight in note.highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _HighlightCard(highlight: highlight),
          ),
      ],
    );
  }

  static String _formatDate(DateTime d) => '${d.year}年${d.month}月${d.day}日';
}

// ── ハイライトカード ────────────────────────────────────────────────────────

class _HighlightCard extends StatelessWidget {
  final ReleaseHighlight highlight;

  const _HighlightCard({required this.highlight});

  static const _typeColors = <ReleaseHighlightType, Color>{
    ReleaseHighlightType.feature: AppColors.primary,
    ReleaseHighlightType.improvement: AppColors.info,
    ReleaseHighlightType.fix: AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColors[highlight.type] ?? AppColors.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(label: highlight.type.label, color: color),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    highlight.title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (highlight.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                highlight.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
