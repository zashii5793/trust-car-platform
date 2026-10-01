import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop_ledger.dart';
import 'inquiry_maintenance_importer.dart';
import 'inquiry_service.dart';
import 'ledger_link_service.dart';
import 'maintenance_history_import.dart';

/// 送っていない明細1件（取り込んだ伝票から、開いたときに組み立てる下書き）。
///
/// Firestore には書かない。伝票（`service_records`）と台帳の顧客から、
/// 一覧を開くたびに作り直す。
class DetailDraft {
  final String recordId;
  final String customerId;
  final String customerName;

  /// 送り先（台帳の顧客につながっているアプリの利用者）。
  final String userId;
  final DateTime date;

  /// 伝票の「作業内容」（自由に書かれた言葉）。
  final String typeText;
  final int totalCost;
  final int? mileage;
  final String? slipNumber;
  final String? maker;
  final String? model;

  const DetailDraft({
    required this.recordId,
    required this.customerId,
    required this.customerName,
    required this.userId,
    required this.date,
    required this.typeText,
    required this.totalCost,
    this.mileage,
    this.slipNumber,
    this.maker,
    this.model,
  });

  String get vehicleLabel =>
      [maker, model].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  /// 送る中身。1件ずつ送るときのフォームが作るものと同じ形。
  InquiryMaintenancePayload payload({required String shopName}) {
    final title = typeText.trim().isEmpty ? '整備' : typeText.trim();
    return InquiryMaintenancePayload(
      typeKey: guessMaintenanceType(typeText).name,
      title: title,
      date: date,
      cost: totalCost < 0 ? 0 : totalCost,
      mileageAtService: mileage,
      shopName: shopName.isEmpty ? null : shopName,
      description: slipNumber == null ? null : '伝票番号 $slipNumber',
    );
  }
}

/// 「送っていない明細」の一覧と、明細送付率の材料。
class DetailDeliveryList {
  final List<DetailDraft> drafts;

  /// 期間内の、アプリ利用客の入庫（伝票）の件数。率の分母。
  final int linkedRecords;

  /// そのうち明細を送ったもの。率の分子。
  final int sentRecords;

  /// 数えた期間（日）。
  final int days;

  const DetailDeliveryList({
    required this.drafts,
    required this.linkedRecords,
    required this.sentRecords,
    required this.days,
  });

  /// 明細送付率（0〜1）。アプリ利用客の入庫が無ければ null。
  double? get rate => linkedRecords == 0 ? null : sentRecords / linkedRecords;
}

/// 送れなかった1件。
class DetailSendFailure {
  final String recordId;
  final String message;

  const DetailSendFailure(this.recordId, this.message);
}

/// まとめて送った結果。
class DetailSendResult {
  /// 送った伝票の ID。
  final List<String> sentRecordIds;

  /// 送る前に見たら、もう送ってあった件数（別の人が送った・スレッドで
  /// 手で送ってあった）。送らずに印だけ付ける。
  final int alreadySent;

  /// 送った相手の人数。
  final int customers;
  final List<DetailSendFailure> failures;

  const DetailSendResult({
    required this.sentRecordIds,
    required this.alreadySent,
    required this.customers,
    required this.failures,
  });

  int get sent => sentRecordIds.length;
}

/// 整備明細の一括送付（2026-09-29 プロダクト評価 #4）。
///
/// 取り込んだ整備履歴（`shops/{shopId}/service_records`）のうち、アプリと
/// つながっている客の伝票で、まだ明細を送っていないものを並べ、まとめて送る。
///
/// - **下書きは書き込まない。** 一覧を開いたときに、伝票と顧客から組み立てる
///   （取込のたびに下書きを書くと、アプリを使っていない客の分まで書き込みが
///   増える）。読み取りは「期間内の伝票」と「アプリ利用中の顧客」の2本
/// - **送り方は1件ずつの送付と同じ。** 店から開いたスレッド
///   （[LedgerLinkService.openThread]）に、整備明細付きのメッセージ
///   （[InquiryService.sendMessage]）を置く
/// - 送った伝票には `detailSentAt` / `detailInquiryId` を付ける。`updatedAt` は
///   動かさない（取込が止まっていないかの判定に使っているため）。取り込み
///   直しは merge で書くので、印は消えない
class DetailDeliveryService {
  final FirebaseFirestore _firestore;
  final LedgerLinkService _linkService;
  final InquiryService _inquiryService;
  final DateTime Function() _now;

