import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inquiry.dart';

/// 顧客台帳の顧客と、アプリの利用者をつなぐ（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §6）。
///
/// 1. 店が顧客詳細で「この人専用のコード」を出す（ShopInviteService.createInvite
///    に customerId を渡す）
/// 2. お客さんがアプリでコードを入れる → 札（shop_customers）に customerId が入る
/// 3. 店が顧客詳細を開いたときに [syncLink] で札を探し、台帳に「アプリ利用中」を付ける
///
/// つながったお客さんには、店から問い合わせのスレッドを開いて整備明細を
/// 送れる（受け取った側は「記録に追加」で、工場の記録として取り込める）。
class LedgerLinkService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  LedgerLinkService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  /// この顧客宛てのコードが使われていれば、台帳の顧客にアプリの利用者を
  /// つなぎ、その利用者の uid を返す。まだなら null。
  Future<Result<String?, AppError>> syncLink({
    required String shopId,
    required String customerId,
  }) async {
    try {
      final snap = await _firestore
          .collection('shop_customers')
          .where('shopId', isEqualTo: shopId)
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return const Result.success(null);
      final userId = snap.docs.first.id;
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .doc(customerId)
          .update({
        'linkedUserId': userId,
        'isLinked': true,
        'updatedAt': Timestamp.fromDate(_now()),
      });
      return Result.success(userId);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// つながったお客さんとのスレッド。前に店から開いたものがあればそれを、
  /// 無ければ新しく開く。
  Future<Result<Inquiry, AppError>> openThread({
    required String shopId,
    required String shopName,
    required String userId,
  }) async {
    try {
      final col = _firestore.collection('inquiries');
      final existing = await col
          .where('shopId', isEqualTo: shopId)
          .where('userId', isEqualTo: userId)
          .where('openedByShop', isEqualTo: true)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return Result.success(Inquiry.fromFirestore(existing.docs.first));
      }

      final now = _now();
      final ref = col.doc();
      final inquiry = Inquiry(
        id: ref.id,
        userId: userId,
        shopId: shopId,
        type: InquiryType.general,
        subject: '整備明細のお届け',
        initialMessage: '$shopName から整備明細をお送りします。'
            '届いた明細は「記録に追加」から保存できます。',
        shopName: shopName,
        createdAt: now,
        updatedAt: now,
        // 店から開いたので、読んでいないのはお客さんの側
        unreadCountUser: 1,
        unreadCountShop: 0,
      );
      await ref.set({...inquiry.toMap(), 'openedByShop': true});
      return Result.success(inquiry);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
