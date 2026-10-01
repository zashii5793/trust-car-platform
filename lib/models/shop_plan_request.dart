import 'package:cloud_firestore/cloud_firestore.dart';

import 'shop.dart';

/// 申し込みの状態。
///
/// アプリが書くのは `pending` だけ。受付後の状態（`completed` など）は
/// 運営者がサーバ側（Admin SDK）で書き換える。
enum ShopPlanRequestStatus {
  pending, // 受付中（担当が請求書・見積もりを準備する）
  completed, // プランの切り替えまで済んだ
  cancelled, // 取り下げ・不成立
  unknown, // 知らない値（将来の状態など）
  ;

  static ShopPlanRequestStatus fromString(String? value) {
    for (final s in values) {
      if (s != unknown && s.name == value) return s;
    }
    return unknown;
  }
}

/// 店舗プランの申し込み（`shops/{shopId}/plan_requests/{id}`）。
///
/// 2026-09-29 のオーナー判断で、店舗プランは当面、請求書払い（銀行振込）。
/// アプリはこの申し込みを置くだけで、`shops/{shopId}` の planType・
/// subscriptionStatus は変えない（ルールでも書けない）。
class ShopPlanRequest {
  final String id;
  final String shopId;

  /// 希望するプラン。フリーならダウングレード（解約）の申し込み。
  final ShopPlanType plan;

  /// 申し込んだ時点のプラン（運営者が見比べるため）。
  final ShopPlanType currentPlan;

  final String requesterUid;
  final String contactEmail;

  /// 請求書の宛名。
  final String billingName;

  final String? note;
  final ShopPlanRequestStatus status;
  final DateTime? createdAt;

  const ShopPlanRequest({
    required this.id,
    required this.shopId,
    required this.plan,
    required this.currentPlan,
    required this.requesterUid,
    required this.contactEmail,
    required this.billingName,
    this.note,
    required this.status,
    this.createdAt,
  });

  /// 個別見積もりの相談か（エンタープライズ）。
  bool get isQuote => plan.isCustomQuote;

  factory ShopPlanRequest.fromMap(
    String id,
    String shopId,
    Map<String, dynamic> m,
  ) =>
      ShopPlanRequest(
        id: id,
        shopId: shopId,
        plan: ShopPlanType.fromString(m['plan'] as String?),
        currentPlan: ShopPlanType.fromString(m['currentPlan'] as String?),
        requesterUid: m['requesterUid'] as String? ?? '',
        contactEmail: m['contactEmail'] as String? ?? '',
        billingName: m['billingName'] as String? ?? '',
        note: m['note'] as String?,
        status: ShopPlanRequestStatus.fromString(m['status'] as String?),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}
