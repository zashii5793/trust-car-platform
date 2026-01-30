import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/result/result.dart';
import '../../core/error/app_error.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../models/maintenance_record.dart';

/// MaintenanceRepositoryのFirebase実装
class FirebaseMaintenanceRepository implements MaintenanceRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'maintenance_records';

  FirebaseMaintenanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recordsRef =>
      _firestore.collection(_collection);

  @override
  Stream<Result<List<MaintenanceRecord>, AppError>> watchVehicleRecords(String vehicleId) {
    return _recordsRef
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map<Result<List<MaintenanceRecord>, AppError>>((snapshot) {
      try {
        final records = snapshot.docs
            .map((doc) => MaintenanceRecord.fromFirestore(doc))
            .toList();
        return Result.success(records);
      } catch (e) {
        return Result.failure(mapFirebaseError(e));
      }
    });
  }

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getVehicleRecords(String vehicleId) async {
    try {
      final snapshot = await _recordsRef
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('date', descending: true)
          .get();

      final records = snapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();

      return Result.success(records);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getUserRecords(String userId) async {
    try {
      final snapshot = await _recordsRef
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      final records = snapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();

      return Result.success(records);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<MaintenanceRecord, AppError>> getRecordById(String recordId) async {
    try {
      final doc = await _recordsRef.doc(recordId).get();

      if (!doc.exists) {
        return const Result.failure(
          AppError.notFound('Record not found', resourceType: 'メンテナンス記録'),
        );
      }

      return Result.success(MaintenanceRecord.fromFirestore(doc));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<String, AppError>> addRecord(MaintenanceRecord record) async {
    try {
      final docRef = await _recordsRef.add(record.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> updateRecord(MaintenanceRecord record) async {
    try {
      await _recordsRef.doc(record.id).update(record.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> deleteRecord(String recordId) async {
    try {
      await _recordsRef.doc(recordId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getRecordsByType(
    String vehicleId,
    MaintenanceType type,
  ) async {
    try {
      final snapshot = await _recordsRef
          .where('vehicleId', isEqualTo: vehicleId)
          .where('type', isEqualTo: type.index)
          .orderBy('date', descending: true)
          .get();

      final records = snapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();

      return Result.success(records);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getRecordsByDateRange(
    String vehicleId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _recordsRef
          .where('vehicleId', isEqualTo: vehicleId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      final records = snapshot.docs
          .map((doc) => MaintenanceRecord.fromFirestore(doc))
          .toList();

      return Result.success(records);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
