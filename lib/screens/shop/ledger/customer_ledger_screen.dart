import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/error/app_error.dart';
import '../../../core/result/result.dart';
import '../../../models/inspection_push_request.dart';
import '../../../models/shop_ledger.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../services/vehicle_share_service.dart';
import '../../../services/shop_staff_service.dart';
import '../../../services/detail_delivery_service.dart';
import '../../../services/ledger_link_service.dart';
import '../../../services/shop_audit_service.dart';
import 'audit_log_screen.dart';
import 'loss_report_screen.dart';
import '../../../services/shop_invite_service.dart';
import '../../../services/ledger_csv_export.dart';
import '../../../services/inspection_push_service.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'customer_detail_screen.dart';
import 'customer_edit_screen.dart';
import 'ledger_csv_import_screen.dart';
import 'ledger_csv_share.dart';
import 'shared_vehicles_screen.dart';
import 'staff_screens.dart';
import 'unsent_details_screen.dart';
import 'ledger_format.dart';
import 'ledger_paged_list.dart';

/// 店の顧客台帳（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §5）。
///
/// 3つの見方を用意する。店が顧客を見るときの問いがそれぞれ違うため。
///
/// - **顧客**：この人は誰で、何台持っているか（名前・ナンバーで引く）
/// - **車検が近い**：今月・来月、誰に声をかけるか（顧客をまたいで満了日順）
/// - **しばらく来ていない**：離れかけているのは誰か
class CustomerLedgerScreen extends StatefulWidget {
  final ShopLedgerService service;

  /// ユーザーから渡された車の写しを読むため。渡さなければ入口を出さない。
  final VehicleShareService? shareService;

  /// 店主が開いたときだけ渡す（スタッフの管理・統計協力の切り替えは店主だけ）。
  final ShopStaffService? staffService;
  final String? ownerUid;

  /// 店主の名前（引き継いだあと、スタッフ名簿に前の店主として載せる）。
  final String ownerName;

  /// 顧客とアプリの利用者をつなぎ、整備明細を送るため（店主だけ）。
  final LedgerLinkService? linkService;
  final ShopInviteService? inviteService;

  /// 取り込んだ伝票から、アプリ利用客への整備明細をまとめて送るため。
  /// [currentUid] は送る人（いまログインしている店主・スタッフ）。
  /// どちらかが無ければ「送っていない明細」の入口を出さない。
  final DetailDeliveryService? deliveryService;
  final String? currentUid;

  /// CSV 取込でファイルを選ぶ関数。テスト（操作の流れを通すもの）で差し替える。
  final CsvFilePicker? csvPicker;

  /// 書き出した CSV を渡す関数。テストで差し替える。
  final CsvSharer? csvSharer;

  /// アプリを使っているお客さんに車検案内（プッシュ）を送るため。
  /// [currentUid]（依頼する人。整備明細の送付と同じ値）と両方そろったときだけ入口を出す。
  final InspectionPushService? pushService;

  /// 操作の記録。[auditService] は店主が記録を見るため（店主のときだけ渡す）。
  final AuditRecorder? onAudit;
  final ShopAuditService? auditService;
  final String shopId;
  final String shopName;

  /// 「今日」。テスト（特にゴールデン）で日付を止めるために渡せる。
  final DateTime? today;

  /// Opens the customer-side app ("マイカー"). Set when the ledger is the
  /// first screen after sign-in (shop owners and staff), so the way to
  /// the customer screens stays one tap away.
  final VoidCallback? onOpenUserHome;

  const CustomerLedgerScreen({
    super.key,
    required this.service,
    this.shareService,
    this.staffService,
    this.ownerUid,
    this.ownerName = '',
    this.linkService,
    this.inviteService,
    this.deliveryService,
    this.currentUid,
    this.csvPicker,
    this.csvSharer,
    this.pushService,
    this.onAudit,
    this.auditService,
    required this.shopId,
    required this.shopName,
    this.today,
    this.onOpenUserHome,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _searchController = TextEditingController();
  Timer? _debounce;

  LedgerCounts? _counts;
  String _search = '';
  LedgerCustomerSort _sort = LedgerCustomerSort.kana;

  /// 登録・編集・削除のあとに、一覧を先頭から読み直すための番号。
  int _revision = 0;

  /// 書き出しの途中（全件を読んでいる間）。
  bool _exporting = false;

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _ensureSearchFields();
  }

  /// Ledgers written before 2026-10-09 lack the kanji / given-name / phone
  /// and 2-digit plate search fields. Fill them in once (a no-op after
  /// that) and reload the list so the new search works right away.
  Future<void> _ensureSearchFields() async {
    final r = await widget.service.ensureSearchFields(widget.shopId);
    if (!mounted || (r.valueOrNull ?? 0) == 0) return;
    setState(() => _revision++);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final result = await widget.service.counts(widget.shopId);
    if (!mounted) return;
    setState(() => _counts = result.valueOrNull ?? LedgerCounts.empty);
  }

  void _refreshAll() {
    setState(() => _revision++);
    _loadCounts();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // 1文字打つたびに問い合わせない。
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _search = '');
  }

