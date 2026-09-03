import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../models/drive_log.dart';
import '../models/app_notification.dart';
import '../providers/maintenance_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_subscription_provider.dart';
import '../services/drive_log_service.dart';
import '../services/maintenance_schedule_service.dart';
import '../core/di/service_locator.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/loading_indicator.dart';
import 'add_maintenance_screen.dart';
import 'drive/drive_log_screen.dart';
import '../widgets/maintenance/maintenance_ai_comment.dart';
import '../widgets/maintenance/maintenance_detail_breakdown.dart';
import 'export/export_dialog.dart';
import 'marketplace/shop_list_screen.dart';
import 'parts/part_recommendation_screen.dart';
import 'vehicle_edit_screen.dart';
import 'insurance_edit_screen.dart';
import 'maintenance_stats_screen.dart';
import 'maintenance_search_screen.dart';
import '../services/firebase_service.dart';
import '../services/community_trend_service.dart';
import '../core/timeline/mileage_milestone.dart';
import '../models/year_in_review.dart';
import 'year_in_review_screen.dart';
import 'fuel/add_fuel_screen.dart';
import '../services/fuel_service.dart';
import '../widgets/vehicle/maker_badge.dart';

// Data returned by _InspectionCompleteDialog when the user confirms.
class _InspectionCompletionResult {
  final DateTime newExpiryDate;
  final int? mileage;
  const _InspectionCompletionResult(
      {required this.newExpiryDate, this.mileage});
}

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Vehicle _vehicle;

  /// Guards the quick-action flows (車検完了 / 走行距離更新) against
  /// double-submission while an async update is in flight.
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    // Own the maintenance subscription for this vehicle so newly added records
    // (including ones created from this screen) stream into the timeline even
    // when the navigating screen never started the listener. Without this the
    // timeline can stay empty right after adding a record.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MaintenanceProvider>().listenToMaintenanceRecords(
            _vehicle.id,
          );
    });
  }

  String _formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// Explains why a records-dependent action is not available yet, and offers
  /// the one step that makes it available.
  ///
  /// Greying the icon out was the whole message before: the user could not tell
  /// "not available yet" from "broken", and nothing on screen said what to do.
  void _showNeedsRecordsMessage(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureは、整備記録が1件以上あると使えます'),
        action: SnackBarAction(
          label: '記録を追加',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddMaintenanceScreen(
                vehicleId: _vehicle.id,
                currentVehicleMileage: _vehicle.mileage,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPdfUpgradeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('プレミアムプランが必要です'),
        content: const Text(
          'PDF出力はプレミアムプランの機能です。\n'
          'プレミアムプランにアップグレードしてご利用ください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showExportTypeSelector(
      BuildContext context, List<MaintenanceRecord> records) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Text(
                'PDFエクスポートの種類を選択',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                key: const Key('export_karte_option'),
                leading: const Icon(Icons.book_outlined),
                title: const Text('愛車カルテ'),
                subtitle: const Text('車両情報＋整備履歴の完全記録'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showExportDialog(
                    context: context,
                    vehicle: _vehicle,
                    records: records,
                    exportType: ExportType.vehicleKarte,
                  );
                },
              ),
              ListTile(
                key: const Key('export_report_option'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('整備履歴レポート'),
                subtitle: const Text('整備記録の一覧と費用サマリー'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showExportDialog(
                    context: context,
                    vehicle: _vehicle,
                    records: records,
                    exportType: ExportType.maintenanceReport,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleEditScreen(vehicle: _vehicle),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _vehicle = result;
      });
    }
  }

  Future<void> _showInspectionCompleteDialog() async {
    if (_isProcessing) return;
    if (_vehicle.inspectionExpiryDate == null) return;
    // Capture context-dependent objects before any async gap.
    final maintenanceProvider = context.read<MaintenanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<_InspectionCompletionResult>(
      context: context,
      builder: (_) => _InspectionCompleteDialog(
        currentExpiry: _vehicle.inspectionExpiryDate!,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final firebaseService = sl.get<FirebaseService>();
      final updated = _vehicle.copyWith(
        inspectionExpiryDate: result.newExpiryDate,
        updatedAt: DateTime.now(),
      );

      final updateResult =
          await firebaseService.updateVehicle(_vehicle.id, updated);
      if (!mounted) return;

      // Abort if the expiry-date update itself failed — do not show success.
      if (updateResult.isFailure) {
        messenger.showSnackBar(
          const SnackBar(content: Text('車検完了の記録に失敗しました')),
        );
        return;
      }

      // Ignore an obviously-wrong mileage (below the vehicle's current value)
      // to keep the record consistent with the odometer.
      final mileageAtService =
          (result.mileage != null && result.mileage! >= _vehicle.mileage)
              ? result.mileage
              : null;

      final added = await maintenanceProvider.addMaintenanceRecord(
        MaintenanceRecord(
          id: '',
          vehicleId: _vehicle.id,
          userId: _vehicle.userId,
          type: MaintenanceType.legalInspection24,
          title: '車検',
          date: DateTime.now(),
          cost: 0,
          createdAt: DateTime.now(),
          mileageAtService: mileageAtService,
        ),
      );
      if (!mounted) return;

      setState(() => _vehicle = updated);
      messenger.showSnackBar(
        SnackBar(
          content: Text(added ? '車検完了を記録しました' : '満了日は更新しましたが整備記録の追加に失敗しました'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 整備記録に残っている直近の店舗名。無ければ null。
  ///
  /// 「いつもの店に相談」の宛先に使う。記録は日付降順で保持されている。
  String? _latestShopName() {
    final provider = context.read<MaintenanceProvider>();
    for (final record in provider.records) {
      final name = record.shopName;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    return null;
  }

  Future<void> _showMileageUpdateDialog() async {
    if (_isProcessing) return;
    final messenger = ScaffoldMessenger.of(context);

    final newMileage = await showDialog<int>(
      context: context,
      builder: (_) => _MileageUpdateDialog(currentMileage: _vehicle.mileage),
    );

    if (newMileage == null || !mounted) return;
    if (newMileage <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('正しい走行距離を入力してください')),
      );
      return;
    }

    // Guard against odometer regression — almost always a typo. Allow the
    // user to override for legitimate cases (meter replacement / swap).
    if (newMileage < _vehicle.mileage) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('走行距離の確認'),
          content: Text(
            '入力値 ${_formatNumber(newMileage)} km は現在の登録値 '
            '${_formatNumber(_vehicle.mileage)} km より小さい値です。'
            'このまま更新しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('confirm_mileage_regression_btn'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('更新する'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isProcessing = true);
    try {
      final firebaseService = sl.get<FirebaseService>();
      final updated = _vehicle.copyWith(
        mileage: newMileage,
        mileageUpdatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await firebaseService.updateVehicle(_vehicle.id, updated);
      if (!mounted) return;

      result.when(
        success: (_) {
          setState(() => _vehicle = updated);
          messenger.showSnackBar(
            const SnackBar(content: Text('走行距離を更新しました')),
          );
        },
        failure: (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('走行距離の更新に失敗しました')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_vehicle.maker} ${_vehicle.model}'),
          actions: [
            // 整備履歴検索ボタン
            //
            // A disabled icon renders faded with no explanation, so a feature
            // that is merely unavailable looks broken. Keep it tappable and
            // say why, with the action that unlocks it.
            Consumer<MaintenanceProvider>(
              builder: (context, provider, child) {
                final empty = provider.records.isEmpty;
                return IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: empty ? '整備記録を追加すると使えます' : '整備履歴を検索',
                  onPressed: () {
                    if (empty) {
                      _showNeedsRecordsMessage(context, '整備履歴の検索');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaintenanceSearchScreen(),
                      ),
                    );
                  },
                );
              },
            ),
            // PDF出力ボタン（プレミアム機能）
            Consumer<MaintenanceProvider>(
              builder: (context, provider, child) {
                final empty = provider.records.isEmpty;
                return IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  // 空のときに押せなくするのではなく、押せて理由を言う
                  // （main 側の判断。灰色のアイコンは「壊れている」に見える）。
                  // 出す中身は #90 の種別選択に差し替え、愛車カルテと
                  // 整備記録のどちらを出すか選ばせる。
                  tooltip: empty ? '整備記録を追加すると使えます' : 'PDFで出力',
                  onPressed: () {
                    if (empty) {
                      _showNeedsRecordsMessage(context, 'PDF出力');
                      return;
                    }
                    final canExport =
                        context.read<UserSubscriptionProvider>().canExportPdf;
                    if (!canExport) {
                      _showPdfUpgradeDialog(context);
                      return;
                    }
                    _showExportTypeSelector(context, provider.records);
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.build_circle_outlined),
              tooltip: 'パーツ提案',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PartRecommendationScreen(vehicle: _vehicle),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '編集',
              onPressed: _navigateToEdit,
            ),
          ],
          bottom: TabBar(
            // This TabBar sits inside the AppBar, whose background is the
            // primary navy in light mode. Tinting the labels with
            // colorScheme.primary painted navy on navy — the tab names were
            // invisible. Colours here must contrast with the AppBar, not with
            // the page surface. Matches safety_tip_screen / accessory_showcase.
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.timeline, size: 18), text: 'すべて'),
              Tab(icon: Icon(Icons.build_outlined, size: 18), text: '整備記録'),
              Tab(
                icon: Icon(Icons.directions_car_outlined, size: 18),
                text: 'ドライブ',
              ),
            ],
          ),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 車両画像
                  _VehicleImage(imageUrls: _vehicle.imageUrls, isDark: isDark),

                  // 車両基本情報
                  Padding(
                    padding: AppSpacing.paddingScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // `Vehicle` は makerId を持たないので名前から引く。
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            MakerBadge.fromName(_vehicle.maker, size: 32),
                            AppSpacing.horizontalSm,
                            Expanded(
                              child: Text(
                                '${_vehicle.maker} ${_vehicle.model}',
                                style: theme.textTheme.displayMedium,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalSm,
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: '年式',
                          value: '${_vehicle.year}年',
                        ),
                        _InfoRow(
                          icon: Icons.star_outline,
                          label: 'グレード',
                          value: _vehicle.grade,
                        ),
                        _InfoRow(
                          icon: Icons.speed,
                          label: '走行距離',
                          value: '${_formatNumber(_vehicle.mileage)} km',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 88, top: 2),
                          child: OutlinedButton.icon(
                            key: const Key('update_mileage_btn'),
                            onPressed: _showMileageUpdateDialog,
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('更新する'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.info,
                              side: const BorderSide(color: AppColors.info),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (_vehicle.inspectionExpiryDate != null) ...[
                          _InfoRow(
                            icon: Icons.verified_outlined,
                            label: '車検満了日',
                            value: DateFormat('yyyy年MM月dd日')
                                .format(_vehicle.inspectionExpiryDate!),
                            valueColor: _vehicle.isInspectionExpired
                                ? AppColors.error
                                : _vehicle.isInspectionDueSoon
                                    ? AppColors.warning
                                    : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 88, top: 2),
                            child: OutlinedButton.icon(
                              key: const Key('inspection_complete_btn'),
                              onPressed: _showInspectionCompleteDialog,
                              icon: const Icon(Icons.task_alt, size: 15),
                              label: const Text('車検完了'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(
                                  color: AppColors.success,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          // 期限が迫っている・切れているときは「知らせる」
                          // だけでなく、その場で動ける導線を出す。
                          // 期限を知っても次の行き先が無ければ放置される。
                          if (_vehicle.isInspectionExpired ||
                              _vehicle.isInspectionDueSoon)
                            Padding(
                              padding: const EdgeInsets.only(left: 88, top: 6),
                              child: _InspectionActionButtons(
                                latestShopName: _latestShopName(),
                              ),
                            ),
                        ],
                        if (_vehicle.insuranceExpiryDate != null)
                          _InfoRow(
                            icon: Icons.shield_outlined,
                            label: '自賠責満了日',
                            value: DateFormat('yyyy年MM月dd日')
                                .format(_vehicle.insuranceExpiryDate!),
                            valueColor:
                                (_vehicle.daysUntilInsuranceExpiry != null &&
                                        _vehicle.daysUntilInsuranceExpiry! < 0)
                                    ? AppColors.error
                                    : _vehicle.isInsuranceDueSoon
                                        ? AppColors.warning
                                        : null,
                          ),
                      ],
                    ),
                  ),

                  // 任意保険情報セクション（未登録でも編集導線を表示）
                  _VoluntaryInsuranceSection(
                    vehicle: _vehicle,
                    onUpdated: (updated) => setState(() => _vehicle = updated),
                  ),

                  // リース情報セクション
                  if (_vehicle.leaseInfo != null &&
                      _vehicle.leaseInfo!.hasAnyValue)
                    _LeaseInfoSection(leaseInfo: _vehicle.leaseInfo!),

                  // オプション・装備セクション
                  if (_vehicle.equipment != null &&
                      _vehicle.equipment!.hasAnyValue)
                    _EquipmentInfoSection(equipment: _vehicle.equipment!),

                  // 点検スケジュールセクション
                  _MaintenanceScheduleSection(vehicle: _vehicle),

                  const Divider(height: 1),

                  // 統計情報
                  _StatisticsSection(
                    vehicleId: _vehicle.id,
                    onDetailsTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MaintenanceStatsScreen(
                            vehicleName: '${_vehicle.maker} ${_vehicle.model}',
                          ),
                        ),
                      );
                    },
                  ),

                  // 給油を記録（月2〜4回の接点。docs/HABIT_DESIGN.md 打ち手1）
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        key: const Key('add_fuel_entry'),
                        leading: const Icon(
                          Icons.local_gas_station_outlined,
                          color: AppColors.accentDrive,
                        ),
                        title: const Text('給油を記録'),
                        subtitle: const Text('入力は4つだけ。満タン2回で燃費が出ます'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AddFuelScreen(
                              service: sl.get<FuelService>(),
                              vehicleId: _vehicle.id,
                              userId: _vehicle.userId,
                              lastOdometer: _vehicle.mileage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // この1年のふりかえり
                  _YearInReviewCard(vehicle: _vehicle),

                  // 整備記録の査定価値バナー
                  _MaintenanceValueBanner(vehicle: _vehicle),

                  // AI提案
                  Consumer<NotificationProvider>(
                    builder: (context, notifProvider, _) {
                      final suggestions = notifProvider
                          .getNotificationsForVehicle(_vehicle.id)
                          .where((n) => !n.isRead)
                          .take(3)
                          .toList();
                      if (suggestions.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          const Divider(height: 1),
                          _VehicleAiSuggestions(
                            suggestions: suggestions,
                            vehicleId: _vehicle.id,
                            vehicleMileage: _vehicle.mileage,
                          ),
                        ],
                      );
                    },
                  ),

                  // コミュニティトレンドセクション
                  _CommunityTrendSection(vehicle: _vehicle),

                  const Divider(height: 1),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _VehicleTimeline(
                vehicle: _vehicle,
                filter: _TimelineFilter.all,
              ),
              _VehicleTimeline(
                vehicle: _vehicle,
                filter: _TimelineFilter.maintenance,
              ),
              _VehicleTimeline(
                vehicle: _vehicle,
                filter: _TimelineFilter.drive,
              ),
            ],
          ),
        ),
        // ドライブタブ(index=2)では非表示
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                if (tabController.index == 2) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  // テーマの CircleBorder が extended にも効き、ラベルが円の外へ
                  // はみ出して読めなくなるため個別に指定する。
                  shape: const StadiumBorder(),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddMaintenanceScreen(
                          vehicleId: _vehicle.id,
                          currentVehicleMileage: _vehicle.mileage,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('履歴を追加'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── 任意保険情報セクション ────────────────────────────────────────────────────

class _VoluntaryInsuranceSection extends StatelessWidget {
  final Vehicle vehicle;
  final ValueChanged<Vehicle> onUpdated;
  const _VoluntaryInsuranceSection({
    required this.vehicle,
    required this.onUpdated,
  });

  Future<void> _openEditor(BuildContext context) async {
    final updated = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(
        builder: (_) => InsuranceEditScreen(vehicle: vehicle),
      ),
    );
    if (updated != null) onUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insurance = vehicle.voluntaryInsurance;
    final money = NumberFormat('#,###');

    final days = insurance?.expiryDate?.difference(DateTime.now()).inDays;
    final isExpired = days != null && days < 0;
    final isWarning = days != null && days <= 30 && days >= 0;
    final expiryColor = isExpired
        ? AppColors.error
        : isWarning
            ? AppColors.warning
            : null;

    final hasAnyData = insurance != null &&
        (insurance.companyName != null ||
            insurance.expiryDate != null ||
            insurance.hasCoverageDetails ||
            insurance.namedInsured != null ||
            insurance.annualPremium != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security,
                      size: 16, color: AppColors.textSecondary),
                  AppSpacing.horizontalXs,
                  Text(
                    '任意保険',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('edit_insurance_btn'),
                    onPressed: () => _openEditor(context),
                    icon: Icon(
                      hasAnyData ? Icons.edit_outlined : Icons.add,
                      size: 15,
                    ),
                    label: Text(hasAnyData ? '編集' : '登録'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              if (!hasAnyData)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 2),
                  child: Text(
                    'どんな保険に入っているか記録しておきましょう',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                AppSpacing.verticalXs,
                if (insurance.contractType != null)
                  _InfoRow(
                    icon: Icons.workspace_premium_outlined,
                    label: '契約形態',
                    value: insurance.isFleetContract
                        ? 'フリート契約'
                            '${insurance.fleetDiscountRate != null ? '（割増引率 ${insurance.fleetDiscountRate!.toStringAsFixed(0)}%）' : ''}'
                        : 'ノンフリート'
                            '${insurance.nonFleetGrade != null ? '（${insurance.nonFleetGrade}等級）' : ''}',
                  ),
                if (insurance.companyName != null)
                  _InfoRow(
                    icon: Icons.business,
                    label: '保険会社',
                    value: insurance.companyName!,
                  ),
                if (insurance.namedInsured != null)
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: '記名被保険者',
                    value: insurance.namedInsured!,
                  ),
                if (insurance.expiryDate != null)
                  _InfoRow(
                    icon: Icons.event,
                    label: '満期日',
                    value:
                        DateFormat('yyyy年MM月dd日').format(insurance.expiryDate!),
                    valueColor: expiryColor,
                  ),
                if (insurance.usagePurpose != null)
                  _InfoRow(
                    icon: Icons.commute_outlined,
                    label: '使用目的',
                    value: insurance.usagePurpose!,
                  ),
                if (insurance.bodilyInjuryLimit != null)
                  _InfoRow(
                    icon: Icons.personal_injury_outlined,
                    label: '対人賠償',
                    value: insurance.bodilyInjuryLimit!,
                  ),
                if (insurance.propertyDamageLimit != null)
                  _InfoRow(
                    icon: Icons.car_crash_outlined,
                    label: '対物賠償',
                    value: insurance.propertyDamageLimit!,
                  ),
                if (insurance.personalInjuryAmount != null)
                  _InfoRow(
                    icon: Icons.healing_outlined,
                    label: '人身傷害',
                    value: insurance.personalInjuryAmount!,
                  ),
                if (insurance.hasVehicleInsurance == true)
                  _InfoRow(
                    icon: Icons.directions_car_outlined,
                    label: '車両保険',
                    value: [
                      insurance.vehicleInsuranceType,
                      if (insurance.vehicleInsuranceAmount != null)
                        '¥${money.format(insurance.vehicleInsuranceAmount)}',
                      if (insurance.vehicleInsuranceDeductible != null)
                        '免責${insurance.vehicleInsuranceDeductible}',
                    ].whereType<String>().join(' / '),
                  ),
                if (insurance.driverScope != null ||
                    insurance.driverAgeCondition != null)
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: '運転者条件',
                    value: [
                      insurance.driverScope,
                      insurance.driverAgeCondition,
                    ].whereType<String>().join(' / '),
                  ),
                if (insurance.annualPremium != null)
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: '年間保険料',
                    value: '¥${money.format(insurance.annualPremium)}'
                        '${insurance.paymentMethod != null ? '（${insurance.paymentMethod}）' : ''}',
                  ),
                if (insurance.specialClauses.isNotEmpty)
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    label: '特約',
                    value: insurance.specialClauses.join('・'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── リース情報セクション ───────────────────────────────────────────────────────

class _LeaseInfoSection extends StatelessWidget {
  final LeaseInfo leaseInfo;
  const _LeaseInfoSection({required this.leaseInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = leaseInfo.contractEndDate?.difference(DateTime.now()).inDays;
    final isExpired = days != null && days < 0;
    final isWarning = days != null && days <= 60 && days >= 0;
    final endDateColor = isExpired
        ? AppColors.error
        : isWarning
            ? AppColors.warning
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment,
                      size: 16, color: AppColors.textSecondary),
                  AppSpacing.horizontalXs,
                  Text(
                    'リース情報',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              AppSpacing.verticalXs,
              if (leaseInfo.lessorName != null)
                _InfoRow(
                  icon: Icons.business,
                  label: 'リース会社',
                  value: leaseInfo.lessorName!,
                ),
              if (leaseInfo.monthlyFee != null)
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: '月額',
                  value:
                      '¥${NumberFormat('#,###').format(leaseInfo.monthlyFee!)}',
                ),
              if (leaseInfo.contractEndDate != null)
                _InfoRow(
                  icon: Icons.event_busy,
                  label: '契約満了日',
                  value: DateFormat('yyyy年MM月dd日')
                      .format(leaseInfo.contractEndDate!),
                  valueColor: endDateColor,
                ),
              if (leaseInfo.maintenancePackDetails != null)
                _InfoRow(
                  icon: Icons.build_outlined,
                  label: 'メンテパック',
                  value: leaseInfo.maintenancePackDetails!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── オプション・装備セクション ──────────────────────────────────────────────

class _EquipmentInfoSection extends StatelessWidget {
  final VehicleEquipment equipment;
  const _EquipmentInfoSection({required this.equipment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('vehicle_equipment_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_suggest,
                      size: 16, color: AppColors.textSecondary),
                  AppSpacing.horizontalXs,
                  Text(
                    'オプション・装備',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              AppSpacing.verticalXs,
              if (equipment.navigation.hasAnyValue)
                _InfoRow(
                  icon: Icons.navigation,
                  label: 'カーナビ',
                  value: equipment.navigation.displayLabel,
                ),
              if (equipment.driveRecorder.hasAnyValue)
                _InfoRow(
                  icon: Icons.videocam,
                  label: 'ドラレコ',
                  value: equipment.driveRecorder.displayLabel,
                ),
              if (equipment.etc.hasAnyValue)
                _InfoRow(
                  icon: Icons.toll,
                  label: 'ETC',
                  value: equipment.etc.displayLabel,
                ),
              if (equipment.features.isNotEmpty ||
                  equipment.others.isNotEmpty) ...[
                AppSpacing.verticalXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    for (final f in equipment.features)
                      Chip(
                        label: Text(f.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    for (final o in equipment.others)
                      Chip(
                        label: Text(o),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── 点検スケジュールセクション ────────────────────────────────────────────────

class _MaintenanceScheduleSection extends StatelessWidget {
  final Vehicle vehicle;
  const _MaintenanceScheduleSection({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    // Section is optional — degrade gracefully when the service is
    // unavailable (e.g. in widget tests that don't register it).
    if (!sl.isRegistered<MaintenanceScheduleService>()) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheduleService = sl.get<MaintenanceScheduleService>();
    final schedule = scheduleService.generateSchedule(vehicle);
    // Show the first 5 items only
    final items = schedule.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_repeat,
                      size: 16, color: AppColors.textSecondary),
                  AppSpacing.horizontalXs,
                  Text(
                    '推奨メンテナンス周期',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              AppSpacing.verticalXs,
              ...items.map((item) {
                final nextKm = scheduleService.nextDueMileage(vehicle, item);
                String intervalText = '';
                if (item.intervalKm != null && item.intervalMonths != null) {
                  intervalText =
                      '${NumberFormat('#,###').format(item.intervalKm!)}km / ${item.intervalMonths}ヶ月毎';
                } else if (item.intervalKm != null) {
                  intervalText =
                      '${NumberFormat('#,###').format(item.intervalKm!)}km毎';
                } else if (item.intervalMonths != null) {
                  intervalText = '${item.intervalMonths}ヶ月毎';
                }
                final nextKmText = nextKm != null
                    ? '  次回: ${NumberFormat('#,###').format(nextKm)}km'
                    : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.type.icon, size: 14, color: item.type.color),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.type.displayName,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$intervalText$nextKmText',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// 車両写真。複数枚あるときは横スワイプでめくれるようにし、
/// 何枚目を見ているかをドットで示す。1枚だけのときは従来通り静止表示。
class _VehicleImage extends StatefulWidget {
  final List<String> imageUrls;
  final bool isDark;

  const _VehicleImage({required this.imageUrls, required this.isDark});

  @override
  State<_VehicleImage> createState() => _VehicleImageState();
}

class _VehicleImageState extends State<_VehicleImage> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get isDark => widget.isDark;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const height = 220.0;
    final urls = widget.imageUrls;
    Widget image;

    if (urls.isEmpty) {
      image = _buildPlaceholder(height);
    } else if (urls.length == 1) {
      image = Image.network(
        urls.first,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(height),
      );
    } else {
      image = SizedBox(
        height: height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.network(
                urls[i],
                height: height,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(height),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_index + 1} / ${urls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Gradient overlay at the bottom for smooth transition into content
    return Stack(
      children: [
        image,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (isDark ? AppColors.darkBackground : Colors.white)
                      .withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkCard, AppColors.darkSurface]
              : [AppColors.backgroundLight, AppColors.backgroundSecondary],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car,
          size: 80,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
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
            style: theme.textTheme.bodyLarge?.copyWith(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final String vehicleId;
  final VoidCallback? onDetailsTap;

  const _StatisticsSection({required this.vehicleId, this.onDetailsTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, provider, child) {
        final totalCost = provider.getTotalCost();
        final recordCount = provider.records.length;
        final verifiedCount =
            provider.records.where((r) => r.isVerified).length;

        return Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long,
                      label: '総費用',
                      value: '¥${NumberFormat('#,###').format(totalCost)}',
                      color: AppColors.primary,
                    ),
                  ),
                  AppSpacing.horizontalMd,
                  Expanded(
                    child: _StatCard(
                      icon: Icons.history,
                      label: '履歴数',
                      value: '$recordCount 件',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              if (verifiedCount > 0) ...[
                AppSpacing.verticalSm,
                Row(
                  children: [
                    Icon(Icons.verified, size: 14, color: AppColors.success),
                    AppSpacing.horizontalXxs,
                    Text(
                      '検証済み',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.horizontalXxs,
                    Text(
                      '$verifiedCount / $recordCount 件',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
              if (recordCount > 0 && onDetailsTap != null) ...[
                AppSpacing.verticalSm,
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onDetailsTap,
                    icon: const Icon(Icons.bar_chart, size: 18),
                    label: const Text('統計の詳細を見る'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSpacing.iconSm, color: color),
              AppSpacing.horizontalXs,
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
          AppSpacing.verticalXs,
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Maintenance value banner (resale/appraisal benefit)
// ---------------------------------------------------------------------------

/// 整備記録が査定時に有利になることをユーザーに伝えるバナー。
///
/// 記録が1件以上あるときのみ表示する。車検記録（carInspection）が
/// 含まれる場合は、より強い訴求文言に切り替える。
class _MaintenanceValueBanner extends StatelessWidget {
  final Vehicle vehicle;

  const _MaintenanceValueBanner({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<MaintenanceProvider>(
      builder: (context, provider, _) {
        final records = provider.records;
        if (records.isEmpty) {
          return const SizedBox.shrink();
        }

        final hasInspection = records.any(
          (r) => r.type == MaintenanceType.carInspection,
        );
        final count = records.length;

        final title =
            hasInspection ? '車検記録あり — 査定で信頼性アピール' : '整備記録 $count 件 — 査定価値UP';
        final body = hasInspection
            ? '車検・整備記録が揃っていると、査定士に適切なメンテナンスが行われた証拠を提示でき、査定額向上につながります。'
            : '整備記録を残し続けることで、売却時に「きちんと管理された車」と証明できます。記録が多いほど査定評価が高まります。';

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingScreen.horizontal / 2,
          ).copyWith(bottom: AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.25),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unified Vehicle Timeline (maintenance records + drive logs)
// ---------------------------------------------------------------------------

/// タイムラインの表示フィルタ
enum _TimelineFilter { all, maintenance, drive }

/// Timeline entry: either a maintenance record or a drive log
sealed class _TimelineEntry {
  DateTime get date;
}

class _MaintenanceEntry extends _TimelineEntry {
  final MaintenanceRecord record;
  _MaintenanceEntry(this.record);
  @override
  DateTime get date => record.date;
}

class _DriveEntry extends _TimelineEntry {
  final DriveLog log;
  _DriveEntry(this.log);
  @override
  DateTime get date => log.startTime;
}

/// List item in the timeline ListView — either a month header or a timeline entry
sealed class _TimelineListItem {}

class _TimelineMonthHeader extends _TimelineListItem {
  final int year;
  final int month;
  _TimelineMonthHeader(this.year, this.month);
}

class _TimelineEntryItem extends _TimelineListItem {
  final _TimelineEntry entry;
  final bool isFirst;
  final bool isLast;
  _TimelineEntryItem(this.entry, {required this.isFirst, required this.isLast});
}

class _MilestoneListItem extends _TimelineListItem {
  final MileageMilestone milestone;
  final bool isFirst;
  final bool isLast;
  _MilestoneListItem(
    this.milestone, {
    required this.isFirst,
    required this.isLast,
  });
}

class _VehicleTimeline extends StatefulWidget {
  final Vehicle vehicle;
  final _TimelineFilter filter;

  const _VehicleTimeline({
    required this.vehicle,
    this.filter = _TimelineFilter.all,
  });

  @override
  State<_VehicleTimeline> createState() => _VehicleTimelineState();
}

class _VehicleTimelineState extends State<_VehicleTimeline> {
  List<DriveLog> _driveLogs = [];
  bool _driveLogsLoaded = false;

  DriveLogService get _driveLogService => sl.get<DriveLogService>();

  @override
  void initState() {
    super.initState();
    _loadDriveLogs();
  }

  Future<void> _loadDriveLogs() async {
    // 整備記録のみ表示の場合はドライブログを取得しない
    if (widget.filter == _TimelineFilter.maintenance) {
      if (mounted) setState(() => _driveLogsLoaded = true);
      return;
    }
    final result = await _driveLogService.getVehicleDriveLogs(
      vehicleId: widget.vehicle.id,
      userId: widget.vehicle.userId,
    );
    if (mounted) {
      setState(() {
        _driveLogs = result.getOrElse([]);
        _driveLogsLoaded = true;
      });
    }
  }

  String get _emptyTitle {
    switch (widget.filter) {
      case _TimelineFilter.maintenance:
        return 'メンテナンス記録がありません';
      case _TimelineFilter.drive:
        return 'ドライブログがありません';
      case _TimelineFilter.all:
        return '記録がありません';
    }
  }

  String get _emptyDescription {
    switch (widget.filter) {
      case _TimelineFilter.maintenance:
        return '整備・点検・オイル交換などの記録を追加すると\nここに履歴が表示されます';
      case _TimelineFilter.drive:
        return 'ドライブログを記録してみましょう';
      case _TimelineFilter.all:
        return '整備履歴や走行記録を追加してみましょう';
    }
  }

  IconData get _emptyIcon {
    switch (widget.filter) {
      case _TimelineFilter.maintenance:
        return Icons.build_outlined;
      case _TimelineFilter.drive:
        return Icons.directions_car_outlined;
      case _TimelineFilter.all:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, maintenanceProvider, child) {
        if (maintenanceProvider.isLoading || !_driveLogsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        // A failed read must not look like "you have no records".
        // MaintenanceProvider already captures stream errors, but this screen
        // never read them: when the Firestore query failed (a missing
        // composite index, for example) records stayed empty and the user was
        // told 「メンテナンス記録がありません」 — so a real error was
        // indistinguishable from an empty history, and記録を追加しても
        // 反映されないように見えていた。
        final error = maintenanceProvider.error;
        if (error != null && maintenanceProvider.records.isEmpty) {
          return AppEmptyState(
            key: const Key('maintenance_load_error'),
            icon: Icons.cloud_off,
            title: '記録を読み込めませんでした',
            description: error.userMessage,
            // A non-retryable error used to leave no button at all, which is
            // the state that needs a next step most: the user cannot tell a
            // broken screen from an empty one. Reconnecting the stream is
            // always safe to offer — worst case the same error comes back.
            buttonLabel: maintenanceProvider.isRetryable ? '再試行' : 'もう一度読み込む',
            onButtonPressed: () => maintenanceProvider
                .listenToMaintenanceRecords(widget.vehicle.id),
          );
        }

        // Sort entries newest-first
        final entries = <_TimelineEntry>[
          if (widget.filter != _TimelineFilter.drive)
            ...maintenanceProvider.records.map(_MaintenanceEntry.new),
          if (widget.filter != _TimelineFilter.maintenance)
            ..._driveLogs.map(_DriveEntry.new),
        ]..sort((a, b) => b.date.compareTo(a.date));

        if (entries.isEmpty) {
          // Every empty state needs a next step on the screen the user is on.
          // The drive tab used to show none, on the assumption that "the
          // drive-only tab has its own recording flow" — true of DriveLogScreen,
          // but there was no way to reach it from here, so the tab dead-ended.
          final isDrive = widget.filter == _TimelineFilter.drive;
          return AppEmptyState(
            icon: _emptyIcon,
            title: _emptyTitle,
            description: _emptyDescription,
            buttonLabel: isDrive ? 'ドライブログを記録' : '整備記録を追加',
            onButtonPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isDrive
                      ? const DriveLogScreen()
                      : AddMaintenanceScreen(
                          vehicleId: widget.vehicle.id,
                          currentVehicleMileage: widget.vehicle.mileage,
                        ),
                ),
              ).then((_) {
                if (isDrive && mounted) _loadDriveLogs();
              });
            },
          );
        }

        // Detect walk-through milestones (maintenance-containing filters only).
        final milestones = widget.filter != _TimelineFilter.drive
            ? MileageMilestoneDetector.detect(maintenanceProvider.records)
            : <MileageMilestone>[];

        // Merge entries and milestones newest-first.
        // Same-date tie-break: milestones appear above (newer side) their entry.
        final allNodes = <(bool, DateTime, Object)>[
          ...entries.map((e) => (false, e.date, e as Object)),
          ...milestones.map((m) => (true, m.date, m as Object)),
        ]..sort((a, b) {
            final cmp = b.$2.compareTo(a.$2);
            if (cmp != 0) return cmp;
            // milestone (true) before entry (false) on same date
            if (a.$1 && !b.$1) return -1;
            if (!a.$1 && b.$1) return 1;
            return 0;
          });

        // Build the flat list: insert a month-header before each new year/month group.
        // Both entries and milestones participate in isFirst/isLast (line continuity).
        final items = <_TimelineListItem>[];
        int? lastYear;
        int? lastMonth;
        final nodeIndices = <int>[];
        for (final node in allNodes) {
          final nodeDate = node.$2;
          final y = nodeDate.year;
          final m = nodeDate.month;
          if (y != lastYear || m != lastMonth) {
            items.add(_TimelineMonthHeader(y, m));
            lastYear = y;
            lastMonth = m;
          }
          final isFirstNode = nodeIndices.isEmpty;
          nodeIndices.add(items.length);
          if (node.$1) {
            items.add(_MilestoneListItem(
              node.$3 as MileageMilestone,
              isFirst: isFirstNode,
              isLast: false,
            ));
          } else {
            items.add(_TimelineEntryItem(
              node.$3 as _TimelineEntry,
              isFirst: isFirstNode,
              isLast: false,
            ));
          }
        }
        // Mark the bottommost node as isLast (no line below it)
        if (nodeIndices.isNotEmpty) {
          final lastPos = nodeIndices.last;
          final last = items[lastPos];
          if (last is _MilestoneListItem) {
            items[lastPos] = _MilestoneListItem(
              last.milestone,
              isFirst: last.isFirst,
              isLast: true,
            );
          } else if (last is _TimelineEntryItem) {
            items[lastPos] = _TimelineEntryItem(
              last.entry,
              isFirst: last.isFirst,
              isLast: true,
            );
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.xs,
            bottom: AppSpacing.xxl,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return switch (item) {
              _TimelineMonthHeader(:final year, :final month) =>
                _MonthSectionHeader(year: year, month: month),
              _TimelineEntryItem(:final entry, :final isFirst, :final isLast) =>
                switch (entry) {
                  _MaintenanceEntry(:final record) => _MaintenanceTimelineItem(
                      record: record,
                      isFirst: isFirst,
                      isLast: isLast,
                      onTap: () => _showMaintenanceDetailSheet(
                        context,
                        record,
                        maintenanceProvider,
                        widget.vehicle.mileage,
                      ),
                    ),
                  _DriveEntry(:final log) => _DriveTimelineItem(
                      log: log,
                      isFirst: isFirst,
                      isLast: isLast,
                    ),
                },
              _MilestoneListItem(
                :final milestone,
                :final isFirst,
                :final isLast
              ) =>
                _MilestoneTimelineItem(
                  milestone: milestone,
                  isFirst: isFirst,
                  isLast: isLast,
                ),
            };
          },
        );
      },
    );
  }

  void _showMaintenanceDetailSheet(
    BuildContext context,
    MaintenanceRecord record,
    MaintenanceProvider provider,
    int currentVehicleMileage,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _MaintenanceDetailSheet(
        record: record,
        provider: provider,
        currentVehicleMileage: currentVehicleMileage,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month section header
// ---------------------------------------------------------------------------

class _MonthSectionHeader extends StatelessWidget {
  final int year;
  final int month;

  const _MonthSectionHeader({required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
        left: 48 + AppSpacing.sm, // align with card content
      ),
      child: Text(
        '$year年$month月',
        style: theme.textTheme.labelMedium?.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline rows
// ---------------------------------------------------------------------------

/// Maintenance record row
class _MaintenanceTimelineItem extends StatelessWidget {
  final MaintenanceRecord record;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _MaintenanceTimelineItem({
    required this.record,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  static const double _lineWidth = 2.0;
  static const double _leftColumnWidth = 48.0;
  static const double _avatarRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = record.typeColor;
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark ? AppColors.darkCard : AppColors.divider;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Left: timeline line + icon ----
          SizedBox(
            width: _leftColumnWidth,
            child: Column(
              children: [
                // Top segment of the line
                SizedBox(
                  width: _lineWidth,
                  height: _avatarRadius + 4,
                  child: isFirst
                      ? const SizedBox.shrink()
                      : ColoredBox(color: lineColor),
                ),
                // Icon circle
                CircleAvatar(
                  radius: _avatarRadius,
                  backgroundColor: typeColor,
                  child: Icon(
                    record.typeIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                // Bottom segment of the line — stretches to fill remaining height
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(
                          child: SizedBox(
                            width: _lineWidth,
                            child: ColoredBox(color: lineColor),
                          ),
                        ),
                ),
              ],
            ),
          ),

          AppSpacing.horizontalSm,

          // ---- Right: card ----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.md,
              ),
              child: Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusMd),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left type-color accent bar
                        Container(width: 4, color: typeColor),
                        Expanded(
                          child: Padding(
                            padding: AppSpacing.paddingCard,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date + type badge
                                Row(
                                  children: [
                                    Text(
                                      dateFormat.format(record.date),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xs,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            typeColor.withValues(alpha: 0.12),
                                        borderRadius: AppSpacing.borderRadiusXs,
                                      ),
                                      child: Text(
                                        record.typeDisplayName,
                                        style: TextStyle(
                                          color: typeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                AppSpacing.verticalXxs,
                                // Title
                                Text(
                                  record.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                AppSpacing.verticalXxs,
                                // Cost + mileage at service
                                Row(
                                  children: [
                                    Text(
                                      '¥${NumberFormat('#,###').format(record.cost)}',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: typeColor,
                                      ),
                                    ),
                                    if (record.mileageAtService != null) ...[
                                      const Spacer(),
                                      Icon(
                                        Icons.speed,
                                        size: 12,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.textTertiary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${NumberFormat('#,###').format(record.mileageAtService!)} km',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextTertiary
                                              : AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // Shop name (optional)
                                if (record.shopName != null &&
                                    record.shopName!.isNotEmpty) ...[
                                  AppSpacing.verticalXxs,
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.store_outlined,
                                        size: 13,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.textTertiary,
                                      ),
                                      AppSpacing.horizontalXxs,
                                      Flexible(
                                        child: Text(
                                          record.shopName!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: isDark
                                                ? AppColors.darkTextTertiary
                                                : AppColors.textTertiary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                // Verification badge (optional)
                                if (record.isVerified) ...[
                                  AppSpacing.verticalXxs,
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        size: 13,
                                        color: AppColors.success,
                                      ),
                                      AppSpacing.horizontalXxs,
                                      Text(
                                        '工場裏書き',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drive log timeline row
// ---------------------------------------------------------------------------

class _DriveTimelineItem extends StatelessWidget {
  final DriveLog log;
  final bool isFirst;
  final bool isLast;

  const _DriveTimelineItem({
    required this.log,
    required this.isFirst,
    required this.isLast,
  });

  static const double _lineWidth = 2.0;
  static const double _leftColumnWidth = 48.0;
  static const double _avatarRadius = 18.0;
  static const Color _driveColor = AppColors.info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark ? AppColors.darkCard : AppColors.divider;
    final dateFormat = DateFormat('yyyy/MM/dd');
    final distanceStr = log.statistics.totalDistance > 0
        ? '${log.statistics.totalDistance.toStringAsFixed(1)} km'
        : null;
    final durationMin = log.statistics.totalDuration ~/ 60;
    final title = log.title ??
        (log.startAddress != null ? '${log.startAddress} 発' : 'ドライブ記録');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Left: timeline line + icon ----
          SizedBox(
            width: _leftColumnWidth,
            child: Column(
              children: [
                SizedBox(
                  width: _lineWidth,
                  height: _avatarRadius + 4,
                  child: isFirst
                      ? const SizedBox.shrink()
                      : ColoredBox(color: lineColor),
                ),
                CircleAvatar(
                  radius: _avatarRadius,
                  backgroundColor: _driveColor,
                  child: const Icon(
                    Icons.directions_car_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(
                          child: SizedBox(
                            width: _lineWidth,
                            child: ColoredBox(color: lineColor),
                          ),
                        ),
                ),
              ],
            ),
          ),

          AppSpacing.horizontalSm,

          // ---- Right: card ----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.md,
              ),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateFormat.format(log.startTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _driveColor.withValues(alpha: 0.12),
                            borderRadius: AppSpacing.borderRadiusXs,
                          ),
                          child: const Text(
                            'ドライブ',
                            style: TextStyle(
                              color: _driveColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalXxs,
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (distanceStr != null || durationMin > 0) ...[
                      AppSpacing.verticalXxs,
                      Row(
                        children: [
                          if (distanceStr != null) ...[
                            Icon(
                              Icons.straighten,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              distanceStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (durationMin > 0) ...[
                            Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$durationMin分',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mileage milestone row
// ---------------------------------------------------------------------------

class _MilestoneTimelineItem extends StatelessWidget {
  final MileageMilestone milestone;
  final bool isFirst;
  final bool isLast;

  const _MilestoneTimelineItem({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
  });

  static const double _lineWidth = 2.0;
  static const double _leftColumnWidth = 48.0;
  static const double _markerRadius = 14.0;
  static const Color _milestoneColor = AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark ? AppColors.darkCard : AppColors.divider;
    final kmLabel = NumberFormat('#,###').format(milestone.km);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---- Left: timeline line + trophy icon ----
          SizedBox(
            width: _leftColumnWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _lineWidth,
                  height: _markerRadius + 4,
                  child: isFirst
                      ? const SizedBox.shrink()
                      : ColoredBox(color: lineColor),
                ),
                CircleAvatar(
                  radius: _markerRadius,
                  backgroundColor: _milestoneColor.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: _milestoneColor,
                    size: 16,
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(
                          child: SizedBox(
                            width: _lineWidth,
                            child: ColoredBox(color: lineColor),
                          ),
                        ),
                ),
              ],
            ),
          ),

          AppSpacing.horizontalSm,

          // ---- Right: slim badge ----
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: _milestoneColor.withValues(alpha: 0.12),
                borderRadius: AppSpacing.borderRadiusSm,
                border: Border.all(
                  color: _milestoneColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏁 ', style: TextStyle(fontSize: 13)),
                  Text(
                    '$kmLabel km 突破',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          isDark ? AppColors.warning : const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
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
// Detail BottomSheet
// ---------------------------------------------------------------------------

class _MaintenanceDetailSheet extends StatelessWidget {
  final MaintenanceRecord record;
  final MaintenanceProvider provider;
  final int currentVehicleMileage;

  const _MaintenanceDetailSheet({
    required this.record,
    required this.provider,
    required this.currentVehicleMileage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = record.typeColor;
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy年MM月dd日');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: AppSpacing.paddingScreen,
                children: [
                  // Header: icon + title + date
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: typeColor,
                        child: Icon(
                          record.typeIcon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      AppSpacing.horizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              dateFormat.format(record.date),
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

                  AppSpacing.verticalMd,

                  // Cost (large)
                  Text(
                    '¥${NumberFormat('#,###').format(record.cost)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),

                  AppSpacing.verticalMd,

                  // AI comment — why this maintenance matters and next schedule
                  MaintenanceAiComment(
                    record: record,
                    allRecords: provider.records,
                    currentMileage: currentVehicleMileage,
                  ),

                  AppSpacing.verticalMd,
                  const Divider(),
                  AppSpacing.verticalSm,

                  // Shop name
                  if (record.shopName != null && record.shopName!.isNotEmpty)
                    _DetailRow(
                      icon: Icons.store_outlined,
                      label: '整備店',
                      value: record.shopName!,
                    ),

                  // Mileage
                  if (record.mileageAtService != null)
                    _DetailRow(
                      icon: Icons.speed_outlined,
                      label: '施工時走行距離',
                      value:
                          '${NumberFormat('#,###').format(record.mileageAtService)} km',
                    ),

                  // Description
                  if (record.description != null &&
                      record.description!.isNotEmpty) ...[
                    AppSpacing.verticalSm,
                    Text(
                      'メモ',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                    AppSpacing.verticalXxs,
                    Text(
                      record.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],

                  // Work items
                  if (record.workItems.isNotEmpty) ...[
                    AppSpacing.verticalMd,
                    Text(
                      '作業内容',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                    AppSpacing.verticalXxs,
                    ...record.workItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxs,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16),
                            AppSpacing.horizontalXs,
                            Expanded(
                              child: Text(
                                item.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '¥${NumberFormat('#,###').format(item.laborCost)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 明細（部品 / 金額内訳 / 次回交換 / 点検結果 / タイヤ）。
                  // 請求書OCRが読み取った項目は保存されていたが、これまで
                  // 表示する画面が無く誰も見られなかった。
                  MaintenanceDetailBreakdown(record: record),

                  AppSpacing.verticalLg,

                  // Edit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddMaintenanceScreen(
                              vehicleId: record.vehicleId,
                              currentVehicleMileage: currentVehicleMileage,
                              existingRecord: record,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('この記録を編集'),
                    ),
                  ),

                  AppSpacing.verticalSm,

                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('この記録を削除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),

                  AppSpacing.verticalMd,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この整備記録を削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await provider.deleteMaintenanceRecord(record.id);
      if (context.mounted) {
        if (success) {
          Navigator.pop(context); // close the sheet only on success
        } else {
          showErrorSnackBar(context, '削除に失敗しました。再度お試しください。');
        }
      }
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
            size: 16,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showSuggestionDetail(
  BuildContext context,
  AppNotification notification, {
  String vehicleId = '',
  int vehicleMileage = 0,
}) {
  final theme = Theme.of(context);
  final dateFormat = DateFormat('yyyy/MM/dd');
  final color = _SuggestionRow._typeColor(notification.type);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: AppSpacing.paddingScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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

                // Icon + type badge + priority
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color,
                      child: Icon(
                        _SuggestionRow._typeIcon(notification.type),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    AppSpacing.horizontalSm,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.borderRadiusXs,
                      ),
                      child: Text(
                        notification.typeDisplayName,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (notification.priority == NotificationPriority.high)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: const Text(
                          '緊急',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
                AppSpacing.verticalMd,

                // Title
                Text(notification.title, style: theme.textTheme.headlineLarge),
                AppSpacing.verticalSm,

                // Message
                Text(notification.message, style: theme.textTheme.bodyLarge),
                AppSpacing.verticalLg,

                // Reason
                if (notification.reason != null) ...[
                  Container(
                    padding: AppSpacing.paddingCard,
                    decoration: BoxDecoration(
                      color: AppColors.infoBackground,
                      borderRadius: AppSpacing.borderRadiusMd,
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: AppColors.info),
                            AppSpacing.horizontalXs,
                            Text(
                              'なぜ今なのか',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalXxs,
                        Text(notification.reason!,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  AppSpacing.verticalMd,
                ],

                // Action date
                if (notification.actionDate != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 16, color: AppColors.textTertiary),
                      AppSpacing.horizontalXs,
                      Text(
                        '推奨日: ${dateFormat.format(notification.actionDate!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  AppSpacing.verticalSm,
                ],

                AppSpacing.verticalLg,

                // CTA: record maintenance
                if (vehicleId.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddMaintenanceScreen(
                                vehicleId: vehicleId,
                                currentVehicleMileage: vehicleMileage,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('今すぐ記録する'),
                    ),
                  ),
                  AppSpacing.verticalSm,
                ],

                // Close button
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

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle AI suggestions — shows unread AI recommendations for this vehicle
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleAiSuggestions extends StatelessWidget {
  final List<AppNotification> suggestions;
  final String vehicleId;
  final int vehicleMileage;

  const _VehicleAiSuggestions({
    required this.suggestions,
    required this.vehicleId,
    required this.vehicleMileage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: AppSpacing.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'AIからの提案',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.verticalSm,

          // Suggestion rows
          ...suggestions.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _SuggestionRow(
                notification: n,
                onTap: () => _showSuggestionDetail(
                  context,
                  n,
                  vehicleId: vehicleId,
                  vehicleMileage: vehicleMileage,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const _SuggestionRow({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(notification.type);

    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(_typeIcon(notification.type), size: 16, color: color),
            AppSpacing.horizontalXs,
            Expanded(
              child: Text(
                notification.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (notification.priority == NotificationPriority.high)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: const Text(
                  '緊急',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.inspectionReminder:
        return AppColors.maintenanceCarInspection;
      case NotificationType.partsReplacement:
        return AppColors.maintenanceParts;
      case NotificationType.system:
        return AppColors.info;
      case NotificationType.maintenanceRecommendation:
        return AppColors.maintenanceRepair;
    }
  }

  static IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.inspectionReminder:
        return Icons.verified_outlined;
      case NotificationType.partsReplacement:
        return Icons.build_outlined;
      case NotificationType.system:
        return Icons.info_outline;
      case NotificationType.maintenanceRecommendation:
        return Icons.car_repair;
    }
  }
}

// ── 車検完了ダイアログ ─────────────────────────────────────────────────────────

class _InspectionCompleteDialog extends StatefulWidget {
  final DateTime currentExpiry;
  const _InspectionCompleteDialog({required this.currentExpiry});

  @override
  State<_InspectionCompleteDialog> createState() =>
      _InspectionCompleteDialogState();
}

class _InspectionCompleteDialogState extends State<_InspectionCompleteDialog> {
  late DateTime _newExpiry;
  final _mileageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default: 2 years from current expiry (or from today if already expired)
    final base = widget.currentExpiry.isAfter(DateTime.now())
        ? widget.currentExpiry
        : DateTime.now();
    _newExpiry = DateTime(base.year + 2, base.month, base.day);
  }

  @override
  void dispose() {
    _mileageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('車検完了を記録'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('新しい車検満了日', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                DateFormat('yyyy年MM月dd日').format(_newExpiry),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                key: const Key('pick_expiry_date_btn'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _newExpiry,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(DateTime.now().year + 10),
                  );
                  if (picked != null) {
                    setState(() => _newExpiry = picked);
                  }
                },
                child: const Text('変更'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('inspection_mileage_field'),
            controller: _mileageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '現在の走行距離（任意）',
              suffixText: 'km',
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
          key: const Key('confirm_inspection_complete_btn'),
          onPressed: () {
            final mileage = int.tryParse(_mileageController.text.trim());
            Navigator.pop(
              context,
              _InspectionCompletionResult(
                newExpiryDate: _newExpiry,
                mileage: mileage,
              ),
            );
          },
          child: const Text('記録する'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mileage update dialog — owns its TextEditingController lifecycle
// ─────────────────────────────────────────────────────────────────────────────

class _MileageUpdateDialog extends StatefulWidget {
  final int currentMileage;

  const _MileageUpdateDialog({required this.currentMileage});

  @override
  State<_MileageUpdateDialog> createState() => _MileageUpdateDialogState();
}

class _MileageUpdateDialogState extends State<_MileageUpdateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentMileage.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('走行距離を更新'),
      content: TextField(
        key: const Key('mileage_input_field'),
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '新しい走行距離',
          suffixText: 'km',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('confirm_mileage_btn'),
          onPressed: () {
            final value = int.tryParse(_controller.text.trim());
            Navigator.pop(context, value);
          },
          child: const Text('更新'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Community trend section — shows anonymized peer maintenance stats
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityTrendSection extends StatefulWidget {
  final Vehicle vehicle;

  const _CommunityTrendSection({required this.vehicle});

  @override
  State<_CommunityTrendSection> createState() => _CommunityTrendSectionState();
}

/// 「この1年のふりかえり」への入口。
///
/// docs/HABIT_DESIGN.md 打ち手2。1年で整備記録は数十件溜まるのに、それを
/// 見返す道が履歴の一覧しかなかった。**溜めることには協力してもらっている
/// のに、溜まった価値を突き返していない。**
///
/// 中身が薄いうちは出さない。1件だけの「ふりかえり」は白ける。
class _YearInReviewCard extends StatefulWidget {
  final Vehicle vehicle;

  const _YearInReviewCard({required this.vehicle});

  @override
  State<_YearInReviewCard> createState() => _YearInReviewCardState();
}

class _YearInReviewCardState extends State<_YearInReviewCard> {
  /// 同じ車種の人の年間費用。取れなければ null のまま（比較欄が出ないだけ）。
  int? _peerAnnualCost;

  @override
  void initState() {
    super.initState();
    _fetchPeerCost();
  }

  Future<void> _fetchPeerCost() async {
    if (!sl.isRegistered<CommunityTrendService>()) return;
    final result = await sl.get<CommunityTrendService>().getTrendsForVehicle(
          maker: widget.vehicle.maker,
          model: widget.vehicle.model,
        );
    if (!mounted) return;
    setState(() => _peerAnnualCost = result.valueOrNull?.estimatedAnnualCost);
  }

  YearInReview _build(List<MaintenanceRecord> records) {
    final now = DateTime.now();
    return YearInReview.from(
      records: records.where((r) => r.vehicleId == widget.vehicle.id).toList(),
      from: DateTime(now.year - 1, now.month, now.day),
      to: now,
      peerAverageCost: _peerAnnualCost,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, provider, _) {
        final review = _build(provider.records);
        if (!review.hasEnoughData) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final fmt = NumberFormat('#,###');

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const Key('year_in_review_entry'),
              leading: const Icon(
                Icons.insights_outlined,
                color: AppColors.primary,
              ),
              title: const Text('この1年のふりかえり'),
              subtitle: Text(
                '${fmt.format(review.totalCost)}円 ・ 整備${review.recordCount}回'
                '${review.distanceKm != null ? ' ・ ${fmt.format(review.distanceKm)}km' : ''}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => YearInReviewScreen(
                    review: review,
                    vehicleName:
                        '${widget.vehicle.maker} ${widget.vehicle.model}',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommunityTrendSectionState extends State<_CommunityTrendSection> {
  CommunityTrendData? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!sl.isRegistered<CommunityTrendService>()) {
      _loaded = true; // No service available — skip async fetch
      return;
    }
    _fetchTrends();
  }

  Future<void> _fetchTrends() async {
    final service = sl.get<CommunityTrendService>();
    final result = await service.getTrendsForVehicle(
      maker: widget.vehicle.maker,
      model: widget.vehicle.model,
    );
    if (!mounted) return;
    setState(() {
      _data = result.valueOrNull;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _data == null || _data!.insights.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final data = _data!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 13,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'コミュニティの傾向',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.maker} ${data.model} オーナー ${data.sampleVehicleCount}台のデータ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.verticalSm,
              ...data.insights.take(4).map(
                    (insight) => _CommunityInsightRow(insight: insight),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityInsightRow extends StatelessWidget {
  final CommunityTrendInsight insight;

  const _CommunityInsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _maintenanceTypeLabel(insight.typeKey);
    final pct = insight.popularityPercent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(
              child: Text(
                pct != null ? '${pct.toStringAsFixed(0)}%' : '-',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  insight.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (insight.medianCost != null)
            Text(
              '¥${_formatCost(insight.medianCost!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  static String _maintenanceTypeLabel(String typeKey) {
    const labels = <String, String>{
      'oilChange': 'オイル交換',
      'oilFilterChange': 'オイルフィルター交換',
      'tireRotation': 'タイヤローテーション',
      'tireReplacement': 'タイヤ交換',
      'brakeInspection': 'ブレーキ点検',
      'brakeFluidChange': 'ブレーキフルード交換',
      'coolantChange': 'クーラント交換',
      'batteryChange': 'バッテリー交換',
      'airFilterChange': 'エアフィルター交換',
      'cabinFilterChange': 'エアコンフィルター交換',
      'transmissionFluidChange': 'AT/MTフルード交換',
      'legalInspection12': '12ヶ月法定点検',
      'legalInspection24': '車検',
      'carInspection': '車両点検',
      'other': 'その他',
    };
    return labels[typeKey] ?? typeKey;
  }

  static String _formatCost(double cost) {
    if (cost >= 10000) {
      return '${(cost / 10000).toStringAsFixed(1)}万';
    }
    return cost.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// 車検アクション導線
// ---------------------------------------------------------------------------

/// 車検の期限が迫っている・切れているときに出す行動ボタン。
///
/// 期限の警告だけでは「で、どうすれば」で止まる。その場から
/// 工場検索へ進めるようにし、過去に使った店があればその名前で
/// 検索済みの状態で開く（記録の shopName は文字列でしか持っておらず
/// shopId が無いため、名前検索で繋ぐ）。
class _InspectionActionButtons extends StatelessWidget {
  final String? latestShopName;

  const _InspectionActionButtons({required this.latestShopName});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        OutlinedButton.icon(
          key: const Key('inspection_find_shop_btn'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopListScreen()),
          ),
          icon: const Icon(Icons.search, size: 15),
          label: const Text('整備工場を探す'),
          style: _style(AppColors.warning),
        ),
        if (latestShopName != null)
          OutlinedButton.icon(
            key: const Key('inspection_contact_last_shop_btn'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ShopListScreen(maintenanceContext: latestShopName),
              ),
            ),
            icon: const Icon(Icons.history, size: 15),
            label: Text('$latestShopNameに相談'),
            style: _style(AppColors.info),
          ),
      ],
    );
  }

  ButtonStyle _style(Color color) => OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 12),
      );
}
