import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle.dart';

/// Handles vehicle lifecycle retirement: selling, scrapping, lease returns, and
/// transfers between owners.
///
/// Key design:
/// - Data retention is the user's choice (retainData flag)
/// - Retired vehicles remain in Firestore with `status != active`
/// - Active garage queries filter by `status == active`
/// - Restoration is allowed to undo accidental retirement
class VehicleRetirementService {
  static const _collection = 'vehicles';

  final FirebaseFirestore _firestore;

  VehicleRetirementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Marks a vehicle as retired (sold/scrapped/leaseReturned/transferred).
  ///
  /// [reason] must not be [VehicleStatus.active].
  /// [retainData] controls whether maintenance records are flagged for retention.
  Future<Result<void, AppError>> retireVehicle({
    required String vehicleId,
    required String ownerId,
    required VehicleStatus reason,
    required bool retainData,
    String? note,
  }) async {
    if (vehicleId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('vehicleId must not be empty'));
    }
    if (reason == VehicleStatus.active) {
      return const Result.failure(
          AppError.validation('reason must be a retirement status, not active'));
    }

    try {
      final doc =
          await _firestore.collection(_collection).doc(vehicleId).get();
      if (!doc.exists) {
        return Result.failure(
            AppError.notFound('Vehicle not found: $vehicleId'));
      }
      final data = doc.data()!;
      if (data['userId'] != ownerId) {
        return const Result.failure(
            AppError.permission('only the vehicle owner can retire it'));
      }
      final currentStatus =
          VehicleStatus.fromString(data['status'] as String?);
      if (currentStatus != VehicleStatus.active) {
        return const Result.failure(
            AppError.validation('vehicle is already retired'));
      }

      await _firestore.collection(_collection).doc(vehicleId).update({
        'status': reason.name,
        'retiredAt': Timestamp.fromDate(DateTime.now()),
        'retirementNote': note,
        'isDataRetained': retainData,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Restores a retired vehicle back to active status (undo retirement).
  Future<Result<void, AppError>> restoreVehicle({
    required String vehicleId,
    required String ownerId,
  }) async {
    if (vehicleId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('vehicleId must not be empty'));
    }

    try {
      final doc =
          await _firestore.collection(_collection).doc(vehicleId).get();
      if (!doc.exists) {
        return Result.failure(
            AppError.notFound('Vehicle not found: $vehicleId'));
      }
      final data = doc.data()!;
      if (data['userId'] != ownerId) {
        return const Result.failure(
            AppError.permission('only the vehicle owner can restore it'));
      }
      final currentStatus =
          VehicleStatus.fromString(data['status'] as String?);
      if (currentStatus == VehicleStatus.active) {
        return const Result.failure(
            AppError.validation('vehicle is already active'));
      }

      await _firestore.collection(_collection).doc(vehicleId).update({
        'status': VehicleStatus.active.name,
        'retiredAt': null,
        'retirementNote': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns all retired vehicles (sold/scrapped/etc.) for [userId].
  Future<Result<List<Vehicle>, AppError>> getRetiredVehicles(
      String userId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', whereNotIn: [VehicleStatus.active.name])
          .get();
      return Result.success(snap.docs.map(Vehicle.fromFirestore).toList());
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns only active vehicles for [userId] (excludes retired).
  Future<Result<List<Vehicle>, AppError>> getActiveVehicles(
      String userId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: VehicleStatus.active.name)
          .get();
      return Result.success(snap.docs.map(Vehicle.fromFirestore).toList());
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }
}
