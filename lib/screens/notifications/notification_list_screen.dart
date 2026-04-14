import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_notification.dart';
import '../../models/vehicle.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../vehicle_detail_screen.dart';

/// 通知一覧（Scaffold なし — HomeScreen の AppBar に統合）
class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const AppLoadingCenter();
        }

        if (provider.notifications.isEmpty) {
          return const AppEmptyState(
            icon: Icons.notifications_none,
            title: '通知はありません',
            description: 'メンテナンスの推奨がある場合はここに表示されます',
          );
        }

        return ListView.builder(
          padding: AppSpacing.paddingScreen,
          itemCount: provider.notifications.length,
          itemBuilder: (context, index) {
            final notification = provider.notifications[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _NotificationCard(
                notification: notification,
                onTap: () {
                  provider.markAsRead(notification.id);
                  _showNotificationDetail(context, notification);
                },
                onDismiss: () {
                  provider.removeNotification(notification.id);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationDetail(
      BuildContext context, AppNotification notification) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: AppSpacing.paddingScreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ハンドル
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // アイコンとタイプ
                  Row(
                    children: [
                      _buildTypeIcon(notification),
                      AppSpacing.horizontalSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(notification.type)
                              .withValues(alpha: 0.1),
                          borderRadius: AppSpacing.borderRadiusXs,
                        ),
                        child: Text(
                          notification.typeDisplayName,
                          style: TextStyle(
                            color: _getTypeColor(notification.type),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildPriorityBadge(notification.priority),
                    ],
                  ),
                  AppSpacing.verticalMd,

                  // タイトル
                  Text(
                    notification.title,
                    style: theme.textTheme.headlineLarge,
                  ),
                  AppSpacing.verticalSm,

                  // メッセージ
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyLarge,
                  ),
                  AppSpacing.verticalLg,

                  // 詳細情報
                  if (notification.actionDate != null) ...[
                    _DetailRow(
                      icon: Icons.event,
                      label: '推奨日',
                      value: dateFormat.format(notification.actionDate!),
                    ),
                  ],
                  _DetailRow(
                    icon: Icons.access_time,
                    label: '作成日時',
                    value: DateFormat('yyyy/MM/dd HH:mm')
                        .format(notification.createdAt),
                  ),

                  AppSpacing.verticalXl,

                  // 車両詳細へ移動するボタン（vehicleId がある場合のみ）
                  if (notification.vehicleId != null) ...[
                    _VehicleNavigationButton(
                      vehicleId: notification.vehicleId!,
                    ),
                    AppSpacing.verticalSm,
                  ],

                  // 閉じるボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('閉じる'),
                    ),
                  ),
                  AppSpacing.verticalMd,
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeIcon(AppNotification notification) {
    final color = _getTypeColor(notification.type);
    final icon = _getTypeIcon(notification.type);

    return CircleAvatar(
      backgroundColor: color,
      radius: 20,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.maintenanceRecommendation:
        return AppColors.maintenanceParts;
      case NotificationType.inspectionReminder:
        return AppColors.maintenanceCarInspection;
      case NotificationType.partsReplacement:
        return AppColors.maintenanceRepair;
      case NotificationType.system:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.maintenanceRecommendation:
        return Icons.build;
      case NotificationType.inspectionReminder:
        return Icons.verified;
      case NotificationType.partsReplacement:
        return Icons.settings;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Widget _buildPriorityBadge(NotificationPriority priority) {
    Color color;
    String label;

    switch (priority) {
      case NotificationPriority.high:
        color = AppColors.error;
        label = '重要';
        break;
      case NotificationPriority.medium:
        color = AppColors.warning;
        label = '注意';
        break;
      case NotificationPriority.low:
        color = AppColors.info;
        label = '情報';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusXs,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 車両詳細への導線ボタン
// ---------------------------------------------------------------------------

class _VehicleNavigationButton extends StatelessWidget {
  final String vehicleId;

  const _VehicleNavigationButton({required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        final Vehicle? vehicle = vehicleProvider.vehicles
            .where((v) => v.id == vehicleId)
            .firstOrNull;

        if (vehicle == null) return const SizedBox.shrink();

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              // Provider を pop 前に取得
              final maintenanceProvider =
                  Provider.of<MaintenanceProvider>(context, listen: false);
              vehicleProvider.selectVehicle(vehicle);
              maintenanceProvider.listenToMaintenanceRecords(vehicle.id);
              Navigator.pop(context); // BottomSheet を閉じる
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleDetailScreen(vehicle: vehicle),
                ),
              );
            },
            icon: const Icon(Icons.directions_car),
            label: Text('${vehicle.maker} ${vehicle.model} を確認する'),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Card
// ---------------------------------------------------------------------------

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(notification.priority);
    final typeColor = _getTypeColor(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            // 未読時は優先度カラーで薄く染める
            color: notification.isRead
                ? null
                : priorityColor.withValues(alpha: isDark ? 0.07 : 0.05),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 優先度アクセントバー
              Container(
                width: 4,
                height: double.infinity,
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? Colors.transparent
                      : priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusMd),
                    bottomLeft: Radius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
              // アイコン
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.md, 0, AppSpacing.md),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getTypeIcon(notification.type),
                      color: typeColor, size: 22),
                ),
              ),
              // コンテンツ
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイプバッジ + 時間
                      Row(
                        children: [
                          _TypeBadge(
                              label: notification.typeDisplayName,
                              color: typeColor),
                          const Spacer(),
                          Text(
                            _timeAgo(notification.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          // 未読ドット
                          if (!notification.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // タイトル
                      Text(
                        notification.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // メッセージ
                      Text(
                        notification.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 推奨日（ある場合）
                      if (notification.actionDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.event,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary),
                            const SizedBox(width: 3),
                            Text(
                              '推奨日: ${DateFormat('yyyy/MM/dd').format(notification.actionDate!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      // 優先度バッジ（高・中のみ表示）
                      if (notification.priority != NotificationPriority.low)
                        _PriorityBadge(priority: notification.priority),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  /// 相対時間文字列を返す（例: 3分前、2時間前、5日前）
  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 30) return '${diff.inDays}日前';
    return DateFormat('MM/dd').format(dt);
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.maintenanceRecommendation:
        return AppColors.maintenanceParts;
      case NotificationType.inspectionReminder:
        return AppColors.maintenanceCarInspection;
      case NotificationType.partsReplacement:
        return AppColors.maintenanceRepair;
      case NotificationType.system:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.maintenanceRecommendation:
        return Icons.build_rounded;
      case NotificationType.inspectionReminder:
        return Icons.verified_rounded;
      case NotificationType.partsReplacement:
        return Icons.settings_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
    }
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.high:
        return AppColors.error;
      case NotificationPriority.medium:
        return AppColors.warning;
      case NotificationPriority.low:
        return AppColors.info;
    }
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final NotificationPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    switch (priority) {
      case NotificationPriority.high:
        color = AppColors.error;
        label = '重要';
        icon = Icons.priority_high_rounded;
        break;
      case NotificationPriority.medium:
        color = AppColors.warning;
        label = '要注意';
        icon = Icons.warning_amber_rounded;
        break;
      case NotificationPriority.low:
        color = AppColors.info;
        label = '情報';
        icon = Icons.info_outline_rounded;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSpacing.iconSm,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
