import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inspection_pipeline.dart';
import '../models/shop_invite.dart';

/// Where a customer's shop link lives.
///
/// **店に渡るのはこれだけ。** 車検の満了日と台数のほかは、車種も走行距離も
/// 整備履歴も入っていない（`docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2 案A）。
class ShopCustomerLink {
  final String shopId;
  final String shopName;
  final String userId;
  final DateTime linkedAt;

  /// 店に伝えている車検満了日。**日付だけ。どの車のものかは渡さない。**
  final List<DateTime> inspectionExpiries;

  /// 保有台数。[inspectionExpiries] との差が「満了日が未入力の台数」になる。
  final int vehicleCount;

  /// 満了日を店に伝えることに同意しているか。あとから切れる。
  final bool sharesInspectionExpiry;

  /// 満了日を最後に書き込んだ時刻。**古い数字を新しい顔で見せないため。**
  final DateTime? expiryUpdatedAt;

  const ShopCustomerLink({
    required this.shopId,
    required this.shopName,
    required this.userId,
    required this.linkedAt,
    this.inspectionExpiries = const [],
    this.vehicleCount = 0,
    this.sharesInspectionExpiry = true,
    this.expiryUpdatedAt,
  });

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'shopName': shopName,
        'userId': userId,
        'linkedAt': Timestamp.fromDate(linkedAt),
        'inspectionExpiries':
            inspectionExpiries.map((d) => Timestamp.fromDate(d)).toList(),
        'vehicleCount': vehicleCount,
        'sharesInspectionExpiry': sharesInspectionExpiry,
        if (expiryUpdatedAt != null)
          'expiryUpdatedAt': Timestamp.fromDate(expiryUpdatedAt!),
      };

  factory ShopCustomerLink.fromMap(Map<String, dynamic> map) {
    final at = map['linkedAt'];
    final updated = map['expiryUpdatedAt'];
    final raw = map['inspectionExpiries'];

    return ShopCustomerLink(
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      linkedAt: at is Timestamp
          ? at.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      inspectionExpiries: raw is List
          ? raw.whereType<Timestamp>().map((t) => t.toDate()).toList()
          : const [],
      vehicleCount: (map['vehicleCount'] as num?)?.toInt() ?? 0,
      // 招待コード導入時の文書にはこの項目が無い。同意した上で入れた導線なので
      // 既定は true。切りたい人は画面から切れる。
      sharesInspectionExpiry: map['sharesInspectionExpiry'] as bool? ?? true,
      expiryUpdatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  /// 店側の集計に渡す形。
  CustomerExpirySummary toExpirySummary() => CustomerExpirySummary(
        expiries: inspectionExpiries,
        vehicleCount: vehicleCount,
        isSharing: sharesInspectionExpiry,
      );

  ShopCustomerLink copyWith({
    List<DateTime>? inspectionExpiries,
    int? vehicleCount,
    bool? sharesInspectionExpiry,
    DateTime? expiryUpdatedAt,
  }) {
    return ShopCustomerLink(
      shopId: shopId,
      shopName: shopName,
      userId: userId,
      linkedAt: linkedAt,
      inspectionExpiries: inspectionExpiries ?? this.inspectionExpiries,
      vehicleCount: vehicleCount ?? this.vehicleCount,
      sharesInspectionExpiry:
          sharesInspectionExpiry ?? this.sharesInspectionExpiry,
      expiryUpdatedAt: expiryUpdatedAt ?? this.expiryUpdatedAt,
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

  /// Reads the wall clock. Injectable so tests - golden shots in particular -
  /// can pin a date: the linked screen prints the day it was shared, which would
  /// otherwise make the image differ every day.
  final DateTime Function() _now;

  ShopInviteService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

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
      final now = _now();

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

    final rejection = invite.canBeUsedBy(userId, now: _now());
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

      // 店を替えても、共有の可否と満了日は本人のものなので引き継ぐ。
      // 上書きで消すと、切ったはずの共有が既定の true に戻ってしまう。
      final previous =
          existing.exists ? ShopCustomerLink.fromMap(existing.data()!) : null;

      final link = ShopCustomerLink(
        shopId: invite.shopId,
        shopName: invite.shopName,
        userId: userId,
        linkedAt: _now(),
        inspectionExpiries: previous?.inspectionExpiries ?? const [],
        vehicleCount: previous?.vehicleCount ?? 0,
        sharesInspectionExpiry: previous?.sharesInspectionExpiry ?? true,
        expiryUpdatedAt: previous?.expiryUpdatedAt,
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

  /// 一度に店へ渡す満了日の上限。
  ///
  /// 個人が持つ台数を超える数を書けるようにしても得が無く、
  /// 名簿の代わりに使われる余地を残すだけ。`firestore.rules` でも同じ数で止める。
  static const int maxSharedExpiries = 20;

  /// 車検の満了日だけを、かかりつけの店に渡す。
  ///
  /// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2 の案A。
  ///
  /// 店は顧客の `vehicles` を読めない。読めるようにすると走行距離も整備履歴も
  /// 渡ってしまう。**そこは開けず、必要な値だけを顧客側が置く。**
  ///
  /// かかりつけが無い人、共有を切っている人には何も書かない（成功として返す）。
  Future<Result<void, AppError>> shareInspectionExpiries({
    required String userId,
    required List<DateTime?> expiryDates,
    required int vehicleCount,
  }) async {
    if (userId.trim().isEmpty) return const Result.success(null);

    try {
      final linkRef = _customers.doc(_linkId(userId));
      final snapshot = await linkRef.get();
      if (!snapshot.exists) return const Result.success(null);

      final link = ShopCustomerLink.fromMap(snapshot.data()!);
      if (!link.sharesInspectionExpiry) return const Result.success(null);

      final expiries = expiryDates.whereType<DateTime>().toList()..sort();
      final capped = expiries.take(maxSharedExpiries).toList();
      final count =
          vehicleCount < 0 ? 0 : (vehicleCount > 99 ? 99 : vehicleCount);

      // 中身が変わっていなければ書かない。開くたびに書き込むと、
      // 「最終更新」が更新だけで動いて、実際の鮮度が分からなくなる。
      if (_sameDates(link.inspectionExpiries, capped) &&
          link.vehicleCount == count) {
        return const Result.success(null);
      }

      await linkRef.set({
        'inspectionExpiries': capped.map((d) => Timestamp.fromDate(d)).toList(),
        'vehicleCount': count,
        'expiryUpdatedAt': Timestamp.fromDate(_now()),
      }, SetOptions(merge: true));

      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 満了日の共有を入り切りする。
  ///
  /// **切ったときは、すでに渡した満了日も消す。** 「今後は渡さない」だけで
  /// 過去の分が店に残るのでは、切った意味がない。
  Future<Result<ShopCustomerLink?, AppError>> setExpirySharing({
    required String userId,
    required bool enabled,
  }) async {
    if (userId.trim().isEmpty) return const Result.success(null);

    try {
      final linkRef = _customers.doc(_linkId(userId));
      final snapshot = await linkRef.get();
      if (!snapshot.exists) return const Result.success(null);

      await linkRef.set({
        'sharesInspectionExpiry': enabled,
        if (!enabled) 'inspectionExpiries': <Timestamp>[],
        if (!enabled) 'vehicleCount': 0,
        'expiryUpdatedAt': Timestamp.fromDate(_now()),
      }, SetOptions(merge: true));

      final updated = await linkRef.get();
      return Result.success(ShopCustomerLink.fromMap(updated.data()!));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  static bool _sameDates(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!a[i].isAtSameMomentAs(b[i])) return false;
    }
    return true;
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
