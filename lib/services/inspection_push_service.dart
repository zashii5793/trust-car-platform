import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inspection_push_request.dart';

/// アプリを使っているお客さんへの車検案内（プッシュ通知）。
/// 2026-09-29 プロダクト評価 #2 の「アプリ有り」の側。
///
/// プッシュの送信には Admin SDK が要るので、クライアントからは送らない。
///
/// 1. 店のスタッフが `shops/{shopId}/inspection_notices` に依頼を置く（[request]）
/// 2. Cloud Functions（onInspectionNoticeCreated）が、車ごとに台帳の
///    つながり・利用者の通知設定・案内済みかを確かめて送り、送れた車に
///    「案内した日」を付ける（はがきの書き出しと同じ欄）
/// 3. 結果（何台に届いたか・届かなかった理由）を依頼の文書に書く。
///    画面は [watch] で待つ
class InspectionPushService {
  final FirebaseFirestore _firestore;

  InspectionPushService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// 1回の依頼で送れる車の台数（ルールの validInspectionNotice と同じ）。
  static const int maxVehicles = 200;

  CollectionReference<Map<String, dynamic>> _notices(String shopId) =>
      _firestore
          .collection('shops')
          .doc(shopId)
          .collection('inspection_notices');

  /// 依頼を置き、その ID を返す。同じ車が重なっていれば1台にまとめる。
  Future<Result<String, AppError>> request({
    required String shopId,
    required String requesterUid,
    required List<String> vehicleIds,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(
          AppError.validation('店舗が分かりません', field: 'shopId'));
    }
    if (requesterUid.isEmpty) {
      return const Result.failure(
          AppError.validation('ログインしてください', field: 'requesterUid'));
    }
    final ids = vehicleIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) {
      return const Result.failure(
          AppError.validation('送る車がありません', field: 'vehicleIds'));
    }
    if (ids.length > maxVehicles) {
      return const Result.failure(AppError.validation(
          '一度に送れるのは$maxVehicles台までです。期間を短くしてください',
          field: 'vehicleIds'));
    }
    try {
      final ref = await _notices(shopId).add({
        'requesterUid': requesterUid,
        'vehicleIds': ids,
        'status': InspectionPushStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Result.success(ref.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 依頼の様子。サーバーが結果を書くと isFinished になる。
  /// 文書が読めなくなったら（消された等）流れを閉じる。
  Stream<InspectionPushRequest> watch({
    required String shopId,
    required String noticeId,
  }) {
    return _notices(shopId)
        .doc(noticeId)
        .snapshots()
        .takeWhile((s) => s.exists && s.data() != null)
        .map((s) => InspectionPushRequest.fromMap(s.id, s.data()!));
  }
}
