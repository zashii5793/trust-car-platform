import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop_invite.dart';

/// Where a customer's shop link lives.
class ShopCustomerLink {
  final String shopId;
  final String shopName;
  final String userId;
  final DateTime linkedAt;

  const ShopCustomerLink({
    required this.shopId,
    required this.shopName,
    required this.userId,
    required this.linkedAt,
  });

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'shopName': shopName,
        'userId': userId,
        'linkedAt': Timestamp.fromDate(linkedAt),
      };

  factory ShopCustomerLink.fromMap(Map<String, dynamic> map) {
    final at = map['linkedAt'];
    return ShopCustomerLink(
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      linkedAt: at is Timestamp
          ? at.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Issues and redeems the codes a shop hands to its own customers.
///
/// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §4。**店が自分の顧客をアプリに
/// 載せる手段が無い**のが最大の穴だった。車検の入庫時に紙やQRで渡す。
///
/// **コードをドキュメントIDにしてある。** 検索クエリではなく ID 直引きなので、
/// セキュリティルールが単純になり（「そのIDを知っている人だけが読める」）、
/// 総当たりも Firestore 側で頭打ちになる。
class ShopInviteService {
  final FirebaseFirestore _firestore;

  ShopInviteService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  static const String invitesCollection = 'shop_invites';
  static const String customersCollection = 'shop_customers';

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection(invitesCollection);

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection(customersCollection);

  /// 顧客と店の紐づけのドキュメントID。
  ///
  /// **利用者IDだけで引ける形にしてある。** かかりつけは1件なので、
  /// 「この人のかかりつけはどこか」を1回の読み取りで出せる。
  String _linkId(String userId) => userId;

  /// 招待を作る。コードは重複しないものを選ぶ。
  Future<Result<ShopInvite, AppError>> createInvite({
    required String shopId,
    required String shopName,
    required String shopOwnerId,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    if (shopId.trim().isEmpty) {
      return const Result.failure(AppError.validation('店舗が特定できません'));
    }
    // 誰の招待か分からないコードを配ると、自分で自分の顧客になれてしまう。
    if (shopOwnerId.trim().isEmpty) {
      return const Result.failure(AppError.validation('店舗の管理者が特定できません'));
    }
    if (maxUses != null && maxUses <= 0) {
      return const Result.failure(AppError.validation('発行できる枚数は1以上にしてください'));
    }

    try {
      final now = DateTime.now();

      // 空いているコードを探す。ぶつかったら種を変えて引き直す。
      for (var attempt = 0; attempt < 12; attempt++) {
        final code = InviteCode.generate(
          seed: now.microsecondsSinceEpoch + attempt * 7919,
        );
        final doc = _invites.doc(code);
        final existing = await doc.get();
        if (existing.exists) continue;

        final invite = ShopInvite(
          code: code,
          shopId: shopId,
          shopName: shopName,
          shopOwnerId: shopOwnerId,
          createdAt: now,
          expiresAt: expiresAt,
          isActive: true,
          usedCount: 0,
          maxUses: maxUses,
        );
        await doc.set(invite.toMap());
        return Result.success(invite);
      }

      return const Result.failure(
        AppError.unknown('コードを発行できませんでした。もう一度お試しください'),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// コードから招待を引く。入力のゆれは吸収する。
  Future<Result<ShopInvite?, AppError>> findByCode(String code) async {
    final normalized = InviteCode.normalize(code);
    if (normalized.isEmpty) return const Result.success(null);

    try {
      final doc = await _invites.doc(normalized).get();
      if (!doc.exists) return const Result.success(null);
      return Result.success(ShopInvite.fromMap(doc.data()!, normalized));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 招待を使って、顧客を店に紐づける。
  Future<Result<ShopCustomerLink, AppError>> redeem({
    required String code,
    required String userId,
  }) async {
    final found = await findByCode(code);
    if (found.isFailure) {
      return Result.failure(found.errorOrNull ?? const AppError.unknown(''));
    }

    final invite = found.valueOrNull;
    if (invite == null) {
      return Result.failure(
          AppError.validation(InviteRejection.notFound.message));
    }

    final rejection = invite.canBeUsedBy(userId, now: DateTime.now());
    if (rejection != null) {
      return Result.failure(AppError.validation(rejection.message));
    }

    try {
      final linkRef = _customers.doc(_linkId(userId));
      final existing = await linkRef.get();

      // 同じ招待をもう一度使っても、使用回数は増やさない。
      // 増やすと上限が意味をなさなくなる。
      final alreadyOnThisShop = existing.exists &&
          (existing.data()?['shopId'] as String?) == invite.shopId;

      final link = ShopCustomerLink(
        shopId: invite.shopId,
        shopName: invite.shopName,
        userId: userId,
        linkedAt: DateTime.now(),
      );
      await linkRef.set(link.toMap());

      if (!alreadyOnThisShop) {
        await _invites.doc(invite.code).update({
          'usedCount': FieldValue.increment(1),
        });
      }

      return Result.success(link);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// この人のかかりつけの店。無ければ null。
  Future<Result<ShopCustomerLink?, AppError>> linkedShopFor(
      String userId) async {
    if (userId.trim().isEmpty) return const Result.success(null);

    try {
      final doc = await _customers.doc(_linkId(userId)).get();
      if (!doc.exists) return const Result.success(null);
      return Result.success(ShopCustomerLink.fromMap(doc.data()!));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 店に紐づいている顧客の一覧。
  Future<Result<List<ShopCustomerLink>, AppError>> customersOf(
      String shopId) async {
    if (shopId.trim().isEmpty) return const Result.success([]);

    try {
      final snapshot =
          await _customers.where('shopId', isEqualTo: shopId).get();
      return Result.success(
        snapshot.docs.map((d) => ShopCustomerLink.fromMap(d.data())).toList(),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 招待を止める。**すでに紐づいた顧客は外さない。**
  /// コードを配り直したいだけで、顧客を切りたいわけではないため。
  Future<Result<void, AppError>> deactivate(String code) async {
    final normalized = InviteCode.normalize(code);
    if (normalized.isEmpty) {
      return const Result.failure(AppError.validation('コードが指定されていません'));
    }

    try {
      await _invites.doc(normalized).update({'isActive': false});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
