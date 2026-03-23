import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/part_listing.dart';
import '../../models/vehicle.dart';
import '../../providers/part_recommendation_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// パーツ詳細画面
///
/// - pros/cons 一覧
/// - 互換性詳細（車両指定時）
/// - 問い合わせボタン
class PartDetailScreen extends StatefulWidget {
  final PartListing part;
  final Vehicle? vehicle;

  const PartDetailScreen({super.key, required this.part, this.vehicle});

  @override
  State<PartDetailScreen> createState() => _PartDetailScreenState();
}

class _PartDetailScreenState extends State<PartDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<PartRecommendationProvider>()
          .loadPartDetail(widget.part.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PartRecommendationProvider>(
      builder: (context, provider, _) {
        final part = provider.currentPartDetail ?? widget.part;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Text(part.name),
            actions: [
              if (part.isFeatured)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        '広告',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: provider.isDetailLoading
              ? const AppLoadingCenter(message: 'パーツ情報を読み込み中...')
              : provider.detailErrorMessage != null
                  ? AppErrorState(
                      message: provider.detailErrorMessage!,
                      onRetry: () =>
                          provider.loadPartDetail(widget.part.id),
                    )
                  : _buildBody(context, part, isDark),
          bottomNavigationBar: provider.detailErrorMessage == null
              ? _InquiryBottomBar(part: part)
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PartListing part, bool isDark) {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        // ── 画像ギャラリー ──────────────────────────────────────────────────
        if (part.imageUrls.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: part.imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  part.imageUrls[index],
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 200,
                    color:
                        isDark ? AppColors.darkCard : AppColors.backgroundLight,
                    child: const Icon(Icons.build_outlined,
                        size: 48, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),

        if (part.imageUrls.isNotEmpty) AppSpacing.verticalLg,

        // ── 基本情報 ──────────────────────────────────────────────────────────
        _SectionHeader(label: '基本情報'),
        AppSpacing.verticalSm,
        _InfoTable(
          rows: [
            _InfoRow('カテゴリ', part.category.displayName),
            if (part.brand != null) _InfoRow('ブランド', part.brand!),
            if (part.partNumber != null)
              _InfoRow('品番', part.partNumber!),
            _InfoRow('価格', part.priceDisplay),
            if (part.isPriceNegotiable)
              _InfoRow('価格交渉', '応相談'),
            if (part.rating != null)
              _InfoRow('評価', '★ ${part.rating!.toStringAsFixed(1)} (${part.reviewCount}件)'),
          ],
          isDark: isDark,
        ),

        AppSpacing.verticalLg,

        // ── 説明 ──────────────────────────────────────────────────────────────
        _SectionHeader(label: '説明'),
        AppSpacing.verticalSm,
        Text(
          part.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        // ── メリット・デメリット ──────────────────────────────────────────────
        if (part.prosAndCons.isNotEmpty) ...[
          AppSpacing.verticalLg,
          _ProConSection(part: part),
        ],

        // ── 互換性 ──────────────────────────────────────────────────────────
        AppSpacing.verticalLg,
        _CompatibilitySection(part: part, vehicle: widget.vehicle),

        // ── タグ ──────────────────────────────────────────────────────────────
        if (part.tags.isNotEmpty) ...[
          AppSpacing.verticalLg,
          _SectionHeader(label: 'タグ'),
          AppSpacing.verticalSm,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: part.tags
                .map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      backgroundColor: isDark
                          ? AppColors.darkCard
                          : AppColors.backgroundLight,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],

        AppSpacing.verticalXxl,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// セクションヘッダー
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 情報テーブル
// ---------------------------------------------------------------------------

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

class _InfoTable extends StatelessWidget {
  final List<_InfoRow> rows;
  final bool isDark;

  const _InfoTable({required this.rows, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.backgroundSecondary,
        ),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Container(
            decoration: BoxDecoration(
              border: i < rows.length - 1
                  ? Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white12
                            : AppColors.backgroundSecondary,
                      ),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    row.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(row.value, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// メリット・デメリット
// ---------------------------------------------------------------------------

class _ProConSection extends StatelessWidget {
  final PartListing part;

  const _ProConSection({required this.part});

  @override
  Widget build(BuildContext context) {
    final pros = part.pros;
    final cons = part.cons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'メリット・デメリット'),
        AppSpacing.verticalSm,
        if (pros.isNotEmpty) ...[
          _ProConGroup(
            label: 'メリット',
            icon: Icons.thumb_up_outlined,
            color: AppColors.success,
            items: pros.map((p) => p.text).toList(),
          ),
          AppSpacing.verticalSm,
        ],
        if (cons.isNotEmpty)
          _ProConGroup(
            label: 'デメリット',
            icon: Icons.thumb_down_outlined,
            color: AppColors.error,
            items: cons.map((c) => c.text).toList(),
          ),
      ],
    );
  }
}

class _ProConGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _ProConGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodySmall),
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

// ---------------------------------------------------------------------------
// 互換性セクション
// ---------------------------------------------------------------------------

class _CompatibilitySection extends StatelessWidget {
  final PartListing part;
  final Vehicle? vehicle;

  const _CompatibilitySection({required this.part, this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: '互換性'),
        AppSpacing.verticalSm,

        // 自車との互換性（車両指定時）
        if (vehicle != null)
          _MyCarCompatibilityCard(part: part, vehicle: vehicle!, isDark: isDark),

        if (vehicle != null) AppSpacing.verticalSm,

        // デフォルト互換性
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(
              color: isDark ? Colors.white12 : AppColors.backgroundSecondary,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '一般的な互換性: ${part.defaultCompatibility.displayName}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),

        // 互換車両リスト
        if (part.compatibleVehicles.isNotEmpty) ...[
          AppSpacing.verticalSm,
          Text(
            '対応確認済み車種（${part.compatibleVehicles.length}台）:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.textTertiary,
            ),
          ),
          AppSpacing.verticalXs,
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: part.compatibleVehicles.take(10).map((spec) {
              return Chip(
                label: Text(
                  '${spec.makerId ?? ""} ${spec.modelId ?? ""}${spec.yearFrom != null ? " ${spec.yearFrom}年〜" : ""}',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor:
                    isDark ? AppColors.darkCard : AppColors.backgroundLight,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
          if (part.compatibleVehicles.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'および他${part.compatibleVehicles.length - 10}台',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MyCarCompatibilityCard extends StatelessWidget {
  final PartListing part;
  final Vehicle vehicle;
  final bool isDark;

  const _MyCarCompatibilityCard({
    required this.part,
    required this.vehicle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use maker/model as IDs (vehicle model uses name strings as IDs)
    final compatibility = part.getCompatibilityFor(
      makerId: vehicle.maker,
      modelId: vehicle.model,
      year: vehicle.year,
    );

    final (color, icon, label) = switch (compatibility) {
      CompatibilityLevel.perfect => (
          AppColors.success,
          Icons.check_circle_outline,
          '完全適合'
        ),
      CompatibilityLevel.compatible => (
          AppColors.info,
          Icons.check_circle_outline,
          '適合'
        ),
      CompatibilityLevel.conditional => (
          AppColors.warning,
          Icons.warning_amber_outlined,
          '条件付き適合'
        ),
      CompatibilityLevel.incompatible => (
          AppColors.error,
          Icons.cancel_outlined,
          '非対応'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'あなたの車との互換性: $label',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  '${vehicle.maker} ${vehicle.model} ${vehicle.year}年式',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary,
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

// ---------------------------------------------------------------------------
// 問い合わせボタン（BottomBar）
// ---------------------------------------------------------------------------

class _InquiryBottomBar extends StatelessWidget {
  final PartListing part;

  const _InquiryBottomBar({required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : AppColors.backgroundSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          // 価格表示
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.priceDisplay,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (part.isPriceNegotiable)
                  Text(
                    '※ 価格交渉可能',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 問い合わせボタン
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('工場・業者タブから問い合わせできます')),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('問い合わせ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
