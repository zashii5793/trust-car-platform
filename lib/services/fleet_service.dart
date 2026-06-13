import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle.dart';

/// Fleet statistics summary for a company.
class FleetStats {
  final int total;
  final int critical; // inspection ≤7 days or overdue
  final int warning; // inspection 8-30 days
  final int normal; // all others

  const FleetStats({
    required this.total,
    required this.critical,
    required this.warning,
    required this.normal,
  });

  /// Ratio of critical vehicles to total (0.0–1.0).
  double get urgencyRatio => total == 0 ? 0.0 : critical / total;
}

/// Service for fleet (corporate) vehicle management.
///
/// companyId = the business account owner's userId.
/// Fleet vehicles are Firestore documents with `companyId` == the owner's uid.
class FleetService {
  final FirebaseFirestore _firestore;

  FleetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vehiclesRef =>
      _firestore.collection(FirestoreCollections.vehicles);

  /// Stream of all vehicles belonging to the fleet.
  Stream<List<Vehicle>> getCompanyVehicles(String companyId) {
    if (companyId.isEmpty) return Stream.value([]);

    return _vehiclesRef
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) => snap.docs.map(Vehicle.fromFirestore).toList());
  }

  /// Calculates fleet-wide urgency stats.
  Future<Result<FleetStats, AppError>> getFleetStats(String companyId) async {
    try {
      final snap = companyId.isEmpty
          ? await _vehiclesRef.where('companyId', isEqualTo: '').get()
          : await _vehiclesRef.where('companyId', isEqualTo: companyId).get();

      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();
      int critical = 0, warning = 0, normal = 0;

      for (final v in vehicles) {
        final days = v.daysUntilInspection;
        if (days == null) {
          normal++;
        } else if (days < 0 || days <= 7) {
          critical++;
        } else if (days <= 30) {
          warning++;
        } else {
          normal++;
        }
      }

      return Result.success(FleetStats(
        total: vehicles.length,
        critical: critical,
        warning: warning,
        normal: normal,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Links a vehicle to a fleet by setting its companyId.
  ///
  /// Only the vehicle's owner (userId == requestingUserId) can link it.
  Future<Result<void, AppError>> linkVehicleToCompany(
    String vehicleId,
    String companyId,
    String requestingUserId,
  ) async {
    try {
      final doc = await _vehiclesRef.doc(vehicleId).get();
      if (!doc.exists) {
        return const Result.failure(AppError.notFound(
          '車両が見つかりません',
          resourceType: 'Vehicle',
        ));
      }

      final data = doc.data()!;
      if (data['userId'] != requestingUserId) {
        return const Result.failure(AppError.permission(
          'この車両をフリートに追加する権限がありません',
        ));
      }

      await _vehiclesRef.doc(vehicleId).update({
        'companyId': companyId,
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Joins a fleet using the fleet invitation code (= company owner's userId).
  ///
  /// The requesting user must own the vehicle.  The fleet code is not
  /// independently validated against a user document — it is simply stored as
  /// companyId so the owner can see the vehicle in their dashboard.
  Future<Result<void, AppError>> joinFleetByCode(
    String fleetCode,
    String vehicleId,
    String requestingUserId,
  ) async {
    if (fleetCode.trim().isEmpty) {
      return const Result.failure(
        AppError.validation('フリートコードを入力してください'),
      );
    }
    return linkVehicleToCompany(vehicleId, fleetCode.trim(), requestingUserId);
  }

  /// Leaves a fleet by clearing the companyId of the vehicle.
  ///
  /// Only the vehicle's owner can leave.
  Future<Result<void, AppError>> leaveFleet(
    String vehicleId,
    String requestingUserId,
  ) async {
    try {
      final doc = await _vehiclesRef.doc(vehicleId).get();
      if (!doc.exists) {
        return const Result.failure(
            AppError.notFound('車両が見つかりません', resourceType: 'Vehicle'));
      }
      if (doc.data()?['userId'] != requestingUserId) {
        return const Result.failure(
            AppError.permission('この車両のフリートを変更する権限がありません'));
      }
      await _vehiclesRef.doc(vehicleId).update({
        'companyId': null,
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Assigns a staff member to a fleet vehicle.
  ///
  /// The [requestingUserId] must be the fleet owner (companyId == requestingUserId).
  Future<Result<void, AppError>> assignVehicle(
    String vehicleId,
    String assigneeId,
    String assigneeName,
    String requestingUserId,
  ) async {
    try {
      final doc = await _vehiclesRef.doc(vehicleId).get();
      if (!doc.exists) {
        return const Result.failure(
            AppError.notFound('車両が見つかりません', resourceType: 'Vehicle'));
      }
      final data = doc.data()!;
      if (data['companyId'] != requestingUserId) {
        return const Result.failure(
            AppError.permission('この車両に担当者を割り当てる権限がありません'));
      }
      await _vehiclesRef.doc(vehicleId).update({
        'assigneeId': assigneeId.isEmpty ? null : assigneeId,
        'assigneeName': assigneeName.isEmpty ? null : assigneeName,
        'updatedAt': Timestamp.now(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Aggregates maintenance history (last date / total cost) per vehicle.
  ///
  /// Used by the fleet CSV export. Queries in chunks of 10 to respect
  /// Firestore's whereIn limit.
  Future<Result<Map<String, MaintenanceSummary>, AppError>>
      getMaintenanceSummaries(List<String> vehicleIds) async {
    if (vehicleIds.isEmpty) {
      return const Result.success({});
    }
    try {
      final recordsRef =
          _firestore.collection(FirestoreCollections.maintenanceRecords);
      final summaries = <String, MaintenanceSummary>{};

      for (var i = 0; i < vehicleIds.length; i += 10) {
        final chunk = vehicleIds.sublist(
            i, i + 10 > vehicleIds.length ? vehicleIds.length : i + 10);
        final snap = await recordsRef.where('vehicleId', whereIn: chunk).get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final vehicleId = data['vehicleId'] as String? ?? '';
          if (vehicleId.isEmpty) continue;
          final cost = (data['cost'] as num?)?.toInt() ?? 0;
          final ts = data['date'];
          final date = ts is Timestamp ? ts.toDate() : null;

          final prev = summaries[vehicleId];
          summaries[vehicleId] = MaintenanceSummary(
            lastMaintenanceDate: prev?.lastMaintenanceDate == null
                ? date
                : (date != null && date.isAfter(prev!.lastMaintenanceDate!)
                    ? date
                    : prev!.lastMaintenanceDate),
            totalCost: (prev?.totalCost ?? 0) + cost,
            recordCount: (prev?.recordCount ?? 0) + 1,
          );
        }
      }
      return Result.success(summaries);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}

/// Aggregated maintenance history for one vehicle (fleet CSV export).
class MaintenanceSummary {
  final DateTime? lastMaintenanceDate;
  final int totalCost;
  final int recordCount;

  const MaintenanceSummary({
    required this.lastMaintenanceDate,
    required this.totalCost,
    required this.recordCount,
  });
}
