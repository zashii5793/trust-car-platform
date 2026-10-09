import '../core/error/app_error.dart';
import '../core/result/result.dart';
import 'shop_service.dart';
import 'shop_staff_service.dart';

/// The shop a signed-in person works at.
class ShopEntry {
  final String shopId;
  final String shopName;

  /// True for the owner, false for staff.
  final bool isOwner;

  /// The current owner's uid (for staff, read from the shop). Null when the
  /// shop could not be read.
  final String? ownerUid;

  const ShopEntry({
    required this.shopId,
    required this.shopName,
    required this.isOwner,
    required this.ownerUid,
  });
}

/// Decides, right after sign-in, whether the person is a shop owner or
/// staff (2026-10-08 usability test: an owner signing in landed on the
/// customer's "My car" screen and needed five taps to reach the ledger).
///
/// Owner wins over staff. Two small reads: the shop by owner, then the
/// staff link (`shop_staff/{uid}`).
class ShopEntryService {
  final ShopService _shopService;
  final ShopStaffService _staffService;

  ShopEntryService({
    required ShopService shopService,
    required ShopStaffService staffService,
  })  : _shopService = shopService,
        _staffService = staffService;

  Future<Result<ShopEntry?, AppError>> resolve(String uid) async {
    if (uid.isEmpty) return const Result.success(null);

    final owned = await _shopService.getMyShop(uid);
    if (owned.isFailure) return Result.failure(owned.errorOrNull!);
    final shop = owned.valueOrNull;
    if (shop != null) {
      return Result.success(ShopEntry(
        shopId: shop.id,
        shopName: shop.name,
        isOwner: true,
        ownerUid: shop.ownerId ?? uid,
      ));
    }

    final staff = await _staffService.myShop(uid);
    if (staff.isFailure) return Result.failure(staff.errorOrNull!);
    final link = staff.valueOrNull;
    if (link == null || link.shopId.isEmpty) return const Result.success(null);

    // The shop document id is not the owner's uid (ownership can be
    // handed over, and new shops get automatic ids), so read the owner.
    final linked = await _shopService.getShop(link.shopId);
    return Result.success(ShopEntry(
      shopId: link.shopId,
      shopName: linked.valueOrNull?.name ?? link.shopName,
      isOwner: false,
      ownerUid: linked.valueOrNull?.ownerId,
    ));
  }
}
