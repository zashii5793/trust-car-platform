import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop_invite.dart';

/// 店のスタッフ1人。`shops/{shopId}/members/{uid}`
class ShopStaffMember {
  final String uid;
  final String role;
  final String displayName;
  final DateTime? addedAt;

  const ShopStaffMember({
    required this.uid,
    required this.role,
    required this.displayName,
    this.addedAt,
  });

  bool get isOwner => role == 'owner';

  factory ShopStaffMember.fromMap(String uid, Map<String, dynamic> m) =>
      ShopStaffMember(
        uid: uid,
        role: m['role'] as String? ?? 'staff',
        displayName: m['displayName'] as String? ?? 'スタッフ',
        addedAt: (m['addedAt'] as Timestamp?)?.toDate(),
      );
}

/// スタッフとして入っている店（`shop_staff/{uid}`）。
///
/// スタッフの端末から「自分はどの店のスタッフか」を1回の読み取りで引く
/// ための札。店は店主（ownerId）で決まり、店のドキュメントIDからも名簿からも
/// スタッフの uid では店が引けない。
class StaffShopLink {
  final String shopId;
  final String shopName;

  const StaffShopLink({required this.shopId, required this.shopName});
}

/// スタッフ用の招待コード（`shop_staff_invites/{code}`）。
class StaffInvite {
  final String code;
  final String shopId;
  final String shopName;
  final DateTime expiresAt;
  final String? usedBy;

  const StaffInvite({
    required this.code,
    required this.shopId,
    required this.shopName,
    required this.expiresAt,
    this.usedBy,
  });
}

