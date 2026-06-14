import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// Manages user-to-shop permission grants for vehicle maintenance history.
///
/// Privacy design:
/// - Each permission is stored in `vehicle_sharing_permissions/{vehicleId}_{shopId}`
/// - Only the vehicle owner (ownerId) can grant or revoke access
/// - Shops read a list of permitted vehicles to surface in their dashboard
/// - Permissions can expire via [expiresAt] (e.g., one-time inspection)
class VehicleHistorySharingService {
  final FirebaseFirestore _firestore;

  static const _collection = 'vehicle_sharing_permissions';

  VehicleHistorySharingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static String _docId(String vehicleId, String shopId) =>
      '${vehicleId}_$shopId';

  /// Grants [shopId] read access to [vehicleId]'s maintenance history.
  Future<Result<void, AppError>> grantPermission({
    required String vehicleId,
    required String shopId,
    required String ownerId,
    DateTime? expiresAt,
  }) async {
    if (vehicleId.isEmpty) {
      return const Result.failure(
        AppError.validation('vehicleId must not be empty'),
      );
    }
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty'),
      );
    }
    if (ownerId.isEmpty) {
      return const Result.failure(
        AppError.validation('ownerId must not be empty'),
      );
    }
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      return const Result.failure(
        AppError.validation('expiresAt must be in the future'),
      );
    }

    try {
      await _firestore
          .collection(_collection)
          .doc(_docId(vehicleId, shopId))
          .set({
        'vehicleId': vehicleId,
        'shopId': shopId,
        'ownerId': ownerId,
        'isActive': true,
        'grantedAt': DateTime.now().millisecondsSinceEpoch,
        if (expiresAt != null) 'expiresAt': expiresAt.millisecondsSinceEpoch,
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Revokes [shopId]'s access to [vehicleId]. Only [ownerId] can revoke.
  Future<Result<void, AppError>> revokePermission({
    required String vehicleId,
    required String shopId,
    required String ownerId,
  }) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_docId(vehicleId, shopId))
          .get();

      if (!doc.exists) {
        return const Result.success(null); // idempotent
      }

      final data = doc.data() as Map<String, dynamic>;
      if (data['ownerId'] != ownerId) {
        return const Result.failure(
          AppError.permission(
              'only the vehicle owner can revoke sharing permission'),
        );
      }

      await doc.reference.delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns true if [shopId] currently has valid access to [vehicleId].
  Future<Result<bool, AppError>> hasPermission({
    required String vehicleId,
    required String shopId,
  }) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_docId(vehicleId, shopId))
          .get();

      if (!doc.exists) {
        return const Result.success(false);
      }

      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] as bool? ?? false;
      if (!isActive) {
        return const Result.success(false);
      }

      // Check expiry
      final expiresAtMs = data['expiresAt'] as int?;
      if (expiresAtMs != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
        if (expiresAt.isBefore(DateTime.now())) {
          return const Result.success(false);
        }
      }

      return const Result.success(true);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns the list of shop IDs that [ownerId] has granted access to [vehicleId].
  Future<Result<List<String>, AppError>> getPermittedShops({
    required String vehicleId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('vehicleId', isEqualTo: vehicleId)
          .where('isActive', isEqualTo: true)
          .get();

      final now = DateTime.now().millisecondsSinceEpoch;
      final shopIds = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final expiresAtMs = data['expiresAt'] as int?;
            return expiresAtMs == null || expiresAtMs > now;
          })
          .map((doc) => (doc.data())['shopId'] as String)
          .toList();

      return Result.success(shopIds);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns the list of vehicle IDs that [shopId] has been granted access to.
  Future<Result<List<String>, AppError>> getPermittedVehicles({
    required String shopId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('shopId', isEqualTo: shopId)
          .where('isActive', isEqualTo: true)
          .get();

      final now = DateTime.now().millisecondsSinceEpoch;
      final vehicleIds = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final expiresAtMs = data['expiresAt'] as int?;
            return expiresAtMs == null || expiresAtMs > now;
          })
          .map((doc) => (doc.data())['vehicleId'] as String)
          .toList();

      return Result.success(vehicleIds);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }
}
