import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle_master.dart';

/// Community-contributed spec data for a specific maker/model/year/grade.
class VehicleSpecResult {
  final VehicleGrade grade;
  final int contributorCount;

  const VehicleSpecResult({
    required this.grade,
    required this.contributorCount,
  });
}

/// Service for reading and writing community vehicle grade spec data.
///
/// Firestore collection: `vehicle_grade_specs`
/// Document ID: `{maker}_{model}_{year}_{grade}` (lowercased, spaces→underscores)
class VehicleSpecService {
  final FirebaseFirestore _firestore;

  VehicleSpecService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _specsRef =>
      _firestore.collection(FirestoreCollections.vehicleGradeSpecs);

  static String specId(String maker, String model, int year, String grade) =>
      '${maker}_${model}_${year}_$grade'
          .replaceAll(' ', '_')
          .toLowerCase();

  /// Fetches spec data from the community collection.
  /// Returns [null] if no data exists yet for this combination.
  Future<Result<VehicleSpecResult?, AppError>> fetchSpec(
      String maker, String model, int year, String grade) async {
    if (maker.isEmpty) {
      return const Result.failure(
          AppError.validation('maker must not be empty', field: 'maker'));
    }
    if (model.isEmpty) {
      return const Result.failure(
          AppError.validation('model must not be empty', field: 'model'));
    }
    try {
      final doc =
          await _specsRef.doc(specId(maker, model, year, grade)).get();
      if (!doc.exists) {
        return const Result.success(null);
      }
      final data = doc.data()!;
      final g = VehicleGrade(
        id: doc.id,
        modelId: '',
        name: data['grade'] as String? ?? grade,
        engineDisplacement: data['engineDisplacement'] as int?,
        fuelType: data['fuelType'] as String?,
        seatingCapacity: data['seatingCapacity'] as int?,
        vehicleWeight: data['vehicleWeight'] as int?,
        standardEquipment:
            List<String>.from(data['standardEquipment'] as List? ?? []),
      );
      return Result.success(VehicleSpecResult(
        grade: g,
        contributorCount: data['contributorCount'] as int? ?? 1,
      ));
    } catch (e) {
      return Result.failure(AppError.unknown('fetchSpec failed: $e'));
    }
  }

  /// Saves spec data contributed by a user.
  ///
  /// - New document: created with contributorCount = 1 and all spec fields.
  /// - Existing document: only contributorCount is incremented.
  ///   The first contributor's data is preserved as the source of truth.
  Future<Result<void, AppError>> saveSpec(
      String maker,
      String model,
      int year,
      String grade,
      VehicleGrade specData) async {
    if (maker.isEmpty) {
      return const Result.failure(
          AppError.validation('maker must not be empty', field: 'maker'));
    }
    if (model.isEmpty) {
      return const Result.failure(
          AppError.validation('model must not be empty', field: 'model'));
    }
    try {
      final id = specId(maker, model, year, grade);
      final ref = _specsRef.doc(id);
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          'maker': maker,
          'model': model,
          'year': year,
          'grade': grade,
          'engineDisplacement': specData.engineDisplacement,
          'fuelType': specData.fuelType,
          'seatingCapacity': specData.seatingCapacity,
          'vehicleWeight': specData.vehicleWeight,
          'standardEquipment': specData.standardEquipment,
          'contributorCount': 1,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final currentCount =
            (snap.data()!['contributorCount'] as int?) ?? 0;
        await ref.update({
          'contributorCount': currentCount + 1,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('saveSpec failed: $e'));
    }
  }
}
