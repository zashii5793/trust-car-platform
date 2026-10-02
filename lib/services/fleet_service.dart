import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../core/utils/inspection_urgency.dart';
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
        // Reuse the canonical urgency thresholds (≤7 critical, ≤30 warning)
        // so fleet stats never drift from the dashboard's chip coloring.
        switch (inspectionUrgencyForDays(v.daysUntilInspection)) {
          case InspectionUrgency.critical:
            critical++;
          case InspectionUrgency.warning:
            warning++;
          case InspectionUrgency.normal:
          case InspectionUrgency.none: // no inspection date → counted as normal
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

  /// Aggregated maintenance history (last date / total cost / count) per
  /// vehicle, for the fleet CSV export.
  ///
  /// 法人の管理者はメンバーの maintenance_records を読めない（ルールで本人
  /// だけ）。代わりに Cloud Functions（onMaintenanceRecordWritten）が書く
  /// `fleet_maintenance_summaries/{vehicleId}` を読む。集計の項目しか
  /// 入っていないので、メモや店名などの個人の記録は管理者に渡らない。
  ///
  /// ルールは「いまの車の文書」で管理者か持ち主かを判定する（get()）。
  /// documentId の whereIn は文書ごとに評価され、1件でも読めないと全体が
  /// 拒否されるので、1件ずつ get する（Issue #192）。
  ///
  /// 集計がまだ無い車（記録が無い・集計の導入前のまま）はマップに含めない。
  Future<Result<Map<String, MaintenanceSummary>, AppError>>
      getMaintenanceSummaries(List<String> vehicleIds) async {
    final ids = vehicleIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const Result.success({});
    try {
      final ref =
          _firestore.collection(FirestoreCollections.fleetMaintenanceSummaries);
      final snaps = await Future.wait(ids.map((id) => ref.doc(id).get()));

      final summaries = <String, MaintenanceSummary>{};
      for (final snap in snaps) {
        final data = snap.data();
        if (data == null) continue;
        final ts = data['lastMaintenanceDate'];
        summaries[snap.id] = MaintenanceSummary(
          lastMaintenanceDate: ts is Timestamp ? ts.toDate() : null,
          totalCost: (data['totalCost'] as num?)?.toInt() ?? 0,
          recordCount: (data['recordCount'] as num?)?.toInt() ?? 0,
        );
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
