import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../core/theme/button_text_style.dart';
import '../core/utils/premium_upsell.dart';
import '../providers/vehicle_provider.dart';
import '../providers/drive_log_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/user_subscription_provider.dart';
import '../models/accessory_showcase.dart';
import '../services/popular_accessories_service.dart';
import '../services/drive_log_service.dart';
import '../services/part_recommendation_service.dart';
import '../models/part_listing.dart';
import '../services/vehicle_retirement_service.dart';
import '../models/maintenance_record.dart';
import '../models/drive_log.dart';
import '../models/vehicle.dart';
import '../models/app_notification.dart';
import '../models/fleet_plan.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/ai_disclaimer.dart';
import '../core/utils/inspection_urgency.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/offline_banner.dart';
import 'vehicle_registration_screen.dart';
import 'vehicle_edit_screen.dart';
import 'vehicle_detail_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/settings_screen.dart';
import 'settings/privacy_policy_screen.dart';
import 'settings/terms_of_service_screen.dart';
import 'notifications/notification_list_screen.dart';
import 'notifications/social_notification_screen.dart';
import '../core/di/service_locator.dart';
import '../services/follow_service.dart';
import '../services/mileage_notification_service.dart';
import 'marketplace/marketplace_screen.dart';
import 'marketplace/shop_list_screen.dart';
import 'marketplace/shop_owner_screen.dart';
import 'sns/sns_feed_screen.dart';
import 'drive/drive_log_detail_screen.dart';
import 'drive/drive_log_screen.dart';
import 'add_maintenance_screen.dart';
import 'fuel/add_fuel_screen.dart';
import '../services/fuel_service.dart';
import 'maintenance_search_screen.dart';
import 'ai_chat/ai_chat_screen.dart';
import 'fleet/fleet_dashboard_screen.dart';
import 'vehicle/retired_vehicles_screen.dart';
import 'accessories/accessory_showcase_screen.dart';
import 'parts/part_recommendation_screen.dart';
import 'safety/safety_tip_screen.dart';
import '../widgets/vehicle/mileage_reminder_banner.dart';
import '../widgets/vehicle/mileage_update_dialog.dart';
import '../widgets/getting_started_card.dart';
import '../services/firebase_service.dart';
import '../services/feedback_service.dart';
import 'settings/feedback_screen.dart';
import 'settings/help_screen.dart';
import '../core/constants/app_info.dart';
import 'settings/shop_invite_screen.dart';
import '../services/shop_invite_service.dart';
import '../widgets/vehicle/maker_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  VehicleProvider? _vehicleProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    _vehicleProvider = vehicleProvider;
    vehicleProvider.listenToVehicles();
    vehicleProvider.addListener(_onVehiclesChanged);
  }

  void _onVehiclesChanged() {
    if (!mounted) return;
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    if (vehicleProvider.vehicles.isEmpty) return;

    // This runs while VehicleProvider is still dispatching to its listeners.
    // Touching another provider here mutates the widget tree mid-dispatch,
    // which left _VehicleTab's `context.watch` subscription unrebuilt — the
    // list stayed on the empty-state until some other setState happened to
    // rebuild it. Deferring to the next frame lets the dispatch finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<NotificationProvider>(context, listen: false)
          .generateNotificationsForVehicles(vehicleProvider.vehicles);
      _shareInspectionExpiries(vehicleProvider.vehicles);
    });
  }

  /// かかりつけの店に、車検の満了日だけを渡す。
  ///
  /// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2 の案A。
  /// **車検を受けて満了日が延びたら、店の画面もそれに追いつく必要がある。**
  /// 顧客が設定画面を開きに来るのを待っていると、古い日付が残り続ける。
  ///
  /// かかりつけが無い人・共有を切っている人には何も書かない（サービス側で判定）。
  void _shareInspectionExpiries(List<Vehicle> vehicles) {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;
    if (userId == null || userId.isEmpty) return;

    final active = vehicles.where((v) => !v.status.isRetired).toList();

    // 失敗しても画面には出さない。本人の操作ではなく、裏の同期のため。
    sl.get<ShopInviteService>().shareInspectionExpiries(
          userId: userId,
          expiryDates: active.map((v) => v.inspectionExpiryDate).toList(),
          vehicleCount: active.length,
        );
  }

  @override
  void dispose() {
    _vehicleProvider?.removeListener(_onVehiclesChanged);
    super.dispose();
  }

  // ---- AppBar タイトル（タブ連動） ----
  /// 通知一覧を開く。
  ///
  /// タブから外して AppBar のベルに寄せた（2026-09-07）。メニューを4つに
  /// 束ねるためで、**通知は「どのタブにいても見たいもの」**なので、
  /// タブより常設のベルのほうが合う。
  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const NotificationListScreen()),
    );
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'マイカー';
      case 1:
        return 'マーケットプレイス';
      case 2:
        return 'みんなの投稿';
      case 3:
        return 'プロフィール';
      default:
        return 'マイカー';
    }
  }

  // ---- AppBar アクション（タブ連動） ----
  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    // オフラインアイコンは常に表示
    actions.add(
      Consumer<ConnectivityProvider>(
        builder: (context, connectivity, child) {
          if (connectivity.isOffline) {
            return Semantics(
              label: 'オフラインモード',
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_off,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );

    // AIチャットボタン（全タブ共通）
    actions.add(
      IconButton(
        icon: const Icon(Icons.smart_toy_outlined),
        tooltip: 'AIに聞く',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiChatScreen()),
          );
        },
      ),
    );

    // 通知のベルは全タブ共通。タブから外した分、どこからでも届くようにする。
    actions.add(
      Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final unread = provider.unreadCount;
          return IconButton(
            key: const Key('header_notifications_button'),
            tooltip: unread > 0 ? '通知 未読$unread件' : '通知',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _openNotifications,
          );
        },
      ),
    );

    // マイカータブのヘッダーに「たびの記録」。プロフィールの「アカウント」
    // セクションの奥にあり、記録したことを忘れられる位置だった（2026-09-07）。
    if (_currentIndex == 0) {
      actions.add(
        IconButton(
          key: const Key('header_drive_log_button'),
          icon: const Icon(Icons.route_outlined),
          tooltip: 'たびの記録',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const DriveLogScreen()),
          ),
        ),
      );
    }

    // マーケットプレイスタブにオーナー掲載ボタンを表示
    if (_currentIndex == 1) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.storefront_outlined),
          tooltip: '店舗を掲載する',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShopOwnerScreen()),
            );
          },
        ),
      );
    }

    // SNS（みんなの投稿）タブにソーシャル通知ベルを表示。未読数をバッジ表示し、
    // タップでソーシャル通知一覧（いいね・コメント）へ遷移する。
    //
    // 「みんなのアクセサリー」も同じ並びに置く。プロフィールの「コミュニティ」
    // セクションの奥にあり、同じコミュニティ機能なのに入口が離れていた。
    if (_currentIndex == 2) {
      actions.add(
        IconButton(
          key: const Key('header_accessories_button'),
          icon: const Icon(Icons.auto_awesome_outlined),
          tooltip: 'みんなのアクセサリー',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AccessoryShowcaseScreen(),
            ),
          ),
        ),
      );

      final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
      if (uid.isNotEmpty) {
        actions.add(
          StreamBuilder<int>(
            stream: sl.get<FollowService>().watchUnreadNotificationCount(uid),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: '通知',
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SocialNotificationScreen(userId: uid),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    // 「すべて既読」は通知タブに置いていたが、タブを外したので
    // 通知画面（NotificationListScreen）側に任せる。

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: _buildAppBarActions(),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          // 広い画面ではナビゲーションを上段に置く。ボトムナビはモバイルの
          // 作法であって、ブラウザやタブレットでは主要メニューが画面の
          // 一番下にあるのは不自然に映る。狭い画面では従来どおり下段。
          if (_useTopNavigation(context)) _buildNavigation(),
          Expanded(child: _buildBody()),
        ],
      ),
      // FABは車両タブのみ表示（SNSタブのFABはSnsFeedScreen内で管理）
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VehicleRegistrationScreen(),
                  ),
                );
              },
              tooltip: '車両を登録',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar:
          _useTopNavigation(context) ? null : _buildNavigation(),
    );
  }

  /// ナビゲーションを上段に出すか。
  ///
  /// しきい値 720 は「タブレット横向き以上」。この幅より広い環境は
  /// マウス操作が主で、親指の届きやすさを優先するボトムナビの前提が
  /// 成り立たない。
  static bool _useTopNavigation(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 720;

  /// 下段のメニュー。**2行2列**に置く。
  ///
  /// 横一列に5つ並べると、390px 幅では1項目あたり78pxしか取れず、
  /// ラベルが小さくなって押し間違えやすい。2行に分けると倍の幅が取れる。
  ///
  /// 通知はタブから外して AppBar のベルに寄せた（どのタブにいても見たい
  /// ものなので、常設のほうが合う）。残る4つを 2×2 に置いている。
  Widget _buildNavigation() {
    const items = <({IconData icon, IconData selectedIcon, String label})>[
      (
        icon: Icons.directions_car_outlined,
        selectedIcon: Icons.directions_car,
        label: 'マイカー'
      ),
      (icon: Icons.store_outlined, selectedIcon: Icons.store, label: 'マーケット'),
      (icon: Icons.forum_outlined, selectedIcon: Icons.forum, label: 'みんなの投稿'),
      (icon: Icons.person_outline, selectedIcon: Icons.person, label: 'プロフィール'),
    ];

    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 2; row++)
                Row(
                  children: [
                    for (var col = 0; col < 2; col++)
                      Expanded(
                        child: _NavCell(
                          index: row * 2 + col,
                          icon: items[row * 2 + col].icon,
                          selectedIcon: items[row * 2 + col].selectedIcon,
                          label: items[row * 2 + col].label,
                          isSelected: _currentIndex == row * 2 + col,
                          onTap: () =>
                              setState(() => _currentIndex = row * 2 + col),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _VehicleTab(onNavigateToNotifications: _openNotifications);
      case 1:
        return const MarketplaceScreen();
      case 2:
        return const SnsFeedScreen();
      case 3:
        return const _ProfileTab();
      default:
        return _VehicleTab(onNavigateToNotifications: _openNotifications);
    }
  }
}

// ---------------------------------------------------------------------------
// 車両タブ（マイカー一覧・ダッシュボード・AI提案）
// ---------------------------------------------------------------------------

class _VehicleTab extends StatefulWidget {
  /// Navigates to the notifications tab where the full AI suggestion list lives.
  final VoidCallback onNavigateToNotifications;

  const _VehicleTab({required this.onNavigateToNotifications});

  @override
  State<_VehicleTab> createState() => _VehicleTabState();
}

class _VehicleTabState extends State<_VehicleTab> {
  /// 初回ガイドを閉じたことを覚えておくキー。端末ローカルで十分
  /// （別端末で出ても困らない性質の案内なので、Firestore には置かない）。
  static const _gettingStartedDismissedKey = 'getting_started_dismissed';

  /// 「整備の記録が1件でもあるか」。車両ごとではなくアカウント全体で見るため、
  /// MaintenanceProvider（車両単位）ではなく専用の1件読みを使う。
  bool _hasMaintenanceRecord = false;
  bool _gettingStartedDismissed = false;

  /// 読み込みが終わるまでガイドを出さない。未取得を「未達成」として描くと、
  /// 済んでいるステップが一瞬未達成に見えてちらつく。
  bool _gettingStartedLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGettingStartedState();
  }

  Future<void> _loadGettingStartedState() async {
    bool dismissed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed = prefs.getBool(_gettingStartedDismissedKey) ?? false;
    } catch (_) {
      // 端末設定の読み取りに失敗しても、ガイドが出るだけで害はない。
    }

    var hasRecord = false;
    if (!dismissed) {
      final result = await sl.get<FirebaseService>().hasAnyMaintenanceRecord();
      hasRecord = result.valueOrNull ?? false;
    }

    if (!mounted) return;
    setState(() {
      _gettingStartedDismissed = dismissed;
      _hasMaintenanceRecord = hasRecord;
      _gettingStartedLoaded = true;
    });
  }

  Future<void> _dismissGettingStarted() async {
    setState(() => _gettingStartedDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gettingStartedDismissedKey, true);
    } catch (_) {
      // 保存できなくても、この起動中は閉じたままになる。
    }
  }

  /// 整備記録の追加から戻ったら数え直す。「1件つけたのに未達成のまま」を防ぐ。
  Future<void> _refreshMaintenanceState() async {
    if (_gettingStartedDismissed || _hasMaintenanceRecord) return;
    final result = await sl.get<FirebaseService>().hasAnyMaintenanceRecord();
    if (!mounted) return;
    setState(() => _hasMaintenanceRecord = result.valueOrNull ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();

    if (vehicleProvider.isLoading) {
      return const AppLoadingCenter(message: '車両を読み込み中...');
    }

    if (vehicleProvider.error != null) {
      return AppErrorState(
        message: vehicleProvider.errorMessage ?? 'データを読み込めませんでした',
        onRetry: vehicleProvider.isRetryable
            ? () {
                vehicleProvider.clearError();
                vehicleProvider.listenToVehicles();
              }
            : null,
      );
    }

    if (vehicleProvider.vehicles.isEmpty) {
      return _VehicleEmptyOnboarding(
        onRegister: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VehicleRegistrationScreen(),
            ),
          );
        },
      );
    }

    final primaryVehicle = vehicleProvider.vehicles.first;

    return Column(
      children: [
        MileageReminderBanner(
          vehicle: primaryVehicle,
          onTapUpdate: () => MileageUpdateDialog.show(
            context,
            primaryVehicle,
            (newMileage) async {
              final updated = primaryVehicle.copyWith(
                mileage: newMileage,
                mileageUpdatedAt: DateTime.now(),
              );
              await context
                  .read<VehicleProvider>()
                  .updateVehicle(primaryVehicle.id, updated);
              // Schedule a 30-day reminder to update mileage again
              sl
                  .get<MileageNotificationService>()
                  .scheduleMonthlyReminder()
                  .catchError((_) {}); // fire-and-forget
            },
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            final vehicles = vehicleProvider.vehicles;
            final hasVehicleWithoutInspection =
                vehicles.any((v) => v.inspectionExpiryDate == null);
            final hasInspectionDate =
                vehicles.any((v) => v.inspectionExpiryDate != null);

            // 初回の3ステップ。全部済むか、閉じられたら出さない。
            final showGettingStarted = _gettingStartedLoaded &&
                !_gettingStartedDismissed &&
                !(vehicles.isNotEmpty &&
                    hasInspectionDate &&
                    _hasMaintenanceRecord);

            // Build item list: fixed cards + optional prompt + vehicle rows
            final items = <Widget>[
              if (showGettingStarted)
                GettingStartedCard(
                  hasVehicle: vehicles.isNotEmpty,
                  hasInspectionDate: hasInspectionDate,
                  hasMaintenanceRecord: _hasMaintenanceRecord,
                  onRegisterVehicle: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const VehicleRegistrationScreen(),
                    ),
                  ),
                  onSetInspectionDate: () {
                    // 満了日が空の車から。全部埋まっていれば先頭の車を開く。
                    final target = vehicles.firstWhere(
                      (v) => v.inspectionExpiryDate == null,
                      orElse: () => vehicles.first,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => VehicleEditScreen(vehicle: target),
                      ),
                    );
                  },
                  onAddMaintenance: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AddMaintenanceScreen(
                          vehicleId: vehicles.first.id,
                          currentVehicleMileage: vehicles.first.mileage,
                        ),
                      ),
                    );
                    await _refreshMaintenanceState();
                  },
                  onDismiss: _dismissGettingStarted,
                ),
              _DashboardSummaryCard(vehicles: vehicles),
              // 記録する行為と、次に買うものへの入口。開いてすぐの高さに置く。
              _QuickActionsRow(vehicle: primaryVehicle),
              // ガイドを出している間は車検の催促を重ねない。同じことを二か所で
              // 言われると、どちらも読み飛ばされる。
              if (hasVehicleWithoutInspection && !showGettingStarted)
                _InspectionSetupCard(vehicles: vehicles),
              _AiSuggestionSection(onSeeAll: widget.onNavigateToNotifications),
              ...vehicles.map((v) => _VehicleCard(vehicle: v)),
              // たびの記録とおすすめパーツを、車両カードのすぐ下に置く。
              // どちらもプロフィールの奥・車両詳細のヘッダーにあって、
              // 1年使っても辿り着かない位置だった（2026-09-08）。
              const _RecentDriveSection(),
              _RecommendedPartsSection(vehicle: primaryVehicle),
              const _RecentMaintenanceSection(),
              const _PopularAccessoriesSection(),
              const _RetiredVehiclesSection(),
            ];

            return ListView.builder(
              padding: AppSpacing.paddingScreen,
              itemCount: items.length,
              itemBuilder: (_, i) => items[i],
            );
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// プロフィールタブ
// ---------------------------------------------------------------------------

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.firebaseUser;
    final appUser = authProvider.appUser;
    final isBusiness = appUser?.isBusiness ?? false;
    final isPremium = context.watch<UserSubscriptionProvider>().isPremium;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ---- プロフィールヘッダー ----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkSurface]
                    : [AppColors.primary, AppColors.primaryHover],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: user?.photoURL != null
                      ? ClipOval(
                          child: Image.network(
                            user!.photoURL!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 44,
                          color: Colors.white,
                        ),
                ),
                AppSpacing.verticalSm,
                Text(
                  user?.displayName ?? 'ユーザー',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.verticalXxs,
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                AppSpacing.verticalSm,
                // プランバッジ
                Chip(
                  avatar: Icon(
                    isPremium ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isPremium ? 'プレミアム' : 'フリープラン',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 「みんなのアクセサリー」はここに置いていた。プロフィールの奥では
          // 見つからないので、ホームの一覧と「みんなの投稿」のヘッダーへ
          // 移した（2026-09-07）。同じ導線を二か所に置くと、どちらも
          // 覚えられない。

          AppSpacing.verticalSm,

          // ---- アカウントセクション ----
          _buildMenuSection(
            context,
            title: 'アカウント',
            items: [
              _MenuItemData(
                icon: Icons.manage_accounts_outlined,
                label: 'プロフィールを編集',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              // 「ドライブログ」はここに置いていた。「アカウント」の中では
              // 見つからないので、ホームの一覧とマイカーのヘッダーへ移した
              // （2026-09-07）。
              _MenuItemData(
                icon: Icons.compare_arrows_outlined,
                label: '整備工場を比較する',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ShopListScreen(compareMode: true),
                  ),
                ),
              ),
              if (isBusiness)
                _MenuItemData(
                  icon: Icons.business_center_outlined,
                  label: 'フリート管理',
                  color: AppColors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FleetDashboardScreen(
                        companyId: user?.uid ?? '',
                      ),
                    ),
                  ),
                ),
              _MenuItemData(
                icon: Icons.settings_outlined,
                label: '設定',
                color: AppColors.textSecondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),

          AppSpacing.verticalSm,

          // ---- データセクション ----
          _buildMenuSection(
            context,
            title: 'データ',
            items: [
              _MenuItemData(
                icon: Icons.download_outlined,
                // profile_screen と同じ理由で「（プレミアム）」を外す
                // （390px 幅で2行に折り返す）。
                label: 'データをエクスポート',
                color: AppColors.primary,
                onTap: isPremium
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        )
                    : () => _showUpgradeDialog(context),
              ),
            ],
          ),

          AppSpacing.verticalSm,

          // ---- サポートセクション ----
          _buildMenuSection(
            context,
            title: 'サポート・法的情報',
            items: [
              // ここが利用者の見るサポート欄。ヘルプもフィードバックも
              // ProfileScreen 側にしか無く、そこへは「プロフィールを編集」
              // からしか行けなかったため、実質たどり着けなかった。
              // 店から渡されたコードを入れる場所。
              // docs/BUSINESS_MODEL_RETHINK_2026-08-27.md §4 — 既存客が
              // 自分でアプリを探して自分で店を見つける導線しか無かった。
              _MenuItemData(
                icon: Icons.store_outlined,
                label: 'お店のコードを入れる',
                color: AppColors.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShopInviteScreen(
                      service: sl.get<ShopInviteService>(),
                      userId: user?.uid ?? '',
                      vehicles: context.read<VehicleProvider>().vehicles,
                    ),
                  ),
                ),
              ),
              _MenuItemData(
                icon: Icons.help_outline,
                label: 'ヘルプ',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => HelpScreen(userId: user?.uid),
                  ),
                ),
              ),
              _MenuItemData(
                icon: Icons.rate_review_outlined,
                label: 'ご意見・不具合の報告',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FeedbackScreen(
                      service: sl.get<FeedbackService>(),
                      userId: user?.uid ?? '',
                      fromScreen: 'profile',
                    ),
                  ),
                ),
              ),
              _MenuItemData(
                icon: Icons.health_and_safety_outlined,
                label: '安全運転情報',
                color: AppColors.success,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SafetyTipScreen(),
                  ),
                ),
              ),
              _MenuItemData(
                icon: Icons.privacy_tip_outlined,
                label: 'プライバシーポリシー',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              _MenuItemData(
                icon: Icons.article_outlined,
                label: '利用規約',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TermsOfServiceScreen()),
                ),
              ),
            ],
          ),

          AppSpacing.verticalSm,

          // ---- ログアウト ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: AppSpacing.iconMd,
                  ),
                ),
                title: const Text(
                  'ログアウト',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => _confirmSignOut(context),
              ),
            ),
          ),

          AppSpacing.verticalSm,

          // ---- バージョン ----
          // 「直したはずの不具合が直っていない」と言われたとき、その人が
          // どのビルドを触っているかが分からないと確かめようがない。
          // テスト配布中は 1.0.0 のまま何度も出し直すので、ビルド識別子まで
          // 画面から読めるようにしておく（フィードバックにも同じ値が載る）。
          Padding(
            key: const Key('app_version_label'),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'バージョン ${AppInfo.fullVersion} / ${AppInfo.platform}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),

          AppSpacing.verticalXxl,
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItemData> items,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: AppSpacing.iconMd,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        size: AppSpacing.iconMd,
                      ),
                      onTap: item.onTap,
                    ),
                    if (i < items.length - 1)
                      const Divider(height: 1, indent: 56),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    final subscriptionProvider = context.read<UserSubscriptionProvider>();
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('プレミアムプランが必要です'),
        content: Text(premiumUpsellMessage('データのエクスポート')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
          // 凍結中は買えないので、ボタンごと出さない。
          if (canPurchasePremium)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (uid.isEmpty) return;
                final result =
                    await subscriptionProvider.purchasePremium(userId: uid);
                if (context.mounted) {
                  result.when(
                    success: (_) => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('プレミアムプランへの登録が完了しました'),
                          backgroundColor: Colors.green),
                    ),
                    failure: (err) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err.userMessage)),
                    ),
                  );
                }
              },
              child: const Text('プレミアムに登録する'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vehicleProvider = context.read<VehicleProvider>();
      final maintenanceProvider = context.read<MaintenanceProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      final authProvider = context.read<AuthProvider>();

      vehicleProvider.clear();
      maintenanceProvider.clear();
      notificationProvider.clear();
      await authProvider.signOut();
      if (!context.mounted) return;
    }
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleCard({required this.vehicle});

  String _formatMileage(int mileage) {
    final formatter = NumberFormat('#,###');
    return formatter.format(mileage);
  }

  Color _statusAccentColor() {
    if (vehicle.isInspectionExpired ||
        (vehicle.daysUntilInsuranceExpiry != null &&
            vehicle.daysUntilInsuranceExpiry! < 0)) {
      return AppColors.error;
    }
    if (vehicle.isInspectionDueSoon || vehicle.isInsuranceDueSoon) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasInspectionWarning =
        vehicle.isInspectionExpired || vehicle.isInspectionDueSoon;
    final hasInsuranceWarning = vehicle.isInsuranceDueSoon ||
        (vehicle.daysUntilInsuranceExpiry != null &&
            vehicle.daysUntilInsuranceExpiry! < 0);

    final suggestionCount = context
        .watch<NotificationProvider>()
        .getNotificationsForVehicle(vehicle.id)
        .where((n) =>
            n.type != NotificationType.system &&
            (n.priority == NotificationPriority.high ||
                n.priority == NotificationPriority.medium))
        .length;

    final accentColor = _statusAccentColor();

    return Card(
      margin: AppSpacing.marginListItem,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Provider.of<VehicleProvider>(context, listen: false)
              .selectVehicle(vehicle);
          Provider.of<MaintenanceProvider>(context, listen: false)
              .listenToMaintenanceRecords(vehicle.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleDetailScreen(vehicle: vehicle),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status accent bar (green=ok / orange=warning / red=expired)
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: AppSpacing.paddingCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 車両画像
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.backgroundLight,
                              borderRadius: AppSpacing.borderRadiusSm,
                            ),
                            child: vehicle.imageUrl != null &&
                                    vehicle.imageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: AppSpacing.borderRadiusSm,
                                    child: Image.network(
                                      vehicle.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildPlaceholder(isDark),
                                    ),
                                  )
                                : _buildPlaceholder(isDark),
                          ),
                          AppSpacing.horizontalMd,
                          // 車両情報
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 複数台を持つ人は一覧をメーカーで見分ける。
                                // `Vehicle` は makerId を持たないので名前から引く。
                                Row(
                                  children: [
                                    MakerBadge.fromName(vehicle.maker,
                                        size: 18),
                                    AppSpacing.horizontalXs,
                                    Expanded(
                                      child: Text(
                                        '${vehicle.maker} ${vehicle.model}',
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                AppSpacing.verticalXxs,
                                Text(
                                  '${vehicle.year}年式 ${vehicle.grade}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                AppSpacing.verticalXxs,
                                // 走行距離 + 燃料タイプ
                                Row(
                                  children: [
                                    Icon(
                                      Icons.speed,
                                      size: AppSpacing.iconSm,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.textTertiary,
                                    ),
                                    AppSpacing.horizontalXs,
                                    Text(
                                      '${_formatMileage(vehicle.mileage)} km',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (vehicle.fuelType != null) ...[
                                      AppSpacing.horizontalSm,
                                      _InfoChip(
                                        label: vehicle.fuelType!.displayName,
                                        color: AppColors.secondary,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ],
                                ),
                                AppSpacing.verticalXxs,
                                // ナンバープレート + 車検残日数
                                Row(
                                  children: [
                                    if (vehicle.licensePlate != null &&
                                        vehicle.licensePlate!.isNotEmpty) ...[
                                      Icon(
                                        Icons.credit_card_outlined,
                                        size: 13,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.textTertiary,
                                      ),
                                      AppSpacing.horizontalXs,
                                      Flexible(
                                        child: Text(
                                          vehicle.licensePlate!,
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      AppSpacing.horizontalSm,
                                    ],
                                    if (vehicle.daysUntilInspection != null &&
                                        !vehicle.isInspectionExpired) ...[
                                      Icon(
                                        Icons.verified_outlined,
                                        size: 13,
                                        color: vehicle.isInspectionDueSoon
                                            ? AppColors.warning
                                            : (isDark
                                                ? AppColors.darkTextTertiary
                                                : AppColors.textTertiary),
                                      ),
                                      AppSpacing.horizontalXs,
                                      Text(
                                        '車検 残${vehicle.daysUntilInspection}日',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: vehicle.isInspectionDueSoon
                                              ? AppColors.warning
                                              : null,
                                          fontWeight:
                                              vehicle.isInspectionDueSoon
                                                  ? FontWeight.w600
                                                  : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // 任意保険 満期警告（満期間近・期限切れ時のみ）
                                if (vehicle.voluntaryInsurance != null &&
                                    (vehicle.voluntaryInsurance!
                                            .isExpiringSoon ||
                                        vehicle.voluntaryInsurance!
                                            .isExpired)) ...[
                                  AppSpacing.verticalXxs,
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.security,
                                        size: 13,
                                        color: vehicle
                                                .voluntaryInsurance!.isExpired
                                            ? AppColors.error
                                            : AppColors.warning,
                                      ),
                                      AppSpacing.horizontalXs,
                                      Text(
                                        vehicle.voluntaryInsurance!.isExpired
                                            ? '任意保険 期限切れ'
                                            : '任意保険 満期間近',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: vehicle
                                                  .voluntaryInsurance!.isExpired
                                              ? AppColors.error
                                              : AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 提案バッジ + シェブロン
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.chevron_right,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                              if (suggestionCount > 0) ...[
                                AppSpacing.verticalXxs,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.12),
                                    borderRadius: AppSpacing.borderRadiusXs,
                                    border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    '提案 $suggestionCount件',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      // 車検・保険警告バナー
                      if (hasInspectionWarning || hasInsuranceWarning) ...[
                        AppSpacing.verticalSm,
                        _buildWarningBanner(context, theme),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context, ThemeData theme) {
    final warnings = <Widget>[];

    if (vehicle.isInspectionExpired) {
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.error,
        label: '車検切れ',
        color: AppColors.error,
      ));
    } else if (vehicle.isInspectionDueSoon) {
      final days = vehicle.daysUntilInspection!;
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.warning_amber,
        label: '車検 残り$days日',
        color: days <= 7 ? AppColors.error : AppColors.warning,
      ));
    }

    final insuranceDays = vehicle.daysUntilInsuranceExpiry;
    if (insuranceDays != null && insuranceDays < 0) {
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.error,
        label: '自賠責切れ',
        color: AppColors.error,
      ));
    } else if (vehicle.isInsuranceDueSoon) {
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.shield,
        label: '保険 残り$insuranceDays日',
        color: insuranceDays! <= 7 ? AppColors.error : AppColors.warning,
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: warnings,
    );
  }

  Widget _buildWarningChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusXs,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          AppSpacing.horizontalXxs,
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.directions_car,
        size: AppSpacing.iconLg,
        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 車両未登録時オンボーディングガイド
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// 車検日未設定プロンプトカード
// Shown when one or more vehicles have no inspectionExpiryDate.
// ---------------------------------------------------------------------------

class _InspectionSetupCard extends StatelessWidget {
  final List<Vehicle> vehicles;

  const _InspectionSetupCard({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Find the first vehicle without an inspection date as the action target
    final target = vehicles.firstWhere((v) => v.inspectionExpiryDate == null);

    return Container(
      key: const Key('inspection_setup_card'),
      margin: AppSpacing.marginListItem,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: AppColors.warning,
            size: AppSpacing.iconMd,
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '車検満了日を登録しよう',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.verticalXxs,
                Text(
                  '車検期限を登録すると、満了前に通知でお知らせします。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalSm,
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleEditScreen(vehicle: target),
                ),
              );
            },
            child: const Text('登録する'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _VehicleEmptyOnboarding extends StatelessWidget {
  final VoidCallback onRegister;

  const _VehicleEmptyOnboarding({required this.onRegister});

  static const _features = [
    (
      icon: Icons.history,
      title: '整備履歴を正確に記録',
      description: '修理・点検・消耗品交換を時系列で管理できます',
      color: AppColors.primary,
    ),
    (
      icon: Icons.notifications_active,
      title: 'AIが次の点検をお知らせ',
      description: '走行距離と履歴から最適なタイミングを自動分析',
      color: AppColors.info,
    ),
    (
      icon: Icons.handshake,
      title: '信頼できる整備工場と繋がる',
      description: 'AI提案から評価の高い工場へ簡単にアクセス',
      color: AppColors.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        children: [
          AppSpacing.verticalXl,
          // Hero icon — decorative, excluded from semantics tree
          ExcludeSemantics(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car,
                size: 52,
                color: AppColors.primary,
              ),
            ),
          ),
          AppSpacing.verticalMd,
          Semantics(
            header: true,
            child: Text(
              'まず愛車を登録しよう',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          AppSpacing.verticalSm,
          Text(
            '登録するだけで、AIがあなたの愛車に\n合ったお役立ち情報をお知らせします',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalXl,
          // Feature list
          ...(_features.map((f) => _FeatureRow(
                icon: f.icon,
                title: f.title,
                description: f.description,
                accentColor: f.color,
              ))),
          AppSpacing.verticalXl,
          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.add),
              label: const Text('車両を登録する'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                textStyle: buttonTextStyle(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feature icon — decorative; text title/description carry the meaning
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Icon(icon, size: 22, color: accentColor),
            ),
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.5,
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
// AIからの提案セクション（ホーム画面トップ）
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// ダッシュボードサマリーカード（マイカータブ最上部）
// ---------------------------------------------------------------------------

class _DashboardSummaryCard extends StatelessWidget {
  final List<Vehicle> vehicles;

  const _DashboardSummaryCard({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 警告のある車両を集計
    final expiredCount = vehicles
        .where((v) =>
            v.isInspectionExpired ||
            (v.daysUntilInsuranceExpiry != null &&
                v.daysUntilInsuranceExpiry! < 0))
        .length;
    final warnCount = vehicles
        .where((v) =>
            (v.isInspectionDueSoon && !v.isInspectionExpired) ||
            (v.isInsuranceDueSoon &&
                v.daysUntilInsuranceExpiry != null &&
                v.daysUntilInsuranceExpiry! >= 0))
        .length;

    // 最も近い車検日を持つ車両
    Vehicle? nextInspectionVehicle;
    int? minDays;
    for (final v in vehicles) {
      if (v.daysUntilInspection != null && v.daysUntilInspection! > 0) {
        if (minDays == null || v.daysUntilInspection! < minDays) {
          minDays = v.daysUntilInspection;
          nextInspectionVehicle = v;
        }
      }
    }

    return Container(
      margin: AppSpacing.marginListItem,
      // 画面上部を占有しすぎていたため縮小。数字の可読性は保ちつつ、
      // 余白・アイコン・区切り線の高さを詰めている。
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkCard, AppColors.darkSurface]
              : [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: AppSpacing.borderRadiusMd,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- タイトル ----
          Row(
            children: [
              const Icon(Icons.dashboard_outlined,
                  size: AppSpacing.iconSm, color: Colors.white),
              AppSpacing.horizontalXs,
              Text(
                'ダッシュボード',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          AppSpacing.verticalXxs,

          // ---- 統計行 ----
          Row(
            children: [
              _buildStatItem(
                context,
                icon: Icons.directions_car,
                value: '${vehicles.length}',
                label: '登録車両',
                iconColor: Colors.white,
              ),
              _buildDivider(),
              _buildStatItem(
                context,
                icon: Icons.error_outline,
                value: '$expiredCount',
                label: '要対応',
                iconColor: expiredCount > 0
                    ? AppColors.error.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.85),
              ),
              _buildDivider(),
              _buildStatItem(
                context,
                icon: Icons.warning_amber_outlined,
                value: '$warnCount',
                label: '注意',
                iconColor: warnCount > 0
                    ? AppColors.warning
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),

          // ---- 次回車検 ----
          if (nextInspectionVehicle != null)
            _buildInspectionChip(nextInspectionVehicle, minDays!),

          // ---- フリートプラン案内（5台以上で表示・現在は無料開放中） ----
          if (FleetPlan.requiresPaidPlan(vehicles.length))
            _buildFleetPlanBanner(context, vehicles.length),
        ],
      ),
    );
  }

  /// SMB fleet upsell: shown from the 5th vehicle. During the promotional
  /// free period it only sets pricing expectations (no payment action).
  ///
  /// Tappable: business accounts jump straight to the fleet dashboard (improves
  /// discoverability — previously only reachable deep in the profile tab);
  /// personal accounts get a hint to register a business account.
  Widget _buildFleetPlanBanner(BuildContext context, int vehicleCount) {
    final price = FleetPlan.monthlyPriceFor(vehicleCount);
    final priceLabel =
        price != null ? '月額¥${NumberFormat('#,###').format(price)}' : '個別見積もり';
    final auth = context.read<AuthProvider>();
    final isBusiness = auth.appUser?.isBusiness ?? false;
    final uid = auth.firebaseUser?.uid ?? '';

    void onTap() {
      if (isBusiness) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FleetDashboardScreen(companyId: uid),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィール →「法人アカウント登録」でフリート管理を利用できます'),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.verticalSm,
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('fleet_plan_banner_action'),
            onTap: onTap,
            borderRadius: AppSpacing.borderRadiusSm,
            child: Container(
              key: const Key('fleet_plan_banner'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppSpacing.borderRadiusSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 14, color: Colors.white),
                  AppSpacing.horizontalXs,
                  Expanded(
                    child: Text(
                      FleetPlan.isPromotionalFreePeriod
                          ? '$vehicleCount台を管理中 — 法人向け'
                              '${FleetPlan.planLabelFor(vehicleCount)}プラン対象'
                              '（現在無料開放中・正式リリース後 $priceLabel 予定）'
                          : '$vehicleCount台を管理中 — '
                              '${FleetPlan.planLabelFor(vehicleCount)}プラン'
                              '（$priceLabel）',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                  AppSpacing.horizontalXs,
                  Text(
                    isBusiness ? 'フリート管理' : '法人登録で利用',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 16, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Inspection-deadline chip with urgency-based emphasis so the core
  /// promise (車検を見落とさない) is visible at a glance.
  Widget _buildInspectionChip(Vehicle vehicle, int days) {
    final urgency = inspectionUrgencyForDays(days);

    final Color background;
    final Color iconColor;
    final IconData icon;
    final FontWeight fontWeight;
    final String keySuffix;
    switch (urgency) {
      case InspectionUrgency.critical:
        background = AppColors.error.withValues(alpha: 0.45);
        iconColor = Colors.white;
        icon = Icons.error_outline;
        fontWeight = FontWeight.bold;
        keySuffix = 'critical';
      case InspectionUrgency.warning:
        background = AppColors.warning.withValues(alpha: 0.35);
        iconColor = Colors.white;
        icon = Icons.warning_amber_outlined;
        fontWeight = FontWeight.bold;
        keySuffix = 'warning';
      case InspectionUrgency.normal:
      case InspectionUrgency.none:
        background = Colors.white.withValues(alpha: 0.12);
        iconColor = Colors.white;
        icon = Icons.verified_outlined;
        fontWeight = FontWeight.normal;
        keySuffix = 'normal';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.verticalSm,
        Container(
          key: Key('dashboard_inspection_chip_$keySuffix'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              AppSpacing.horizontalXs,
              Text(
                '次の車検: '
                '${vehicle.maker} '
                '${vehicle.model} '
                '— あと$days日',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ),
        // 残量バー。**「あと19日」は数字を読まないと分からないが、
        // バーは目を向けただけで分かる。** 車検は2年（730日）周期なので、
        // 残り日数をその割合で描く。
        if (days >= 0) ...[
          AppSpacing.verticalXs,
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: Key('dashboard_inspection_meter_$keySuffix'),
              value: (days / 730).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // アイコンは数字の左に置き、1行分の高さを削る。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              AppSpacing.horizontalXxs,
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

// ---------------------------------------------------------------------------

class _AiSuggestionSection extends StatelessWidget {
  final VoidCallback onSeeAll;

  const _AiSuggestionSection({required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final suggestions = notificationProvider.topSuggestions;

        // 提案がなければセクション自体を非表示
        if (suggestions.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- ヘッダー ----
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
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
                        AppSpacing.horizontalXs,
                        Text(
                          'AIからの提案',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'すべて見る',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- 横スクロールカード ----
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => AppSpacing.horizontalSm,
                itemBuilder: (context, index) {
                  final n = suggestions[index];
                  return _SuggestionCard(
                    notification: n,
                    isDark: isDark,
                    onTap: n.vehicleId != null
                        ? () {
                            final vehicles =
                                context.read<VehicleProvider>().vehicles;
                            final vehicle =
                                vehicles.cast<Vehicle?>().firstWhere(
                                      (v) => v?.id == n.vehicleId,
                                      orElse: () => null,
                                    );
                            if (vehicle == null || !context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddMaintenanceScreen(
                                  vehicleId: vehicle.id,
                                  currentVehicleMileage: vehicle.mileage,
                                ),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            ),

            AppSpacing.verticalMd,
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 個別の提案カード
// ---------------------------------------------------------------------------

class _SuggestionCard extends StatefulWidget {
  final AppNotification notification;
  final bool isDark;
  final VoidCallback? onTap;

  const _SuggestionCard({
    required this.notification,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  Color get _priorityColor {
    switch (widget.notification.priority) {
      case NotificationPriority.high:
        return AppColors.error;
      case NotificationPriority.medium:
        return AppColors.warning;
      case NotificationPriority.low:
        return AppColors.info;
    }
  }

  IconData get _typeIcon {
    switch (widget.notification.type) {
      case NotificationType.inspectionReminder:
        return Icons.verified_outlined;
      case NotificationType.partsReplacement:
        return Icons.build_outlined;
      case NotificationType.maintenanceRecommendation:
        return Icons.directions_car_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  void _openDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SuggestionDetailSheet(
        notification: widget.notification,
        isDark: widget.isDark,
        onAddRecord: widget.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor;
    final n = widget.notification;

    return GestureDetector(
      onTap: () => _openDetailSheet(context),
      child: SizedBox(
        width: 210,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
            side: BorderSide(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored top accent strip
              Container(height: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- アイコン + 優先度バッジ ----
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(_typeIcon, size: 15, color: color),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              n.priority == NotificationPriority.high
                                  ? '要対応'
                                  : '推奨',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalXs,
                      // ---- タイトル ----
                      Text(
                        n.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalXxs,
                      // ---- メッセージ ----
                      Expanded(
                        child: Text(
                          n.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ---- 「理由を見る」ヒント ----
                      AppSpacing.verticalXxs,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'タップで詳細',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 13, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 提案詳細ボトムシート（理由全文 + アクション選択）
// ---------------------------------------------------------------------------

class _SuggestionDetailSheet extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final VoidCallback? onAddRecord;

  const _SuggestionDetailSheet({
    required this.notification,
    required this.isDark,
    this.onAddRecord,
  });

  Color _priorityColor(BuildContext context) {
    switch (notification.priority) {
      case NotificationPriority.high:
        return AppColors.error;
      case NotificationPriority.medium:
        return AppColors.warning;
      case NotificationPriority.low:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor(context);
    final n = notification;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ListView(
          controller: scrollController,
          children: [
            // ---- ドラッグハンドル ----
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ---- 優先度バッジ + タイトル ----
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    n.priority == NotificationPriority.high ? '要対応' : '推奨',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              n.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ---- 理由セクション ----
            if (n.reason != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 15, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'なぜ今なのか',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      n.reason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.7,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else ...[
              Text(
                n.message,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ---- 注意文 ----
            // 「あなたが決めるための情報を整理しました。最終的な判断はあなた自身で
            // お決めください」から変更。判断を委ねる意図だったが、こちらが情報を
            // 与えて相手に決めさせる構図になっており、上から目線に読める。
            // 主語をサービス側に置き、「参考情報である」という事実だけを伝える。
            // AIの出力に添える注記は AiDisclaimer に一本化する。
            // 画面ごとに書き分けると必ず抜けと表記ゆれが出る。
            const AiDisclaimer(subject: 'この提案'),

            const SizedBox(height: AppSpacing.lg),

            // ---- アクション: 整備記録を追加 ----
            if (onAddRecord != null)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAddRecord!();
                },
                icon: const Icon(Icons.add),
                label: const Text('整備記録を追加する'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // ---- アクション: 整備工場を探す ----
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopListScreen(
                      maintenanceContext:
                          n.metadata?['ruleName'] as String? ?? n.title,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.store_outlined),
              label: const Text('近くの整備工場を探す'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// プロフィールメニュー項目データクラス
// ---------------------------------------------------------------------------

class _MenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// 小型インフォチップ（車両カード内）
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 過去の車両リンク（退役済み車両への導線）
// ---------------------------------------------------------------------------
/// ホームの「過去の車両」。
///
/// **一覧から消すと「記録ごと無くなった」と感じる。** 売却・リース返却済みの
/// 車も薄く残し、いつ手放したかを添える。過去の車にかけた整備費も、生涯
/// コストとしては意味がある。
///
/// 2026-09-07 まではテキストリンクだけで、車そのものは奥の画面まで行かないと
/// 見えなかった。
class _RetiredVehiclesSection extends StatefulWidget {
  const _RetiredVehiclesSection();

  @override
  State<_RetiredVehiclesSection> createState() =>
      _RetiredVehiclesSectionState();
}

class _RetiredVehiclesSectionState extends State<_RetiredVehiclesSection> {
  List<Vehicle>? _vehicles;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().appUser?.id ?? '';
    if (uid.isEmpty) return;
    final result =
        await sl.get<VehicleRetirementService>().getRetiredVehicles(uid);
    if (!mounted) return;
    result.when(
      // **返ってきたリストをその場で並べ替えない。** 呼び出し先が変更できない
      // リスト（const [] など）を返すと落ちる。写しを作ってから並べ替える。
      success: (vehicles) => setState(() {
        _vehicles = [...vehicles]..sort((a, b) =>
            (b.retiredAt ?? DateTime(0)).compareTo(a.retiredAt ?? DateTime(0)));
      }),
      failure: (_) => setState(() => _vehicles = const []),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _vehicles;
    if (vehicles == null || vehicles.isEmpty) return const SizedBox.shrink();

    final shown = vehicles.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.history_outlined,
          title: '過去の車両',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const RetiredVehiclesScreen(),
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _RetiredVehicleRow(vehicle: shown[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RetiredVehicleRow extends StatelessWidget {
  final Vehicle vehicle;

  const _RetiredVehicleRow({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy年M月');
    final retiredAt = vehicle.retiredAt;

    // 現役の車と同じ濃さで出すと、どれが今の愛車か分からなくなる。
    return Opacity(
      opacity: 0.65,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.directions_car_outlined,
                size: 18, color: AppColors.textTertiary),
            AppSpacing.horizontalSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.maker} ${vehicle.model}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalXxs,
                  Text(
                    retiredAt == null
                        ? vehicle.status.displayName
                        : '${vehicle.status.displayName} ・ ${dateFormat.format(retiredAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ホームに出す「最近のメンテナンス」と「最近のドライブ」
//
// どちらもメニューの奥にあって見つけにくかった（ドライブログは「アカウント」
// セクションの中）。**開いてすぐ、クルマの情報・メンテナンスの記録・たびの
// 記録が並んで見える**のが望ましい、という判断で 2026-09-07 にホームへ出した。
// ---------------------------------------------------------------------------

/// 見出しと「すべて見る」を揃えるための共通の帯。
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          AppSpacing.horizontalXs,
          Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
            child: const Text('すべて見る'),
          ),
        ],
      ),
    );
  }
}

/// セクションの合計を1行で出す帯。
///
/// **1件ずつ見なくても分かる数字**を、リストの前に置く。
class _SectionSummary extends StatelessWidget {
  /// (ラベル, 値)。値が空なら、ラベルだけを薄く出す。
  final List<(String, String)> items;

  const _SectionSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          for (final (label, value) in items) ...[
            if (value.isEmpty)
              Text(label, style: theme.textTheme.bodySmall)
            else ...[
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.bodySmall,
              ),
              AppSpacing.horizontalXs,
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// ホームの「メンテナンスの記録」。
///
/// **車検・点検だけでなく、オイル交換もカスタムパーツも同じ並びで出す。**
/// 種類で分けずに時系列で見せたほうが、そのクルマに何をしてきたかが分かる。
/// 金額を右に出すのは、積み上がった費用がそのまま維持費の実感になるため。
class _RecentMaintenanceSection extends StatefulWidget {
  const _RecentMaintenanceSection();

  @override
  State<_RecentMaintenanceSection> createState() =>
      _RecentMaintenanceSectionState();
}

class _RecentMaintenanceSectionState extends State<_RecentMaintenanceSection> {
  List<MaintenanceRecord>? _records;

  /// この1年の件数と金額。直近3件の合計では、かけた額が分からない。
  MaintenanceSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = sl.get<FirebaseService>();
    final result = await service.getRecentMaintenanceRecords(limit: 3);
    if (!mounted) return;
    result.when(
      success: (records) => setState(() => _records = records),
      failure: (_) => setState(() => _records = const []),
    );

    final summary = await service.maintenanceSummary(
      since: DateTime.now().subtract(const Duration(days: 365)),
    );
    if (!mounted) return;
    // 集計が取れなくても一覧は出す。数字が出ないだけ。
    setState(() => _summary = summary.valueOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    // 読み込み中とゼロ件は、どちらも何も出さない。ホームの一等地に
    // 「ありません」を置いても、できることが増えるわけではない。
    if (records == null || records.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.build_outlined,
          title: 'メンテナンスの記録',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const MaintenanceSearchScreen(),
            ),
          ),
        ),
        // 直近の3件だけだと「1年でいくら使ったか」が見えない。**積み上がった
        // 額が維持費の実感になる**ので、集計を先に出す。集計が取れないあいだは
        // 直近3件ぶんを出すが、そのときは「合計」とは書かない。
        _SectionSummary(
          items: _summary == null
              ? [
                  ('直近${records.length}件', ''),
                  (
                    '小計',
                    '¥${NumberFormat('#,###').format(records.fold<int>(0, (s, r) => s + r.cost))}'
                  ),
                ]
              : [
                  ('この1年で${_summary!.count}件', ''),
                  (
                    '合計',
                    '¥${NumberFormat('#,###').format(_summary!.totalCost)}'
                  ),
                ],
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < records.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _MaintenanceRow(record: records[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  final MaintenanceRecord record;

  const _MaintenanceRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd');
    final costFormat = NumberFormat('#,###');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(record.typeIcon, size: 18, color: record.typeColor),
          AppSpacing.horizontalSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.verticalXxs,
                Text(
                  dateFormat.format(record.date),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppSpacing.horizontalSm,
          Text(
            '¥${costFormat.format(record.cost)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// ホームの「たびの記録」。
///
/// ドライブログは「アカウント」セクションの奥にあり、**記録したことを
/// 忘れられる位置**だった。距離と時間を添えて出す。
class _RecentDriveSection extends StatefulWidget {
  const _RecentDriveSection();

  @override
  State<_RecentDriveSection> createState() => _RecentDriveSectionState();
}

class _RecentDriveSectionState extends State<_RecentDriveSection> {
  /// この1年の回数と距離。一覧を読まずに集計だけを取る。
  DriveLogSummary? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().appUser?.id;
      if (uid == null || uid.isEmpty) return;
      context.read<DriveLogProvider>().loadUserDriveLogs(uid);
      _loadSummary(uid);
    });
  }

  Future<void> _loadSummary(String uid) async {
    final result = await sl.get<DriveLogService>().summaryForUser(
          userId: uid,
          since: DateTime.now().subtract(const Duration(days: 365)),
        );
    if (!mounted) return;
    // 失敗しても一覧は出す。数字が出ないだけで、記録は読める。
    setState(() => _summary = result.valueOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<DriveLogProvider>().logs;
    if (logs.isEmpty) return const SizedBox.shrink();

    final recent = logs.take(2).toList();

    // 集計が返るまでは、読み込んだ分だけで出す。**「合計」とは書かない。**
    // 1年で200回近く走る人がいるので、1ページ分（20件）の合計を「合計」と
    // 呼ぶと、実際の1/10の距離が出る（2026-09-08 に実データで確認）。
    final summary = _summary;
    final kmFormat = NumberFormat('#,###');
    final items = summary == null
        ? <(String, String)>[
            ('直近${logs.length}回', ''),
            (
              '距離',
              '${kmFormat.format(logs.fold<double>(0, (s, l) => s + l.statistics.totalDistance).round())} km'
            ),
          ]
        : <(String, String)>[
            ('この1年で${summary.count}回', ''),
            ('合計', '${kmFormat.format(summary.totalDistanceKm.round())} km'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.route_outlined,
          title: 'たびの記録',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const DriveLogScreen()),
          ),
        ),
        _SectionSummary(items: items),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _DriveRow(log: recent[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DriveRow extends StatelessWidget {
  final DriveLog log;

  const _DriveRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DriveLogDetailScreen(driveLog: log),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.navigation_outlined,
                size: 18, color: AppColors.secondary),
            AppSpacing.horizontalSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.displayTitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalXxs,
                  Text(
                    dateFormat.format(log.startTime),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            AppSpacing.horizontalSm,
            Text(
              '${log.statistics.totalDistance.toStringAsFixed(1)} km',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ホームの「みんなのアクセサリー」。
///
/// **他の人が何を付けているかは、カタログより参考になる。** 品名・ブランド・
/// 平均価格・何人が使っているかを並べる。プロフィールの奥にあった導線を、
/// メンテナンスやドライブと同じ高さに引き上げた（2026-09-07）。
class _PopularAccessoriesSection extends StatefulWidget {
  const _PopularAccessoriesSection();

  @override
  State<_PopularAccessoriesSection> createState() =>
      _PopularAccessoriesSectionState();
}

class _PopularAccessoriesSectionState
    extends State<_PopularAccessoriesSection> {
  List<AccessoryTrend>? _trends;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await sl.get<PopularAccessoriesService>().getTopAccessories(limit: 3);
    if (!mounted) return;
    result.when(
      success: (trends) => setState(() => _trends = trends),
      failure: (_) => setState(() => _trends = const []),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trends = _trends;
    if (trends == null || trends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.auto_awesome_outlined,
          title: 'みんなのアクセサリー',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AccessoryShowcaseScreen(),
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < trends.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _AccessoryRow(trend: trends[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccessoryRow extends StatelessWidget {
  final AccessoryTrend trend;

  const _AccessoryRow({required this.trend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceFormat = NumberFormat('#,###');
    final price = trend.averagePriceApprox;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, size: 18, color: AppColors.warning),
          AppSpacing.horizontalSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.itemName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.verticalXxs,
                Text(
                  // ブランドが無い投稿もあるので、その分は詰める。
                  [
                    if (trend.brand != null && trend.brand!.isNotEmpty)
                      trend.brand!,
                    '${trend.showcaseCount}人が使用',
                    '★${trend.averageRating.toStringAsFixed(1)}',
                  ].join(' ・ '),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (price != null) ...[
            AppSpacing.horizontalSm,
            Text(
              '¥${priceFormat.format(price)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ホームのいちばん上に置く4つの入口。
///
/// **記録する行為と、次に買うものへの入口を、開いてすぐの場所に置く。**
/// これまでは、たびの記録はプロフィールの奥、給油は車両詳細を開いて
/// スクロールした先、パーツ提案は車両詳細のヘッダーのアイコン、と
/// バラバラだった。どれも「毎月やること」なのに、毎月たどり着けない。
///
/// 車が1台も無いときは出さない（記録する対象が無い）。
class _QuickActionsRow extends StatelessWidget {
  /// ふだん乗っている1台。給油・整備・パーツはこの車に対して開く。
  final Vehicle vehicle;

  const _QuickActionsRow({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: _QuickAction(
                actionKey: const Key('quick_action_drive'),
                icon: Icons.route_outlined,
                label: 'たびの記録',
                color: AppColors.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DriveLogScreen(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _QuickAction(
                actionKey: const Key('quick_action_parts'),
                icon: Icons.build_circle_outlined,
                // 見出しの「おすすめパーツ」と同じ文字にしない。同じ言葉が
                // 画面に2つあると、どちらを押したのか分からなくなる。
                label: 'パーツを探す',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PartRecommendationScreen(vehicle: vehicle),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _QuickAction(
                actionKey: const Key('quick_action_fuel'),
                icon: Icons.local_gas_station_outlined,
                label: '給油を記録',
                color: AppColors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AddFuelScreen(
                      service: sl.get<FuelService>(),
                      vehicleId: vehicle.id,
                      userId: vehicle.userId,
                      lastOdometer: vehicle.mileage,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _QuickAction(
                actionKey: const Key('quick_action_maintenance'),
                icon: Icons.build_outlined,
                label: '整備を記録',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AddMaintenanceScreen(
                      vehicleId: vehicle.id,
                      currentVehicleMileage: vehicle.mileage,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final Key actionKey;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: actionKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            AppSpacing.verticalXxs,
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// ホームの「おすすめパーツ」。
///
/// パーツ提案は**車両詳細のヘッダーにあるアイコン1つ**からしか開けなかった。
/// 車を選んで、詳細を開いて、右上のアイコンに気づいて、はじめて届く位置に
/// ある。1年使ってもそこに辿り着かない人がいる、という前提で、ホームの
/// 「メンテナンスの記録」と同じ高さに出す（2026-09-08）。
///
/// **適合するものだけを出す。** 付かない部品を並べても、選ぶ手間が増える
/// だけで買い物にならない。適合の度合いは行ごとにラベルで見せる。
class _RecommendedPartsSection extends StatefulWidget {
  /// どの車に合わせて出すか。ふだん乗っている1台。
  final Vehicle vehicle;

  const _RecommendedPartsSection({required this.vehicle});

  @override
  State<_RecommendedPartsSection> createState() =>
      _RecommendedPartsSectionState();
}

class _RecommendedPartsSectionState extends State<_RecommendedPartsSection> {
  List<PartRecommendation>? _recommendations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RecommendedPartsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 車を乗り換えたら取り直す。前の車のパーツが残っていては意味がない。
    if (oldWidget.vehicle.id != widget.vehicle.id) {
      setState(() => _recommendations = null);
      _load();
    }
  }

  Future<void> _load() async {
    final result = await sl
        .get<PartRecommendationService>()
        .getRecommendationsForVehicle(widget.vehicle, limit: 3);
    if (!mounted) return;
    result.when(
      success: (recs) => setState(() => _recommendations = recs),
      failure: (_) => setState(() => _recommendations = const []),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = _recommendations;
    // 読み込み中と0件は何も出さない。ホームの一等地に「ありません」を
    // 置いても、できることは増えない。
    if (recommendations == null || recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.build_circle_outlined,
          title: 'おすすめパーツ',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PartRecommendationScreen(vehicle: widget.vehicle),
            ),
          ),
        ),
        _SectionSummary(
          items: [('${widget.vehicle.displayName}に合うもの', '')],
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < recommendations.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _PartRow(
                  recommendation: recommendations[i],
                  vehicle: widget.vehicle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  final PartRecommendation recommendation;
  final Vehicle vehicle;

  const _PartRow({required this.recommendation, required this.vehicle});

  /// カテゴリの絵。**何の部品かが、名前を読む前に分かる**ようにする。
  IconData get _categoryIcon {
    switch (recommendation.part.category) {
      case PartCategory.wheel:
      case PartCategory.tire:
        return Icons.trip_origin;
      case PartCategory.brake:
        return Icons.disc_full_outlined;
      case PartCategory.lighting:
        return Icons.lightbulb_outline;
      case PartCategory.audio:
        return Icons.speaker_outlined;
      case PartCategory.navigation:
        return Icons.navigation_outlined;
      case PartCategory.safety:
        return Icons.shield_outlined;
      case PartCategory.interior:
        return Icons.event_seat_outlined;
      case PartCategory.maintenance:
        return Icons.oil_barrel_outlined;
      case PartCategory.aero:
      case PartCategory.exterior:
        return Icons.directions_car_outlined;
      case PartCategory.suspension:
      case PartCategory.exhaust:
      case PartCategory.intake:
      case PartCategory.performance:
      case PartCategory.accessory:
      case PartCategory.other:
        return Icons.build_outlined;
    }
  }

  /// 適合の度合いを色で分ける。**「条件付き」を「完全対応」と同じ色で
  /// 出さない。** 追加の部品や加工が要ることは、買う前に伝わっていてよい。
  Color get _compatibilityColor {
    switch (recommendation.compatibility) {
      case CompatibilityLevel.perfect:
        return AppColors.success;
      case CompatibilityLevel.compatible:
        return AppColors.primary;
      case CompatibilityLevel.conditional:
        return AppColors.warning;
      case CompatibilityLevel.incompatible:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = recommendation.part;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PartRecommendationScreen(vehicle: vehicle),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(_categoryIcon, size: 18, color: AppColors.primary),
            AppSpacing.horizontalSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalXxs,
                  Row(
                    children: [
                      Text(
                        recommendation.compatibility.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _compatibilityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // ブランドが無い出品もあるので、その分は詰める。
                      if (part.brand != null && part.brand!.isNotEmpty) ...[
                        Text(' ・ ', style: theme.textTheme.bodySmall),
                        Flexible(
                          child: Text(
                            part.brand!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            AppSpacing.horizontalSm,
            Text(
              part.priceDisplay,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 下段メニューの1マス。
///
/// アイコンと文字を横に並べる。縦積み（アイコンの下に文字）より1行ぶん
/// 低く収まり、2行にしても画面を取りすぎない。
class _NavCell extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavCell({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        key: Key('nav_cell_$index'),
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : null,
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? selectedIcon : icon, size: 20, color: color),
              AppSpacing.horizontalXs,
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