  DetailDeliveryService({
    required FirebaseFirestore firestore,
    required LedgerLinkService linkService,
    required InquiryService inquiryService,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _linkService = linkService,
        _inquiryService = inquiryService,
        _now = now ?? DateTime.now;

  /// 既定で数える期間。点検・オイル交換の明細は、入庫から日が経つほど
  /// 送る意味が薄れる。
  static const int defaultDays = 90;

  CollectionReference<Map<String, dynamic>> _records(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('service_records');

  CollectionReference<Map<String, dynamic>> _customers(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('customers');

  /// 送っていない明細と、明細送付率。
  ///
  /// 入庫日が直近 [days] 日の伝票だけを見る（日付の単一フィールドで引く。
  /// 複合インデックスは要らない）。
  Future<Result<DetailDeliveryList, AppError>> pending({
    required String shopId,
    int days = defaultDays,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(AppError.validation('店が選ばれていません'));
    }
    if (days <= 0) {
      return const Result.failure(AppError.validation('期間は1日以上にしてください'));
    }
    try {
      final now = _now();
      final since = DateTime(now.year, now.month, now.day - days);

      final linked = <String, LedgerCustomer>{
        for (final d in (await _customers(shopId)
                .where('isLinked', isEqualTo: true)
                .get())
            .docs)
          d.id: LedgerCustomer.fromMap(d.id, d.data()),
      };
      if (linked.isEmpty) {
        return Result.success(DetailDeliveryList(
            drafts: const [], linkedRecords: 0, sentRecords: 0, days: days));
      }

      final snap = await _records(shopId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      final drafts = <DetailDraft>[];
      var total = 0;
      var sent = 0;
      for (final d in snap.docs) {
        final m = d.data();
        final customer = linked[m['customerId'] as String?];
        final userId = customer?.linkedUserId;
        final date = (m['date'] as Timestamp?)?.toDate();
        if (customer == null || userId == null || date == null) continue;
        total++;
        if (m['detailSentAt'] != null) {
          sent++;
          continue;
        }
        drafts.add(DetailDraft(
          recordId: d.id,
          customerId: customer.id,
          customerName: customer.name,
          userId: userId,
          date: date,
          typeText: m['type'] as String? ?? '',
          totalCost: (m['totalCost'] as num?)?.toInt() ?? 0,
          mileage: (m['mileage'] as num?)?.toInt(),
          slipNumber: m['externalId'] as String?,
          maker: m['maker'] as String?,
          model: m['model'] as String?,
        ));
      }
      drafts.sort((a, b) => b.date.compareTo(a.date));
      return Result.success(DetailDeliveryList(
        drafts: drafts,
        linkedRecords: total,
        sentRecords: sent,
        days: days,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 選んだ明細をまとめて送る。
  ///
  /// 1件ずつ「送る直前に伝票を読み直し、送ってあれば飛ばす」ので、古い
  /// 一覧のまま押しても二重には送らない。スレッドに同じ日・同じ金額の明細が
  /// 既にあれば（スレッドから手で送ってあった）、送らずに印だけ付ける。
  ///
  /// 途中で失敗した分は [DetailSendResult.failures] に入れて、残りは続ける。
  /// 失敗した伝票には印を付けないので、一覧に残り、もう一度送れる。
  Future<Result<DetailSendResult, AppError>> sendAll({
    required String shopId,
    required String shopName,
    required String senderId,
    required List<DetailDraft> drafts,
    void Function(int done, int total)? onProgress,
  }) async {
    if (shopId.isEmpty || senderId.isEmpty) {
      return const Result.failure(AppError.validation('送る人が分かりません'));
    }
    final unique = <String, DetailDraft>{
      for (final d in drafts) d.recordId: d,
    }.values.toList();
    if (unique.isEmpty) {
      return const Result.failure(AppError.validation('送る明細を選んでください'));
    }

    // 送り先ごとにまとめる（スレッドを開くのは1人1回）
    final byUser = <String, List<DetailDraft>>{};
    for (final d in unique) {
      byUser.putIfAbsent(d.userId, () => []).add(d);
    }

    final sent = <String>[];
    var already = 0;
    var done = 0;
    final customers = <String>{};
    final failures = <DetailSendFailure>[];
    onProgress?.call(0, unique.length);

    for (final entry in byUser.entries) {
      final thread = await _linkService.openThread(
        shopId: shopId,
        shopName: shopName,
        userId: entry.key,
      );
      final inquiry = thread.valueOrNull;
      if (inquiry == null) {
        final msg = thread.errorOrNull?.userMessage ?? 'スレッドを開けませんでした';
        for (final d in entry.value) {
          failures.add(DetailSendFailure(d.recordId, msg));
        }
        done += entry.value.length;
        onProgress?.call(done, unique.length);
        continue;
      }

      final inThread = await _payloadKeysIn(inquiry.id);
      for (final d in entry.value) {
        final r = await _sendOne(
          shopId: shopId,
          shopName: shopName,
          senderId: senderId,
          inquiryId: inquiry.id,
          draft: d,
          inThread: inThread,
        );
        switch (r.$1) {
          case _Outcome.sent:
            sent.add(d.recordId);
            customers.add(d.customerId);
          case _Outcome.alreadySent:
            already++;
          case _Outcome.failed:
            failures.add(DetailSendFailure(d.recordId, r.$2 ?? '送れませんでした'));
        }
        done++;
        onProgress?.call(done, unique.length);
      }
    }

    return Result.success(DetailSendResult(
      sentRecordIds: sent,
      alreadySent: already,
      customers: customers.length,
      failures: failures,
    ));
  }

  Future<(_Outcome, String?)> _sendOne({
    required String shopId,
    required String shopName,
    required String senderId,
    required String inquiryId,
    required DetailDraft draft,
    required Set<String> inThread,
  }) async {
    try {
      final ref = _records(shopId).doc(draft.recordId);
      final current = await ref.get();
      if (!current.exists) {
        return (_Outcome.failed, '伝票が見つかりません（消された可能性があります）');
      }
      if (current.data()?['detailSentAt'] != null) {
        return (_Outcome.alreadySent, null);
      }

      final payload = draft.payload(shopName: shopName);
      final key = _payloadKey(payload);
      if (inThread.contains(key)) {
        await _mark(ref, inquiryId);
        return (_Outcome.alreadySent, null);
      }

      final r = await _inquiryService.sendMessage(
        inquiryId: inquiryId,
        senderId: senderId,
        isFromShop: true,
        content: maintenanceDetailMessage,
        maintenancePayload: payload.toMap(),
      );
      if (r.isFailure) return (_Outcome.failed, r.errorOrNull!.userMessage);
      inThread.add(key);
      await _mark(ref, inquiryId);
      return (_Outcome.sent, null);
    } catch (e) {
      return (_Outcome.failed, mapFirebaseError(e).userMessage);
    }
  }

  Future<void> _mark(
          DocumentReference<Map<String, dynamic>> ref, String inquiryId) =>
      ref.update({
        'detailSentAt': Timestamp.fromDate(_now()),
        'detailInquiryId': inquiryId,
      });

  /// スレッドに既にある明細（日付と金額）。
  Future<Set<String>> _payloadKeysIn(String inquiryId) async {
    final r = await _inquiryService.getMessages(inquiryId, limit: 500);
    final keys = <String>{};
    for (final m in r.valueOrNull ?? const []) {
      final raw = m.maintenancePayload;
      if (!m.isFromShop || raw == null) continue;
      keys.add(_payloadKey(InquiryMaintenancePayload.fromMap(raw)));
    }
    return keys;
  }

  static String _payloadKey(InquiryMaintenancePayload p) =>
      '${p.date.year}-${p.date.month}-${p.date.day}|${p.cost}';
}

enum _Outcome { sent, alreadySent, failed }
