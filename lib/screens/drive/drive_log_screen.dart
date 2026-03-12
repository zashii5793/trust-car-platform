import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/drive_log.dart';
import '../../providers/drive_log_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// ドライブログ一覧画面
///
/// 自分のドライブ履歴をカード形式で表示する。
/// - 距離・時間・平均速度などの統計を表示
/// - 天気・道路種別バッジ表示
/// - プルリフレッシュ対応
class DriveLogScreen extends StatefulWidget {
  const DriveLogScreen({super.key});

  @override
  State<DriveLogScreen> createState() => _DriveLogScreenState();
}

class _DriveLogScreenState extends State<DriveLogScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _load() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null) return;
    context.read<DriveLogProvider>().loadUserDriveLogs(userId);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.firebaseUser?.uid;
      if (userId != null) {
        context.read<DriveLogProvider>().loadMore(userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドライブログ'),
      ),
      body: Consumer<DriveLogProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.logs.isEmpty) {
            return const AppLoadingCenter(message: 'ドライブログを読み込み中...');
          }

          if (provider.error != null && provider.logs.isEmpty) {
            return AppErrorState(
              message: provider.errorMessage ?? 'エラーが発生しました',
              onRetry: _load,
            );
          }

          if (provider.logs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'ドライブログがありません',
              description: 'ドライブを記録してみましょう',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.builder(
              controller: _scrollController,
              padding: AppSpacing.paddingScreen,
              itemCount:
                  provider.logs.length + (provider.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == provider.logs.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _DriveLogCard(log: provider.logs[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ドライブログカード
// ---------------------------------------------------------------------------

class _DriveLogCard extends StatelessWidget {
  final DriveLog log;

  const _DriveLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusMd,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ヘッダー ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ドライブアイコン
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.title ?? 'ドライブ記録',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(log.startTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 天気バッジ
                if (log.weather != null)
                  _WeatherBadge(weather: log.weather!),
              ],
            ),
          ),

          // ── 経路情報 ────────────────────────────────────────────────────
          if (log.startAddress != null || log.endAddress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _RouteRow(
                from: log.startAddress,
                to: log.endAddress,
                isDark: isDark,
              ),
            ),

          if (log.startAddress != null || log.endAddress != null)
            const SizedBox(height: 8),

          // ── 統計 ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _StatsRow(statistics: log.statistics, isDark: isDark),
          ),

          // ── タグ・道路種別 ──────────────────────────────────────────────
          if (log.roadTypes.isNotEmpty || log.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...log.roadTypes.take(3).map(
                        (rt) => _SmallChip(
                          label: rt.displayName,
                          color: AppColors.info,
                        ),
                      ),
                  ...log.tags.take(3).map(
                        (tag) => _SmallChip(label: '#$tag'),
                      ),
                ],
              ),
            ),

          // ── フッター（いいね数・削除） ──────────────────────────────────
          _CardFooter(log: log),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('yyyy年M月d日 HH:mm').format(dt);
  }
}

// ---- 天気バッジ ----

class _WeatherBadge extends StatelessWidget {
  final WeatherCondition weather;

  const _WeatherBadge({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        weather.displayName,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

// ---- 経路行 ----

class _RouteRow extends StatelessWidget {
  final String? from;
  final String? to;
  final bool isDark;

  const _RouteRow({this.from, this.to, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Row(
      children: [
        Icon(Icons.radio_button_checked, size: 12, color: AppColors.success),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            from ?? '出発地',
            style: theme.textTheme.bodySmall?.copyWith(color: tertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward, size: 12, color: tertiary),
        const SizedBox(width: 4),
        Icon(Icons.location_on, size: 12, color: AppColors.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            to ?? '目的地',
            style: theme.textTheme.bodySmall?.copyWith(color: tertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---- 統計行 ----

class _StatsRow extends StatelessWidget {
  final DriveStatistics statistics;
  final bool isDark;

  const _StatsRow({required this.statistics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _StatItem(
          icon: Icons.route,
          label: '距離',
          value: '${(statistics.totalDistance / 1000).toStringAsFixed(1)} km',
          theme: theme,
          isDark: isDark,
        ),
        _StatItem(
          icon: Icons.timer,
          label: '時間',
          value: statistics.formattedDuration,
          theme: theme,
          isDark: isDark,
        ),
        _StatItem(
          icon: Icons.speed,
          label: '平均速度',
          value: '${statistics.averageSpeed.toStringAsFixed(0)} km/h',
          theme: theme,
          isDark: isDark,
        ),
        if (statistics.fuelEfficiency != null)
          _StatItem(
            icon: Icons.local_gas_station,
            label: '燃費',
            value: '${statistics.fuelEfficiency!.toStringAsFixed(1)} km/L',
            theme: theme,
            isDark: isDark,
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: tertiary),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: tertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---- スモールチップ ----

class _SmallChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _SmallChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: c,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---- カードフッター ----

class _CardFooter extends StatelessWidget {
  final DriveLog log;

  const _CardFooter({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          // 公開/非公開アイコン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(
              log.isPublic ? Icons.public : Icons.lock_outline,
              size: 16,
              color: tertiary,
            ),
          ),
          // いいね数
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, size: 16, color: tertiary),
                const SizedBox(width: 4),
                Text(
                  '${log.likeCount}',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: tertiary),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 削除ボタン
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final userId = authProvider.firebaseUser?.uid ?? '';
              if (log.userId != userId || userId.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: tertiary),
                onPressed: () => _confirmDelete(context, userId),
                tooltip: '削除',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ドライブログを削除'),
        content: const Text('このドライブログを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context
          .read<DriveLogProvider>()
          .deleteDriveLog(log.id, userId);
    }
  }
}
