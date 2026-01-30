import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/result/result.dart';
import '../../core/error/app_error.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../models/vehicle.dart';

/// VehicleRepositoryのFirebase実装
class FirebaseVehicleRepository implements VehicleRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'vehicles';

  FirebaseVehicleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vehiclesRef =>
      _firestore.collection(_collection);

  @override
  Stream<Result<List<Vehicle>, AppError>> watchUserVehicles(String userId) {
    return _vehiclesRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map<Result<List<Vehicle>, AppError>>((snapshot) {
      try {
        final vehicles = snapshot.docs
            .map((doc) => Vehicle.fromFirestore(doc))
            .toList();
        return Result.success(vehicles);
      } catch (e) {
        return Result.failure(mapFirebaseError(e));
      }
    });
  }

  @override
  Future<Result<List<Vehicle>, AppError>> getUserVehicles(String userId) async {
    try {
      final snapshot = await _vehiclesRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final vehicles = snapshot.docs
          .map((doc) => Vehicle.fromFirestore(doc))
          .toList();

      return Result.success(vehicles);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<Vehicle, AppError>> getVehicleById(String vehicleId) async {
    try {
      final doc = await _vehiclesRef.doc(vehicleId).get();

      if (!doc.exists) {
        return const Result.failure(
          AppError.notFound('Vehicle not found', resourceType: '車両'),
        );
      }

      return Result.success(Vehicle.fromFirestore(doc));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async {
    try {
      final docRef = await _vehiclesRef.add(vehicle.toMap());
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> updateVehicle(Vehicle vehicle) async {
    try {
      await _vehiclesRef.doc(vehicle.id).update(vehicle.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async {
    try {
      await _vehiclesRef.doc(vehicleId).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  @override
  Future<Result<void, AppError>> updateMileage(String vehicleId, int mileage) async {
    try {
      await _vehiclesRef.doc(vehicleId).update({
        'mileage': mileage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