/// 店のスタッフを増やす・外す（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §4-1）。
///
/// 顧客台帳は何千人分になるので、店主ひとりのアカウントでは回らない。
/// 店主がコードを発行し、スタッフが自分のアプリで入れると、その店の
/// 顧客台帳を開けるようになる。
///
/// **コードは1回限り・7日間。** 使い回されると、誰がスタッフになったかが
/// 分からなくなる。
class ShopStaffService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  ShopStaffService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  static const Duration validFor = Duration(days: 7);

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('shop_staff_invites');

  CollectionReference<Map<String, dynamic>> _members(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('members');

  DocumentReference<Map<String, dynamic>> _link(String uid) =>
      _firestore.collection('shop_staff').doc(uid);

  /// 店主がコードを発行する。
  Future<Result<StaffInvite, AppError>> issue({
    required String shopId,
    required String shopName,
    required String issuedBy,
  }) async {
    if (shopId.isEmpty || issuedBy.isEmpty) {
      return const Result.failure(AppError.validation('店舗が特定できません'));
    }
    try {
      final now = _now();
      for (var attempt = 0; attempt < 12; attempt++) {
        final code = InviteCode.generate(
          seed: now.microsecondsSinceEpoch + attempt * 7919 + 17,
        );
        final ref = _invites.doc(code);
        if ((await ref.get()).exists) continue;
        final invite = StaffInvite(
          code: code,
          shopId: shopId,
          shopName: shopName,
          expiresAt: now.add(validFor),
        );
        await ref.set({
          'shopId': shopId,
          'shopName': shopName,
          'issuedBy': issuedBy,
          'createdAt': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(invite.expiresAt),
          'usedBy': null,
        });
        return Result.success(invite);
      }
      return const Result.failure(
        AppError.unknown('コードを発行できませんでした。もう一度お試しください'),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// スタッフがコードを入れて、店に入る。
  ///
  /// コードの使用・スタッフ名簿・スタッフの札を1回のバッチで書く
  /// （途中で止まると「コードは使ったのに入れていない」になるため）。
  Future<Result<StaffShopLink, AppError>> redeem({
    required String code,
    required String uid,
    required String displayName,
  }) async {
    final normalized = InviteCode.normalize(code);
    if (normalized.length != InviteCode.length) {
      return const Result.failure(
        AppError.validation('コードは6文字です', field: 'code'),
      );
    }
    try {
      final ref = _invites.doc(normalized);
      final doc = await ref.get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return const Result.failure(
          AppError.notFound('このコードは見つかりません'),
        );
      }
      final expires = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expires == null || !expires.isAfter(_now())) {
        return const Result.failure(
          AppError.validation('このコードは期限が切れています。店主に発行し直してもらってください'),
        );
      }
      if (data['usedBy'] != null) {
        return const Result.failure(
          AppError.validation('このコードは使用済みです。店主に発行し直してもらってください'),
        );
      }
      final shopId = data['shopId'] as String;
      final shopName = data['shopName'] as String? ?? '';
      final now = Timestamp.fromDate(_now());
      final batch = _firestore.batch();
      batch.update(ref, {'usedBy': uid, 'usedAt': now});
      batch.set(_members(shopId).doc(uid), {
        'role': 'staff',
        'displayName': displayName.trim().isEmpty ? 'スタッフ' : displayName,
        'inviteCode': normalized,
        'addedAt': now,
      });
      batch.set(_link(uid), {'shopId': shopId, 'shopName': shopName});
      await batch.commit();
      return Result.success(StaffShopLink(shopId: shopId, shopName: shopName));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 自分がスタッフとして入っている店。入っていなければ null。
  Future<Result<StaffShopLink?, AppError>> myShop(String uid) async {
    try {
      final doc = await _link(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return const Result.success(null);
      return Result.success(StaffShopLink(
        shopId: data['shopId'] as String? ?? '',
        shopName: data['shopName'] as String? ?? '',
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<Result<List<ShopStaffMember>, AppError>> members(String shopId) async {
    try {
      final snap = await _members(shopId).get();
      final list = snap.docs
          .map((d) => ShopStaffMember.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return Result.success(list);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// スタッフを外す（店主）／自分で抜ける（スタッフ）。名簿と札を一緒に消す。
  Future<Result<void, AppError>> remove({
    required String shopId,
    required String uid,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_members(shopId).doc(uid));
      batch.delete(_link(uid));
      await batch.commit();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 店主を、スタッフの1人に引き継ぐ（2026-09-29）。
  ///
  /// 店のドキュメントIDは変えない（台帳・履歴・
  /// 問い合わせ・課金がこのIDにぶら下がっているため）。替えるのは ownerId と
  /// スタッフ名簿の役割だけ。**前の店主はスタッフとして残す**（すぐに締め
  /// 出さない。新しい店主があとで外せる）。
  ///
  /// 1回のバッチで書く（途中で止まると店主が2人・0人になるため）。
  Future<Result<void, AppError>> transferOwnership({
    required String shopId,
    required String shopName,
    required String fromUid,
    required String fromName,
    required String toUid,
  }) async {
    if (fromUid == toUid) {
      return const Result.failure(AppError.validation('自分には引き継げません'));
    }
    try {
      final to = await _members(shopId).doc(toUid).get();
      if (!to.exists) {
        return const Result.failure(
          AppError.validation('引き継げるのは、この店のスタッフだけです'),
        );
      }
      final now = Timestamp.fromDate(_now());
      final batch = _firestore.batch();
      batch.update(_firestore.collection('shops').doc(shopId), {
        'ownerId': toUid,
        'updatedAt': now,
      });
      batch.update(_members(shopId).doc(toUid), {'role': 'owner'});
      batch.set(_members(shopId).doc(fromUid), {
        'role': 'staff',
        'displayName': fromName.trim().isEmpty ? '前の店主' : fromName,
        'addedAt': now,
      });
      // 前の店主は、掲載管理の「スタッフの方」の入口から台帳を開けるように
      batch.set(_link(fromUid), {'shopId': shopId, 'shopName': shopName});
      // 新しい店主は、自分の店として開くので、スタッフの札は要らない
      batch.delete(_link(toUid));
      await batch.commit();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
