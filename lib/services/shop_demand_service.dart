import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inquiry.dart';
import '../models/shop_inquiry_demand.dart';

/// Records and retrieves latent demand from users who attempted to contact
/// a non-partner shop (Issue #41 Phase 2 — freemium question gate).
///
/// When a shop is not a platform partner, the user's inquiry is NOT sent.
/// Instead, [recordDemand] persists a [ShopInquiryDemand] document so that
/// during shop onboarding the shop can see "N users tried to contact you",
/// creating a pull-type sales hook.
class ShopDemandService {
  static const _collection = FirestoreCollections.shopInquiryDemands;

  final FirebaseFirestore? _firestoreOverride;

  ShopDemandService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _demands =>
      _firestore.collection(_collection);

  /// Records a demand from [userId] who attempted to contact [shopId].
  ///
  /// Returns [AppError.validation] when required fields are empty.
  Future<Result<ShopInquiryDemand, AppError>> recordDemand({
    required String shopId,
    required String shopOwnerId,
    required String userId,
    required InquiryType type,
    required String subject,
    String? message,
    String? vehicleId,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty', field: 'shopId'),
      );
    }
    if (shopOwnerId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopOwnerId must not be empty',
            field: 'shopOwnerId'),
      );
    }
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.validation('userId must not be empty', field: 'userId'),
      );
    }
    if (subject.isEmpty) {
      return const Result.failure(
        AppError.validation('subject must not be empty', field: 'subject'),
      );
    }

    try {
      final now = DateTime.now();
      final demand = ShopInquiryDemand(
        id: '',
        shopId: shopId,
        shopOwnerId: shopOwnerId,
        userId: userId,
        type: type,
        subject: subject,
        message: message,
        vehicleId: vehicleId,
        createdAt: now,
      );

      final docRef = await _demands.add(demand.toFirestore());

      return Result.success(ShopInquiryDemand(
        id: docRef.id,
        shopId: shopId,
        shopOwnerId: shopOwnerId,
        userId: userId,
        type: type,
        subject: subject,
        message: message,
        vehicleId: vehicleId,
        createdAt: now,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Returns the total number of demand records for [shopId].
  ///
  /// Used during shop onboarding to display "N users tried to contact you".
  ///
  /// [shopOwnerId] must be the caller's own uid. `firestore.rules` only
  /// allows reading a demand when `resource.data.shopOwnerId == request.auth.uid`,
  /// and Firestore rejects a list query it cannot prove satisfies that rule.
  /// A query filtered by `shopId` alone is therefore denied in production
  /// (fake_cloud_firestore does not evaluate rules, so unit tests passed).
  Future<Result<int, AppError>> getDemandCountForShop(
    String shopId, {
    required String shopOwnerId,
  }) async {
    final invalid = _validateShopQuery(shopId, shopOwnerId);
    if (invalid != null) return Result.failure(invalid);

    try {
      final snapshot = await _demands
          .where('shopId', isEqualTo: shopId)
          .where('shopOwnerId', isEqualTo: shopOwnerId)
          .get();
      return Result.success(snapshot.docs.length);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Returns demand records for [shopId], ordered by creation date descending.
  ///
  /// Intended for the shop owner's onboarding screen to list captured demands.
  /// See [getDemandCountForShop] for why [shopOwnerId] is required.
  Future<Result<List<ShopInquiryDemand>, AppError>> getDemandsForShop(
    String shopId, {
    required String shopOwnerId,
  }) async {
    final invalid = _validateShopQuery(shopId, shopOwnerId);
    if (invalid != null) return Result.failure(invalid);

    try {
      final snapshot = await _demands
          .where('shopId', isEqualTo: shopId)
          .where('shopOwnerId', isEqualTo: shopOwnerId)
          .orderBy('createdAt', descending: true)
          .get();
      final demands = snapshot.docs
          .map((doc) => ShopInquiryDemand.fromFirestore(doc))
          .toList();
      return Result.success(demands);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  AppError? _validateShopQuery(String shopId, String shopOwnerId) {
    if (shopId.isEmpty) {
      return const AppError.validation('shopId must not be empty',
          field: 'shopId');
    }
    if (shopOwnerId.isEmpty) {
      return const AppError.validation('shopOwnerId must not be empty',
          field: 'shopOwnerId');
    }
    return null;
  }
}
