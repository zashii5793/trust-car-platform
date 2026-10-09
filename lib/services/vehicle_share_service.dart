import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/maintenance_record.dart';
import '../models/shop_ledger.dart';
import '../models/vehicle.dart';
import '../models/vehicle_share.dart';
import 'shop_ledger_service.dart';

/// ユーザーが、初めて行く店に「この車のこれまで」を渡す。
///
/// `docs/SHOP_CRM_DESIGN_2026-09-27.md` §7。
///
/// 書くのは2か所で、必ず一緒に書き、一緒に消す。
///
/// - `shops/{shopId}/shared_vehicles/{vehicleId}` … 店が読む写し
/// - `vehicle_sharing_permissions/{vehicleId}_{shopId}` … 本人が
///   「どこに渡しているか」を一覧するための索引（店のコレクションを
///   横断して探さずに済む）
class VehicleShareService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  VehicleShareService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  /// 渡せる期間の上限。長く開けっぱなしにしない。
  static const int maxDays = 90;

  /// 写しに入れる整備記録の上限（新しい順）。ドキュメントの大きさ（1MB）に
  /// 収めるため。10年乗っても年20件なら収まる。
  static const int maxRecords = 200;

  static const String _permissions = 'vehicle_sharing_permissions';

  CollectionReference<Map<String, dynamic>> _shares(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('shared_vehicles');

  static String _permissionId(String vehicleId, String shopId) =>
      '${vehicleId}_$shopId';

  /// 写しを作って渡す。同じ車を同じ店に渡し直したら上書きする。
  Future<Result<VehicleShare, AppError>> share({
    required String ownerId,
    required Vehicle vehicle,
    required String shopId,
    required String shopName,
    required List<MaintenanceRecord> records,
    required int days,
    bool includePlate = false,
    bool includeCosts = false,
    String? contactName,
    String? contactPhone,
    String? message,
  }) async {
    if (vehicle.userId != ownerId) {
      return const Result.failure(
        AppError.permission('自分の車だけを共有できます'),
      );
    }
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('共有するお店を選んでください', field: 'shop'),
      );
    }
    if (days < 1 || days > maxDays) {
      return const Result.failure(
        AppError.validation('共有する期間は1〜$maxDays日で選んでください', field: 'days'),
      );
    }

    String? trimmed(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    final now = _now();
    final share = VehicleShare(
      vehicleId: vehicle.id,
      shopId: shopId,
      shopName: shopName,
      ownerId: ownerId,
      contactName: trimmed(contactName),
      contactPhone: trimmed(contactPhone),
      message: trimmed(message),
      maker: vehicle.maker,
      model: vehicle.model,
      year: vehicle.year == 0 ? null : vehicle.year,
      grade: trimmed(vehicle.grade),
      plate: includePlate ? trimmed(vehicle.licensePlate) : null,
      mileage: vehicle.mileage,
      inspectionExpiry: vehicle.inspectionExpiryDate,
      records: [
        for (final r in sorted.take(maxRecords))
          SharedRecord(
            date: r.date,
            type: r.type.displayName,
            title: r.title,
            cost: includeCosts && r.hasCost ? r.cost : null,
            mileage: r.mileageAtService,
            shopName: r.shopName,
          ),
      ],
      includesCosts: includeCosts,
      sharedAt: now,
      expiresAt: now.add(Duration(days: days)),
    );

    try {
      final batch = _firestore.batch();
      batch.set(_shares(shopId).doc(vehicle.id), share.toMap());
      batch.set(
        _firestore
            .collection(_permissions)
            .doc(_permissionId(vehicle.id, shopId)),
        {
          'vehicleId': vehicle.id,
          'shopId': shopId,
          'shopName': shopName,
          'ownerId': ownerId,
          'isActive': true,
          'grantedAt': now.millisecondsSinceEpoch,
          'expiresAt': share.expiresAt.millisecondsSinceEpoch,
        },
      );
      await batch.commit();
      return Result.success(share);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 渡すのをやめる。写しと索引を両方消す。
  Future<Result<void, AppError>> revoke({
    required String vehicleId,
    required String shopId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_shares(shopId).doc(vehicleId));
      batch.delete(_firestore
          .collection(_permissions)
          .doc(_permissionId(vehicleId, shopId)));
      await batch.commit();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// この車を、いまどの店に渡しているか（期限切れは除く）。
  Future<Result<List<ActiveShare>, AppError>> activeSharesOf({
    required String ownerId,
    required String vehicleId,
  }) async {
    try {
      final snap = await _firestore
          .collection(_permissions)
          .where('ownerId', isEqualTo: ownerId)
          .where('vehicleId', isEqualTo: vehicleId)
          .where('isActive', isEqualTo: true)
          .get();
      final now = _now().millisecondsSinceEpoch;
      final list = <ActiveShare>[];
      for (final d in snap.docs) {
        final data = d.data();
        final exp = data['expiresAt'] as int?;
        if (exp != null && exp <= now) continue;
        list.add(ActiveShare(
          shopId: data['shopId'] as String? ?? '',
          shopName: data['shopName'] as String? ?? '',
          expiresAt:
              exp == null ? null : DateTime.fromMillisecondsSinceEpoch(exp),
        ));
      }
      return Result.success(list);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 店の側
  // ---------------------------------------------------------------------------

  /// 店に渡されている写し（新しい順・期限切れは除く）。
  ///
  /// 期限切れの写しは毎晩サーバーで消す。それまでの間も画面には出さない。
  Future<Result<List<VehicleShare>, AppError>> sharesForShop(
      String shopId) async {
    try {
      final snap = await _shares(shopId)
          .orderBy('sharedAt', descending: true)
          .limit(ShopLedgerService.pageSize * 5)
          .get();
      final now = _now();
      return Result.success(snap.docs
          .map((d) => VehicleShare.fromMap(d.data()))
          .where((s) => !s.isExpiredAt(now))
          .toList());
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 店が開いたことを記録する（ユーザーの画面で「見られた」が分かるように）。
  Future<void> markSeen({
    required String shopId,
    required String vehicleId,
  }) async {
    try {
      await _shares(shopId)
          .doc(vehicleId)
          .update({'seenAt': Timestamp.fromDate(_now())});
    } catch (_) {
      // 既読は付かなくても困らない。写しを読む邪魔をしない。
    }
  }

  /// 写しから台帳に顧客と車両を登録する。
  ///
  /// 名前が渡されていなければ「（お名前未共有）」で登録する。
  /// **勝手に名前を推測しない。** 店があとで聞いて直す。
  Future<Result<String, AppError>> importToLedger({
    required ShopLedgerService ledger,
    required VehicleShare share,
  }) async {
    final customer = await ledger.createCustomer(
      shopId: share.shopId,
      // 写しには個人か法人かが入っていない。個人で登録し、店が直す
      kind: LedgerCustomerKind.individual,
      name: share.contactName ?? '（お名前未共有）',
      phone: share.contactPhone,
      note: share.message == null ? null : 'アプリから共有: ${share.message}',
    );
    if (customer.isFailure) return Result.failure(customer.errorOrNull!);
    final c = customer.valueOrNull!;

    final vehicle = await ledger.saveVehicle(
      shopId: share.shopId,
      customerId: c.id,
      maker: share.maker,
      model: share.model,
      plate: share.plate,
      year: share.year,
      inspectionExpiry: share.inspectionExpiry,
      lastMileage: share.mileage,
      // 他店での整備日は「この店に来た日」ではないので、最終来店には入れない
    );
    if (vehicle.isFailure) return Result.failure(vehicle.errorOrNull!);

    try {
      await _shares(share.shopId)
          .doc(share.vehicleId)
          .update({'importedCustomerId': c.id});
    } catch (_) {
      // 登録自体は済んでいる。印が付かなくても台帳は正しい。
    }
    return Result.success(c.id);
  }
}
