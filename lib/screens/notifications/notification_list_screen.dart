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
    final dateFormat = DateFormat('MM/dd');

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
            border: notification.isRead
                ? null
                : Border(
                    left: BorderSide(
                      color: _getPriorityColor(notification.priority),
                      width: 4,
                    ),
                  ),
          ),
          child: ListTile(
            leading: _buildLeadingIcon(),
            title: Text(
              notification.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSpacing.verticalXxs,
                Text(
                  notification.message,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.verticalXxs,
                Text(
                  notification.actionDate != null
                      ? '推奨日: ${dateFormat.format(notification.actionDate!)}'
                      : dateFormat.format(notification.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPriorityIndicator(),
                if (!notification.isRead) ...[
                  AppSpacing.verticalXxs,
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            contentPadding: AppSpacing.paddingCard,
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    final color = _getTypeColor(notification.type);
    final icon = _getTypeIcon(notification.type);

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildPriorityIndicator() {
    final color = _getPriorityColor(notification.priority);
    IconData icon;

    switch (notification.priority) {
      case NotificationPriority.high:
        icon = Icons.priority_high;
        break;
      case NotificationPriority.medium:
        icon = Icons.remove;
        break;
      case NotificationPriority.low:
        icon = Icons.arrow_downward;
        break;
    }

    return Icon(icon, color: color, size: 16);
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