  /// 数字が入っていたら、ナンバーの末尾の番号として引く。
  /// 数字（と区切り）だけで5桁以上なら電話番号なので、顧客から引く。
  bool get _isPlateSearch =>
      RegExp(r'[0-9０-９]').hasMatch(_search) &&
      !LedgerSearch.isPhoneQuery(_search);

  Future<void> _openCustomer(String customerId) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          service: widget.service,
          shopId: widget.shopId,
          customerId: customerId,
          today: widget.today,
          linkService: widget.linkService,
          inviteService: widget.inviteService,
          shopName: widget.shopName,
          ownerUid: widget.ownerUid,
          onAudit: widget.onAudit,
        ),
      ),
    );
    if (changed == true) _refreshAll();
  }

  Future<void> _addCustomer() async {
    final created = await Navigator.push<LedgerCustomer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerEditScreen(
          service: widget.service,
          shopId: widget.shopId,
        ),
      ),
    );
    if (created == null || !mounted) return;
    widget.onAudit?.call(ShopAuditAction.createCustomer,
        targetId: created.id, targetLabel: created.name);
    _refreshAll();
    await _openCustomer(created.id);
  }

  Future<void> _openLoss() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LossReportScreen(
          service: widget.service,
          shopId: widget.shopId,
          onOpenCustomer: _openCustomer,
        ),
      ),
    );
  }

  Future<void> _openUnsentDetails() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => UnsentDetailsScreen(
          service: widget.deliveryService!,
          shopId: widget.shopId,
          shopName: widget.shopName,
          senderUid: widget.currentUid!,
          onAudit: widget.onAudit,
        ),
      ),
    );
  }

  Future<void> _openAudit() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AuditLogScreen(
          service: widget.auditService!,
          shopId: widget.shopId,
        ),
      ),
    );
  }

  Future<void> _openStaff() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StaffManageScreen(
          service: widget.staffService!,
          shopId: widget.shopId,
          shopName: widget.shopName,
          ownerUid: widget.ownerUid!,
          ownerName: widget.ownerName,
        ),
      ),
    );
  }

  Future<void> _openShared() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SharedVehiclesScreen(
          service: widget.shareService!,
          ledger: widget.service,
          shopId: widget.shopId,
          today: widget.today,
          onAudit: widget.onAudit,
        ),
      ),
    );
    if (changed == true) _refreshAll();
  }

  /// 整備実績を、車種別の維持費レポートの匿名の集計に使ってよいか。
  ///
  /// **既定は協力しない。** 店の実績は店のもので、同意なしに集計に入れない。
  Future<void> _openStatistics() async {
    final current = await widget.service.allowsStatistics(widget.shopId);
    if (!mounted) return;
    var value = current.valueOrNull ?? false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('車種別レポートへの協力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '取り込んだ整備履歴を、「この車種は年にいくらかかるか」の'
                '集計に使います。お客さんの名前・連絡先・ナンバーは使いません。'
                '持ち主が5人に満たない数字は出しません。',
              ),
              AppSpacing.verticalSm,
              SwitchListTile(
                key: const Key('ledger_stats_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('匿名の集計に協力する'),
                value: value,
                onChanged: (v) async {
                  final r = await widget.service.setAllowsStatistics(
                    shopId: widget.shopId,
                    value: v,
                  );
                  if (r.isSuccess) {
                    setLocal(() => value = v);
                  } else if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('切り替えられるのは店主のアカウントだけです')),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCsv() async {
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerCsvImportScreen(
          service: widget.service,
          shopId: widget.shopId,
          pickFile: widget.csvPicker ?? pickCsvWithFilePicker,
          onAudit: widget.onAudit,
        ),
      ),
    );
    if (imported == true) _refreshAll();
  }

  CsvSharer get _share => widget.csvSharer ?? shareLedgerCsv;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 台帳の全件を CSV で書き出す（2026-09-29 プロダクト評価 #8）。
  ///
  /// やめるときに名簿を持ち出せるように。書き出した CSV は、そのまま
  /// 「CSVから取り込む」で取り込み直せる。
  Future<void> _exportAll() async {
    final total = _counts?.total;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('台帳を書き出す'),
        content: Text(
          '${total == null ? '全員' : '顧客$total人'}分の名前・住所・電話番号・車両を、'
          'CSV ファイルにして渡します。\n\n'
          'お客さんの個人情報です。書き出したことは操作の記録に残ります。'
          '渡した先で漏れないよう、扱いに気をつけてください。\n\n'
          'このファイルは「CSVから取り込む」でそのまま取り込み直せます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            key: const Key('ledger_export_all_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('書き出す'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _exporting = true);
    final result = await widget.service.exportAll(shopId: widget.shopId);
    if (!mounted) return;
    setState(() => _exporting = false);

    final data = result.valueOrNull;
    if (data == null) {
      _snack('書き出せませんでした: ${result.errorOrNull?.userMessage ?? ''}');
      return;
    }

    final csv =
        buildLedgerCsv(customers: data.customers, vehicles: data.vehicles);
    final detail = '顧客${data.customers.length}人・車両${data.vehicles.length}台';
    // 渡す前に記録する。共有の途中で落ちても、持ち出した記録は残す
    widget.onAudit?.call(ShopAuditAction.exportLedger, detail: detail);
    try {
      await _share(
        csv: csv,
        fileName: '顧客台帳_${ledgerFileStamp(_today)}.csv',
        subject: '${widget.shopName} 顧客台帳',
      );
    } catch (e) {
      _snack('CSVの共有に失敗しました: $e');
    }
  }

  /// 車検案内（はがき・DM）の宛名を書き出す（2026-09-29 プロダクト評価 #2）。
  ///
  /// アプリを入れていないお客さんには、はがきで案内するしかない。
  /// 印刷・発送の業者に渡す CSV を作り、書き出した車に「案内した日」を付ける
  /// （同じ満了日の案内を二度出さない）。
  Future<void> _exportNotice() async {
    final options = await showDialog<_NoticeOptions>(
      context: context,
      builder: (_) => const _NoticeDialog(),
    );
    if (options == null || !mounted) return;

    final from = DateTime(_today.year, _today.month, _today.day);
    final to = DateTime(from.year, from.month + options.months, from.day);
    setState(() => _exporting = true);
    final result = await widget.service.inspectionNoticeTargets(
      shopId: widget.shopId,
      from: from,
      to: to,
      excludeNoticed: options.excludeNoticed,
      excludeLinked: options.excludeLinked,
    );
    if (!mounted) return;
    setState(() => _exporting = false);

    final list = result.valueOrNull;
    if (list == null) {
      _snack('書き出せませんでした: ${result.errorOrNull?.userMessage ?? ''}');
      return;
    }

    final skipped = [
      if (list.alreadyNoticed > 0) '案内済みの${list.alreadyNoticed}台',
      if (list.linked > 0) 'アプリ利用中の${list.linked}台',
      if (list.withoutAddress > 0) '住所の無い${list.withoutAddress}台',
    ];
    final skippedNote = skipped.isEmpty ? '' : '（${skipped.join('・')}は除きました）';

    if (list.targets.isEmpty) {
      _snack('満了日が${ledgerDate(from)}〜${ledgerDate(to)}の、'
          '対象の車はありません$skippedNote');
      return;
    }

    final n = list.targets.length;
    final csv = buildInspectionNoticeCsv(list.targets);
    widget.onAudit?.call(
      ShopAuditAction.exportInspectionNotice,
      detail: '満了日 ${ledgerDate(from)}〜${ledgerDate(to)}・$n台',
    );

    final bool handedOver;
    try {
      handedOver = await _share(
        csv: csv,
        fileName: '車検案内_${ledgerFileStamp(_today)}.csv',
        subject: '${widget.shopName} 車検案内の宛名',
      );
    } catch (e) {
      _snack('CSVの共有に失敗しました: $e');
      return;
    }
    // 共有を取り消したら、案内した日は付けない（まだ誰にも渡っていない）
    if (!handedOver) return;

    final marked = await widget.service.markInspectionNoticed(
      shopId: widget.shopId,
      vehicles: [for (final t in list.targets) t.vehicle],
    );
    if (marked.isFailure) {
      _snack('$n台分を書き出しましたが、案内した日を記録できませんでした');
      return;
    }
    _snack('$n台分を書き出し、案内した日を記録しました$skippedNote');
  }

  bool get _canSendAppNotice =>
      widget.pushService != null && (widget.currentUid ?? '').isNotEmpty;

  /// アプリを使っているお客さんに、車検案内をプッシュで送る
  /// （2026-09-29 プロダクト評価 #2 の「アプリ有り」の側）。
  ///
  /// はがきと同じ「車検が近い」の期間で、台帳とアプリがつながっている
  /// お客さんの車を選ぶ。送るのはサーバー（Cloud Functions）で、送れた車には
  /// はがきと同じ「案内した日」が付く（同じ満了日の案内を二度出さない）。
  Future<void> _sendAppNotice() async {
    final push = widget.pushService;
    final uid = widget.currentUid;
    if (push == null || uid == null) return;

    final months = await showDialog<int>(
      context: context,
      builder: (_) => const _AppNoticeDialog(),
    );
    if (months == null || !mounted) return;

    final from = DateTime(_today.year, _today.month, _today.day);
    final to = DateTime(from.year, from.month + months, from.day);
    setState(() => _exporting = true);
    final result = await widget.service.appInspectionNoticeTargets(
      shopId: widget.shopId,
      from: from,
      to: to,
    );
    if (!mounted) return;
    setState(() => _exporting = false);

    final list = result.valueOrNull;
    if (list == null) {
      _snack('対象の車を読めませんでした: ${result.errorOrNull?.userMessage ?? ''}');
      return;
    }
    final skipped = [
      if (list.alreadyNoticed > 0) '案内済みの${list.alreadyNoticed}台',
      if (list.notLinked > 0) 'アプリを使っていない${list.notLinked}台',
    ];
    final skippedNote = skipped.isEmpty ? '' : '（${skipped.join('・')}は除きます）';
    if (list.targets.isEmpty) {
      _snack('満了日が${ledgerDate(from)}〜${ledgerDate(to)}の、'
          'アプリを使っているお客さんの車はありません$skippedNote');
      return;
    }

    final n = list.targets.length;
    final people = list.targets.map((t) => t.customer.id).toSet().length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アプリに車検案内を送る'),
        content: Text(
          '満了日が${ledgerDate(from)}〜${ledgerDate(to)}の$n台'
          '（$people人）の持ち主のアプリに、車検の案内を通知します。'
          '$skippedNote\n\n'
          '通知を切っているお客さんには届きません。届いた車には、今日を'
          '「案内した日」として記録します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            key: const Key('ledger_app_notice_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('送る'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final sent = await push.request(
      shopId: widget.shopId,
      requesterUid: uid,
      vehicleIds: [for (final t in list.targets) t.vehicle.id],
    );
    if (!mounted) return;
    final noticeId = sent.valueOrNull;
    if (noticeId == null) {
      _snack('送れませんでした: ${sent.errorOrNull?.userMessage ?? ''}');
      return;
    }
    widget.onAudit?.call(
      ShopAuditAction.sendInspectionPush,
      detail: '満了日 ${ledgerDate(from)}〜${ledgerDate(to)}・$n台',
    );
    await showDialog<void>(
      context: context,
      builder: (_) => _AppNoticeProgressDialog(
        stream: push.watch(shopId: widget.shopId, noticeId: noticeId),
        requested: n,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('顧客台帳'),
        // As the first screen there is no back button; the way to the
        // customer side goes there, as words rather than an icon.
        leadingWidth: widget.onOpenUserHome == null ? null : 96,
        leading: widget.onOpenUserHome == null
            ? null
            : TextButton.icon(
                key: const Key('ledger_open_user_home'),
                onPressed: widget.onOpenUserHome,
                icon: const Icon(Icons.directions_car_outlined, size: 18),
                label: const Text('マイカー'),
              ),
        actions: [
          IconButton(
            key: const Key('ledger_loss'),
            tooltip: '車検の取りこぼし',
            icon: const Icon(Icons.trending_down),
            onPressed: _openLoss,
          ),
          if (widget.deliveryService != null && widget.currentUid != null)
            IconButton(
              key: const Key('ledger_unsent_details'),
              tooltip: '送っていない明細',
              icon: const Icon(Icons.outbox_outlined),
              onPressed: _openUnsentDetails,
            ),
          if (widget.shareService != null)
            IconButton(
              key: const Key('ledger_shared_vehicles'),
              tooltip: '共有された車',
              icon: const Icon(Icons.inbox_outlined),
              onPressed: _openShared,
            ),
          IconButton(
            key: const Key('ledger_import_csv'),
            tooltip: 'CSVから取り込む',
            icon: const Icon(Icons.upload_file),
            onPressed: _importCsv,
          ),
          PopupMenuButton<String>(
            key: const Key('ledger_more'),
            onSelected: (v) {
              if (v == 'stats') _openStatistics();
              if (v == 'staff') _openStaff();
              if (v == 'audit') _openAudit();
              if (v == 'export_all') _exportAll();
              if (v == 'export_notice') _exportNotice();
              if (v == 'app_notice') _sendAppNotice();
            },
            itemBuilder: (_) => [
              if (widget.staffService != null && widget.ownerUid != null)
                const PopupMenuItem(value: 'staff', child: Text('スタッフ')),
              if (widget.auditService != null)
                const PopupMenuItem(value: 'audit', child: Text('操作の記録')),
              if (_canSendAppNotice)
                PopupMenuItem(
                  value: 'app_notice',
                  enabled: !_exporting,
                  child: const Text('アプリに車検案内を送る'),
                ),
              PopupMenuItem(
                value: 'export_notice',
                enabled: !_exporting,
                child: const Text('車検案内の宛名を書き出す'),
              ),
              // 全件の書き出しは店のスタッフ全員が使える（2026-10-01 オーナー判断）。
              // ルール上スタッフは台帳を全件読めるので、画面で止めても守りにならない。
              // 代わりに、誰がいつ書き出したかを操作の記録に残す。
              PopupMenuItem(
                value: 'export_all',
                enabled: !_exporting,
                child: const Text('台帳を書き出す（CSV）'),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: Text('車種別レポートへの協力'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          // AppBar は紺。タブの文字は AppBar に対して見える色にする
          // （既定の primary だと紺の上に紺で、選んだタブが読めない）。
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '顧客'),
            Tab(text: '車検が近い'),
            Tab(text: 'しばらく来ていない'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ledger_add_customer'),
        // テーマの形は丸い FAB 用。extended は自分で形を渡さないと丸に潰れる
        shape: const StadiumBorder(),
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('顧客を追加'),
      ),
      body: Column(
        children: [
          _CountsBar(counts: _counts),
          if (_exporting) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _customersTab(),
                _inspectionTab(),
                _lapsedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ledger_search'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '名前・フリガナ・電話番号・ナンバー末尾（2〜4桁）',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              AppSpacing.horizontalXs,
              PopupMenuButton<LedgerCustomerSort>(
                key: const Key('ledger_sort'),
                tooltip: '並べ替え',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final s in LedgerCustomerSort.values)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isPlateSearch ? _plateResults() : _customerList(),
        ),
      ],
    );
  }

  Widget _customerList() {
    return LedgerPagedList<LedgerCustomer>(
      reloadKey: '$_revision|$_search|${_sort.name}',
      loader: (cursor) => widget.service.listCustomers(
        shopId: widget.shopId,
        sort: _sort,
        search: _search,
        cursor: cursor,
      ),
      itemBuilder: (context, c) => _CustomerTile(
        customer: c,
        today: _today,
        onTap: () => _openCustomer(c.id),
      ),
      empty: _search.isEmpty
          ? AppEmptyState(
              icon: Icons.people_outline,
              title: 'まだ顧客が登録されていません',
              description: '整備管理ソフトの名簿があれば、右上の取込ボタンから'
                  'CSV でまとめて入れられます。1人ずつなら右下の「顧客を追加」から。',
              buttonLabel: '顧客を追加',
              onButtonPressed: _addCustomer,
            )
          : _NoMatch(
              key: ValueKey('nomatch|$_revision|$_search'),
              search: _search,
              similar: widget.service.similarCustomers(
                shopId: widget.shopId,
                search: _search,
              ),
              today: _today,
              onOpenCustomer: _openCustomer,
              onAdd: _addCustomer,
            ),
    );
  }

  /// Fetch one more than shown, to tell whether there are more.
  static const int _plateLimit = 50;

  /// ナンバーは件数が少ない（同じ末尾番号は店内で数台）ので、ページングしない。
  Widget _plateResults() {
    return FutureBuilder(
      key: ValueKey('plate|$_revision|$_search'),
      future: widget.service.findVehiclesByPlateNumber(
        shopId: widget.shopId,
        number: _search,
        limit: _plateLimit + 1,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const AppLoadingCenter();
        final found = snap.data!.valueOrNull ?? const <LedgerVehicle>[];
        final number = LedgerSearch.plateNumber(_search) ?? '';
        if (found.isEmpty) {
          // One digit is only matched exactly (a one-digit tail would hit
          // a tenth of the shop), so do not say "no such car" for it.
          return AppEmptyState(
            icon: Icons.search_off,
            title: number.length < 2
                ? 'ナンバー末尾は2〜4桁で入れてください'
                : 'ナンバー末尾「$number」の車はありません',
            description: number.length < 2
                ? '例: 63-35 の車なら「35」「335」「6335」のどれでも探せます。'
                : 'ナンバーが未登録の車は、名前・フリガナ・電話番号で探してください。',
            buttonLabel: '検索を消す',
            onButtonPressed: _clearSearch,
          );
        }
        final more = found.length > _plateLimit;
        final vehicles = more ? found.take(_plateLimit) : found;
        return ListView(
          children: [
            for (final v in vehicles)
              _VehicleTile(
                vehicle: v,
                today: _today,
                onTap: () => _openCustomer(v.customerId),
              ),
            if (more)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('ほかにもあります。末尾の桁を増やすと絞り込めます。'),
              ),
          ],
        );
      },
    );
  }

  Widget _inspectionTab() {
    return LedgerPagedList<LedgerVehicle>(
      reloadKey: _revision,
      loader: (cursor) => widget.service.listVehiclesByInspection(
        shopId: widget.shopId,
        from: _today,
        cursor: cursor,
      ),
      itemBuilder: (context, v) => _VehicleTile(
        vehicle: v,
        today: _today,
        onTap: () => _openCustomer(v.customerId),
      ),
      empty: AppEmptyState(
        icon: Icons.event_available,
        title: '車検満了日が入っている車はまだありません',
        description: '顧客の車両に満了日を入れると、ここに近い順で並びます。',
        buttonLabel: '顧客一覧へ',
        onButtonPressed: () => _tabs.animateTo(0),
      ),
    );
  }

  Widget _lapsedTab() {
    // 1年。車検は2年ごとでも、点検・オイル交換で年1回は来るのが普通。
    final since = DateTime(_today.year - 1, _today.month, _today.day);
    return LedgerPagedList<LedgerCustomer>(
      reloadKey: _revision,
      loader: (cursor) => widget.service.listLapsedCustomers(
        shopId: widget.shopId,
        since: since,
        cursor: cursor,
      ),
      itemBuilder: (context, c) => _CustomerTile(
        customer: c,
        today: _today,
        showLastVisit: true,
        onTap: () => _openCustomer(c.id),
      ),
      empty: AppEmptyState(
        icon: Icons.check_circle_outline,
        title: '1年以上来ていない顧客はいません',
        description: '最後に来た日が入っている顧客だけを数えています。',
        buttonLabel: '車検が近い車を見る',
        onButtonPressed: () => _tabs.animateTo(1),
      ),
    );
  }
}

/// 車検案内の書き出しの条件。
class _NoticeOptions {
  final int months;
  final bool excludeNoticed;
  final bool excludeLinked;

  const _NoticeOptions({
    required this.months,
    required this.excludeNoticed,
    required this.excludeLinked,
  });
}

/// 車検案内の書き出しの条件を選ぶ。
///
/// 既定は「2か月以内・案内済みは除く・アプリの人は除く」。車検の案内は
/// 1〜2か月前に出すのが普通で、アプリの人にはアプリで案内が届く。
class _NoticeDialog extends StatefulWidget {
  const _NoticeDialog();

  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<_NoticeDialog> {
  int _months = 2;
  bool _excludeNoticed = true;
  bool _excludeLinked = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('車検案内の宛名を書き出す'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('はがき・DM の業者に渡す CSV（氏名・住所・電話・車名・'
                '登録番号・満了日）を作ります。書き出した車には、今日を'
                '「案内した日」として記録します。'),
            AppSpacing.verticalSm,
            const Text('満了日が今日から'),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [1, 2, 3])
                  ChoiceChip(
                    key: Key('ledger_notice_months_$m'),
                    label: Text('$mか月以内'),
                    selected: _months == m,
                    onSelected: (_) => setState(() => _months = m),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('ledger_notice_exclude_noticed'),
              contentPadding: EdgeInsets.zero,
              title: const Text('この満了日で案内済みの車は除く'),
              value: _excludeNoticed,
              onChanged: (v) => setState(() => _excludeNoticed = v),
            ),
            SwitchListTile(
              key: const Key('ledger_notice_exclude_linked'),
              contentPadding: EdgeInsets.zero,
              title: const Text('アプリを使っているお客さんは除く'),
              subtitle: const Text('アプリに案内が届くため'),
              value: _excludeLinked,
              onChanged: (v) => setState(() => _excludeLinked = v),
            ),
            const Text('住所の無いお客さんは、はがきが出せないので除きます。'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const Key('ledger_notice_export'),
          onPressed: () => Navigator.pop(
            context,
            _NoticeOptions(
              months: _months,
              excludeNoticed: _excludeNoticed,
              excludeLinked: _excludeLinked,
            ),
          ),
          child: const Text('書き出す'),
        ),
      ],
    );
  }
}

/// アプリへの車検案内の期間を選ぶ。既定は2か月（はがきと同じ）。
class _AppNoticeDialog extends StatefulWidget {
  const _AppNoticeDialog();

  @override
  State<_AppNoticeDialog> createState() => _AppNoticeDialogState();
}

class _AppNoticeDialogState extends State<_AppNoticeDialog> {
  int _months = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('アプリに車検案内を送る'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('台帳とアプリがつながっているお客さんに、車検が近いことを'
                'プッシュ通知で知らせます。この満了日で案内済みの車には送りません。'),
            AppSpacing.verticalSm,
            const Text('満了日が今日から'),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [1, 2, 3])
                  ChoiceChip(
                    key: Key('ledger_app_notice_months_$m'),
                    label: Text('$mか月以内'),
                    selected: _months == m,
                    onSelected: (_) => setState(() => _months = m),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const Key('ledger_app_notice_next'),
          onPressed: () => Navigator.pop(context, _months),
          child: const Text('対象を確かめる'),
        ),
      ],
    );
  }
}

/// 送った結果を待って見せる。送るのはサーバーなので、閉じても送信は続く。
class _AppNoticeProgressDialog extends StatelessWidget {
  final Stream<InspectionPushRequest> stream;
  final int requested;

  const _AppNoticeProgressDialog({
    required this.stream,
    required this.requested,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InspectionPushRequest>(
      stream: stream,
      builder: (context, snap) {
        final req = snap.data;
        final Widget content;
        if (req == null || !req.isFinished) {
          content = const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(),
              AppSpacing.verticalSm,
              Text('送っています。閉じても送信は続きます。'),
            ],
          );
        } else if (req.status == InspectionPushStatus.failed) {
          content = const Text(
            '送信の途中で失敗しました。時間をおいて、もう一度送ってください'
            '（届いた車には案内した日が付いているので、二重には届きません）。',
            key: Key('ledger_app_notice_failed'),
          );
        } else {
          final r = req.result ?? const InspectionPushResult();
          final notes = r.skippedNotes;
          final lines = [
            '$requested台のうち${r.sent}台に案内を送りました。',
            if (notes.isNotEmpty) '届かなかった車: ${notes.join('・')}',
            if (r.pushOff + r.noDevice > 0)
              '届かなかったお客さんには、はがきの宛名の書き出しで'
                  '「アプリを使っているお客さんは除く」を外すと案内できます。',
          ];
          content = Text(
            lines.join('\n\n'),
            key: const Key('ledger_app_notice_result'),
          );
        }
        return AlertDialog(
          title: const Text('アプリに車検案内を送る'),
          content: content,
          actions: [
            TextButton(
              key: const Key('ledger_app_notice_close'),
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}

class _CountsBar extends StatelessWidget {
  final LedgerCounts? counts;

  const _CountsBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    final c = counts;
    final theme = Theme.of(context);
    Widget item(String label, String value, {Key? key}) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                key: key,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        );
    String n(int? v) => v == null ? '—' : '$v';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          item('顧客', n(c?.total), key: const Key('ledger_count_total')),
          item('個人', n(c?.individual)),
          item('法人', n(c?.corporate)),
          item('アプリ利用中', n(c?.linked)),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final LedgerCustomer customer;
  final DateTime today;
  final bool showLastVisit;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.today,
    required this.onTap,
    this.showLastVisit = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final details = <String>[
      '${c.vehicleCount}台',
      if (showLastVisit && c.lastVisitAt != null)
        '最終来店 ${ledgerDate(c.lastVisitAt!)}（${ledgerMonthsAgo(c.lastVisitAt!, today)}）'
      else if (c.nextInspectionAt != null)
        '次の車検 ${ledgerDate(c.nextInspectionAt!)}',
    ];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(
          c.kind == LedgerCustomerKind.corporate
              ? Icons.business
              : Icons.person,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          if (c.isLinked) ...[
            AppSpacing.horizontalXs,
            const _Badge(label: 'アプリ', color: AppColors.secondary),
          ],
        ],
      ),
      subtitle: Text(details.join('・')),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final LedgerVehicle vehicle;
  final DateTime today;
  final VoidCallback onTap;

  const _VehicleTile({
    required this.vehicle,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final exp = v.inspectionExpiry;
    final days = exp == null ? null : ledgerDaysUntil(exp, today);

    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.directions_car)),
      title: Text(
        [v.displayName, if (v.plate != null) v.plate!].join('　'),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(v.customerName),
      trailing: exp == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(ledgerDate(exp)),
                Text(
                  days! < 0 ? '切れています' : 'あと$days日',
                  style: TextStyle(
                    color: days < 31 ? AppColors.error : null,
                    fontWeight: days < 31 ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

/// Shown when a customer search finds nobody (2026-10-08 usability test:
/// "no one" sat right above "add as a new customer", which led to the
/// same person being registered twice).
///
/// Says what can be searched, shows people with a similar name first,
/// and only then offers to add.
class _NoMatch extends StatelessWidget {
  final String search;
  final Future<Result<List<LedgerCustomer>, AppError>> similar;
  final DateTime today;
  final void Function(String customerId) onOpenCustomer;
  final VoidCallback onAdd;

  const _NoMatch({
    super.key,
    required this.search,
    required this.similar,
    required this.today,
    required this.onOpenCustomer,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Placed inside the paged list's ListView (pull to refresh), so a
    // plain column.
    return Padding(
      key: const Key('ledger_no_match'),
      padding: AppSpacing.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('「$search」に当たる顧客はいません', style: theme.textTheme.titleMedium),
          AppSpacing.verticalXs,
          Text(
            '名前（漢字）・フリガナ（姓だけ・名だけでも）・電話番号・'
            'ナンバー末尾（2〜4桁）で探せます。どれも先頭から一致するものを出します。',
            style: theme.textTheme.bodyMedium,
          ),
          AppSpacing.verticalMd,
          FutureBuilder<Result<List<LedgerCustomer>, AppError>>(
            future: similar,
            builder: (context, snap) {
              final list = snap.data?.valueOrNull ?? const <LedgerCustomer>[];
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                key: const Key('ledger_similar'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('名前の近い顧客', style: theme.textTheme.titleSmall),
                  for (final c in list)
                    _CustomerTile(
                      customer: c,
                      today: today,
                      onTap: () => onOpenCustomer(c.id),
                    ),
                  AppSpacing.verticalMd,
                ],
              );
            },
          ),
          Text(
            '同じ人を二重に登録しないよう、電話番号でも探してみてください。',
            style: theme.textTheme.bodySmall,
          ),
          AppSpacing.verticalSm,
          OutlinedButton.icon(
            key: const Key('ledger_no_match_add'),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('台帳に無いので、新しい顧客として追加'),
          ),
        ],
      ),
    );
  }
}
