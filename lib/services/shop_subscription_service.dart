import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/shop.dart';

/// Plan limits value object
class ShopPlanLimits {
  /// Max monthly inquiries a shop can receive. -1 = unlimited.
  final int maxMonthlyInquiries;

  /// Max photos a shop can upload. -1 = unlimited.
  final int maxPhotos;

  final bool hasPriorityDisplay;
  final bool hasMonthlyReport;

  /// Max number of shops an owner can manage.
  final int maxShops;

  const ShopPlanLimits({
    required this.maxMonthlyInquiries,
    required this.maxPhotos,
    required this.hasPriorityDisplay,
    required this.hasMonthlyReport,
    required this.maxShops,
  });
}

/// Service for BtoB shop subscription management.
///
/// Handles plan limit enforcement and subscription state updates.
/// RevenueCat webhook updates Firestore; this service reads that state.
class ShopSubscriptionService {
  final FirebaseFirestore _firestore;

  ShopSubscriptionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  CollectionReference<Map<String, dynamic>> get _inquiries =>
      _firestore.collection('inquiries');

  // ---------------------------------------------------------------------------
  // Plan limits (pure logic, no Firestore needed)
  // ---------------------------------------------------------------------------

  /// Returns the feature limits for the given plan type.
  ShopPlanLimits getPlanLimits(ShopPlanType planType) {
    switch (planType) {
      case ShopPlanType.free:
        return const ShopPlanLimits(
          maxMonthlyInquiries: 5,
          maxPhotos: 3,
          hasPriorityDisplay: false,
          hasMonthlyReport: false,
          maxShops: 1,
        );
      case ShopPlanType.standard:
        return const ShopPlanLimits(
          maxMonthlyInquiries: -1,
          maxPhotos: 20,
          hasPriorityDisplay: false,
          hasMonthlyReport: false,
          maxShops: 1,
        );
      case ShopPlanType.premium:
        return const ShopPlanLimits(
          maxMonthlyInquiries: -1,
          maxPhotos: -1,
          hasPriorityDisplay: true,
          hasMonthlyReport: true,
          maxShops: 1,
        );
      case ShopPlanType.enterprise:
        return const ShopPlanLimits(
          maxMonthlyInquiries: -1,
          maxPhotos: -1,
          hasPriorityDisplay: true,
          hasMonthlyReport: true,
          maxShops: 5,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Effective plan resolution
  // ---------------------------------------------------------------------------

  /// Returns the effective plan type for a shop, treating expired subscriptions as free.
  ShopPlanType _effectivePlan(
      ShopPlanType planType, ShopSubscriptionStatus status) {
    if (status == ShopSubscriptionStatus.active ||
        status == ShopSubscriptionStatus.trialing) {
      return planType;
    }
    return ShopPlanType.free;
  }

  // ---------------------------------------------------------------------------
  // canReceiveInquiry
  // ---------------------------------------------------------------------------

  /// Returns true if the shop can receive one more inquiry this month.
  Future<Result<bool, AppError>> canReceiveInquiry(String shopId) async {
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty', field: 'shopId'),
      );
    }

    try {
      final shopDoc = await _shops.doc(shopId).get();
      if (!shopDoc.exists) {
        return const Result.failure(
          AppError.notFound('Shop not found', resourceType: '店舗'),
        );
      }

      final data = shopDoc.data()!;
      final planType = ShopPlanType.fromString(data['planType']);
      final status =
          ShopSubscriptionStatus.fromString(data['subscriptionStatus']);
      final effective = _effectivePlan(planType, status);
      final limits = getPlanLimits(effective);

      if (limits.maxMonthlyInquiries < 0) {
        return const Result.success(true);
      }

      final countResult = await getMonthlyInquiryCount(shopId);
      if (countResult.isFailure) {
        return Result.failure(countResult.errorOrNull!);
      }

      return Result.success(
          countResult.valueOrNull! < limits.maxMonthlyInquiries);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // canAddPhoto
  // ---------------------------------------------------------------------------

  /// Returns true if the shop can add one more photo given [currentCount].
  Future<Result<bool, AppError>> canAddPhoto(
    String shopId, {
    required int currentCount,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty', field: 'shopId'),
      );
    }
    if (currentCount < 0) {
      return const Result.failure(
        AppError.validation('currentCount must not be negative',
            field: 'currentCount'),
      );
    }

    try {
      final shopDoc = await _shops.doc(shopId).get();
      if (!shopDoc.exists) {
        return const Result.failure(
          AppError.notFound('Shop not found', resourceType: '店舗'),
        );
      }

      final data = shopDoc.data()!;
      final planType = ShopPlanType.fromString(data['planType']);
      final status =
          ShopSubscriptionStatus.fromString(data['subscriptionStatus']);
      final effective = _effectivePlan(planType, status);
      final limits = getPlanLimits(effective);

      if (limits.maxPhotos < 0) {
        return const Result.success(true);
      }
      return Result.success(currentCount < limits.maxPhotos);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // updatePlan
  // ---------------------------------------------------------------------------

  /// Updates the shop's subscription plan in Firestore.
  ///
  /// Typically called from a Cloud Functions webhook after RevenueCat confirms payment.
  Future<Result<void, AppError>> updatePlan(
    String shopId, {
    required ShopPlanType newPlan,
    required ShopSubscriptionStatus subscriptionStatus,
    DateTime? expiresAt,
    String? revenueCatUserId,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty', field: 'shopId'),
      );
    }

    try {
      final Map<String, dynamic> updates = {
        'planType': newPlan.name,
        'subscriptionStatus': subscriptionStatus.name,
        'updatedAt': Timestamp.now(),
      };

      if (newPlan == ShopPlanType.free) {
        updates['planExpiresAt'] = null;
      } else if (expiresAt != null) {
        updates['planExpiresAt'] = Timestamp.fromDate(expiresAt);
      }

      if (revenueCatUserId != null) {
        updates['revenueCatUserId'] = revenueCatUserId;
      }

      await _shops.doc(shopId).update(updates);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // getMonthlyInquiryCount
  // ---------------------------------------------------------------------------

  /// Returns the number of inquiries received by [shopId] in the current calendar month.
  Future<Result<int, AppError>> getMonthlyInquiryCount(String shopId) async {
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty', field: 'shopId'),
      );
    }

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final snapshot = await _inquiries
          .where('shopId', isEqualTo: shopId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      return Result.success(snapshot.docs.length);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
