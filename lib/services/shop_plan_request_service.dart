import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop.dart';
import '../models/shop_plan_request.dart';

/// 店舗プランの申し込み（請求書払い）。
///
/// 2026-09-29: 店舗プランは当面、請求書払い（銀行振込）。10店舗程度に
/// なったらクレジット決済を足す（特商法・利用規約 第11条）。
///
/// - アプリは `shops/{shopId}/plan_requests` に申し込みを置くだけ
/// - 書けるのは店主だけ。作ったあとは書き換え・削除できない（ルールで止める）
/// - プランの切り替え（planType・subscriptionStatus）は、入金を確かめてから
///   運営者がサーバ側で行う。**このサービスは店のドキュメントに触らない**
class ShopPlanRequestService {
  final FirebaseFirestore? _firestoreOverride;

  ShopPlanRequestService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  /// テストで Firebase.initializeApp() を呼ばずに作れるよう、遅れて解決する。
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const int maxBillingNameLength = 100;
  static const int maxNoteLength = 1000;

  // ルール側（firestore.rules の validPlanRequest）と同じ粗さで見る。
  // 空白を含まない「x@y.z」の形だけ確かめる。
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  CollectionReference<Map<String, dynamic>> _requests(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('plan_requests');

  /// メールアドレスとして受け付けられる形か（画面の入力チェックでも使う）。
  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  /// 申し込みを置く。
  Future<Result<ShopPlanRequest, AppError>> submit({
    required String shopId,
    required String requesterUid,
    required ShopPlanType plan,
    required ShopPlanType currentPlan,
    required String contactEmail,
    required String billingName,
    String? note,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(
          AppError.validation('店舗が分かりません', field: 'shopId'));
    }
    if (requesterUid.isEmpty) {
      return const Result.failure(
          AppError.validation('ログインしてください', field: 'requesterUid'));
    }
    if (plan == currentPlan) {
      return const Result.failure(
          AppError.validation('いまと同じプランです', field: 'plan'));
    }
    final email = contactEmail.trim();
    if (!isValidEmail(email)) {
      return const Result.failure(
          AppError.validation('メールアドレスを確認してください', field: 'contactEmail'));
    }
    final name = billingName.trim();
    if (name.isEmpty || name.length > maxBillingNameLength) {
      return const Result.failure(
          AppError.validation('請求書の宛名を確認してください', field: 'billingName'));
    }
    final trimmedNote = note?.trim() ?? '';
    if (trimmedNote.length > maxNoteLength) {
      return const Result.failure(
          AppError.validation('ご要望が長すぎます', field: 'note'));
    }

    try {
      final ref = await _requests(shopId).add({
        'plan': plan.name,
        'currentPlan': currentPlan.name,
        'requesterUid': requesterUid,
        'contactEmail': email,
        'billingName': name,
        if (trimmedNote.isNotEmpty) 'note': trimmedNote,
        'status': ShopPlanRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Result.success(ShopPlanRequest(
        id: ref.id,
        shopId: shopId,
        plan: plan,
        currentPlan: currentPlan,
        requesterUid: requesterUid,
        contactEmail: email,
        billingName: name,
        note: trimmedNote.isEmpty ? null : trimmedNote,
        status: ShopPlanRequestStatus.pending,
        createdAt: DateTime.now(),
      ));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const Result.failure(AppError.permission('プランを申し込めるのは店主だけです'));
      }
      return Result.failure(AppError.server('申し込みの送信に失敗しました: $e'));
    } catch (e) {
      return Result.failure(AppError.server('申し込みの送信に失敗しました: $e'));
    }
  }

  /// 受付中の申し込みのうち、いちばん新しいもの。無ければ null。
  ///
  /// 状態だけで絞り、並べ替えは手元でする（複合インデックスを増やさない）。
  Future<Result<ShopPlanRequest?, AppError>> latestPending(
      String shopId) async {
    if (shopId.isEmpty) {
      return const Result.failure(
          AppError.validation('店舗が分かりません', field: 'shopId'));
    }
    try {
      final snap = await _requests(shopId)
          .where('status', isEqualTo: ShopPlanRequestStatus.pending.name)
          .get();
      final items = snap.docs
          .map((d) => ShopPlanRequest.fromMap(d.id, shopId, d.data()))
          .toList()
        ..sort((a, b) {
          final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
      return Result.success(items.isEmpty ? null : items.first);
    } catch (e) {
      return Result.failure(AppError.server('申し込み状況の取得に失敗しました: $e'));
    }
  }
}
