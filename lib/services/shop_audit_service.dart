import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import 'shop_ledger_service.dart';

/// 店側の操作の種類。
enum ShopAuditAction {
  viewCustomer('顧客を見た'),
  createCustomer('顧客を登録した'),
  updateCustomer('顧客を直した'),
  deleteCustomer('顧客を消した'),
  saveVehicle('車両を登録・直した'),
  deleteVehicle('車両を消した'),
  importRoster('名簿を取り込んだ'),
  importHistory('整備履歴を取り込んだ'),
  issueCustomerInvite('顧客専用のコードを出した'),
  sendDetail('整備明細を送った'),
  importShared('共有された車を登録した'),

  /// 書き出しは個人情報の持ち出し。**誰がいつ何件持ち出したか**を残す。
  exportLedger('台帳を書き出した'),
  exportInspectionNotice('車検案内の宛名を書き出した'),

  /// アプリを使っているお客さんへの車検案内（プッシュ）を依頼した。
  sendInspectionPush('アプリに車検案内を送った');

  final String label;
  const ShopAuditAction(this.label);

  static ShopAuditAction? fromName(String? n) {
    for (final a in values) {
      if (a.name == n) return a;
    }
    return null;
  }
}

/// 画面から操作を記録する関数。台帳の画面に渡す（渡さなければ記録しない）。
typedef AuditRecorder = void Function(
  ShopAuditAction action, {
  String? targetId,
  String? targetLabel,
  String? detail,
});

/// 操作の記録1件。
class ShopAuditEntry {
  final String actorUid;
  final String actorName;
  final ShopAuditAction? action;
  final String? targetId;
  final String? targetLabel;
  final String? detail;
  final DateTime at;

  const ShopAuditEntry({
    required this.actorUid,
    required this.actorName,
    required this.action,
    this.targetId,
    this.targetLabel,
    this.detail,
    required this.at,
  });

  factory ShopAuditEntry.fromMap(Map<String, dynamic> m) => ShopAuditEntry(
        actorUid: m['actorUid'] as String? ?? '',
        actorName: m['actorName'] as String? ?? '',
        action: ShopAuditAction.fromName(m['action'] as String?),
        targetId: m['targetId'] as String?,
        targetLabel: m['targetLabel'] as String?,
        detail: m['detail'] as String?,
        at: (m['at'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 店側の操作の記録（`shops/{shopId}/audit_logs`）。
///
/// 顧客の個人情報を預かる以上、**「誰がいつこの顧客を見たか」を店主が
/// 確かめられる**ことが、法人に売るときの前提になる
/// （2026-09-29 のプロダクト評価 #10）。
///
/// - 書けるのは店のスタッフ（店主を含む）で、自分の名前でだけ
/// - 読めるのは店主だけ
/// - **後から書き換え・削除はできない**（ルールで止める）
///
/// 記録に失敗しても、元の操作は止めない（記録のために仕事を止めない）。
class ShopAuditService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  ShopAuditService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  CollectionReference<Map<String, dynamic>> _logs(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('audit_logs');

  Future<void> record({
    required String shopId,
    required String actorUid,
    required String actorName,
    required ShopAuditAction action,
    String? targetId,
    String? targetLabel,
    String? detail,
  }) async {
    if (shopId.isEmpty || actorUid.isEmpty) return;
    try {
      await _logs(shopId).add({
        'actorUid': actorUid,
        'actorName': actorName,
        'action': action.name,
        if (targetId != null) 'targetId': targetId,
        if (targetLabel != null) 'targetLabel': targetLabel,
        if (detail != null) 'detail': detail,
        'at': Timestamp.fromDate(_now()),
      });
    } catch (_) {
      // 記録の失敗で、店の仕事を止めない
    }
  }

  /// 新しい順に1ページ。[customerId] を渡せば、その顧客に関するものだけ。
  Future<Result<LedgerPage<ShopAuditEntry>, AppError>> list({
    required String shopId,
    String? customerId,
    Object? cursor,
    int limit = ShopLedgerService.pageSize,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _logs(shopId);
      if (customerId != null) q = q.where('targetId', isEqualTo: customerId);
      q = q.orderBy('at', descending: true);
      if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
      final snap = await q.limit(limit + 1).get();
      final docs = snap.docs;
      final hasMore = docs.length > limit;
      final page = hasMore ? docs.sublist(0, limit) : docs;
      return Result.success(LedgerPage(
        items: page.map((d) => ShopAuditEntry.fromMap(d.data())).toList(),
        cursor: page.isEmpty ? cursor : page.last,
        hasMore: hasMore,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// [shopId] の店で [actorUid] として記録する関数を作る。
  AuditRecorder recorderFor({
    required String shopId,
    required String actorUid,
    required String actorName,
  }) =>
      (action, {targetId, targetLabel, detail}) => record(
            shopId: shopId,
            actorUid: actorUid,
            actorName: actorName,
            action: action,
            targetId: targetId,
            targetLabel: targetLabel,
            detail: detail,
          );
}
