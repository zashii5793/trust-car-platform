import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle_master.dart';

/// Community-contributed spec data for a specific maker/model/year/grade.
class VehicleSpecResult {
  final VehicleGrade grade;
  final int contributorCount;

  /// User IDs that contributed to this spec (used for dedup — one user
  /// can only count once toward the verification badge).
  final List<String> contributorIds;

  /// Photo of an actual vehicle of this grade, contributed by a community
  /// member (the first contributor who registered with a photo).
  final String? sampleImageUrl;

  const VehicleSpecResult({
    required this.grade,
    required this.contributorCount,
    this.contributorIds = const [],
    this.sampleImageUrl,
  });

  /// True once 3+ distinct owners have confirmed the same spec data.
  bool get isVerified => contributorCount >= 3;

  /// True when [userId] has already contributed to this spec.
  bool isContributor(String userId) => contributorIds.contains(userId);
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
      '${maker}_${model}_${year}_$grade'.replaceAll(' ', '_').toLowerCase();

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
      final doc = await _specsRef.doc(specId(maker, model, year, grade)).get();
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
        contributorIds:
            List<String>.from(data['contributorIds'] as List? ?? []),
        sampleImageUrl: data['sampleImageUrl'] as String?,
      ));
    } catch (e) {
      return Result.failure(AppError.unknown('fetchSpec failed: $e'));
    }
  }

  /// Fetches all known grade specs for a maker/model/year combination.
  ///
  /// Used by the vehicle certificate OCR flow where the grade is unknown.
  /// Results are sorted by contributorCount descending (most trusted first).
  /// Only non-personal catalog fields are queried — no user data is sent.
  Future<Result<List<VehicleSpecResult>, AppError>> fetchSpecsForModel(
      String maker, String model, int year) async {
    if (maker.isEmpty) {
      return const Result.failure(
          AppError.validation('maker must not be empty', field: 'maker'));
    }
    if (model.isEmpty) {
      return const Result.failure(
          AppError.validation('model must not be empty', field: 'model'));
    }
    try {
      final snap = await _specsRef
          .where('maker', isEqualTo: maker)
          .where('model', isEqualTo: model)
          .where('year', isEqualTo: year)
          .get();

      final specs = snap.docs.map((doc) {
        final data = doc.data();
        return VehicleSpecResult(
          grade: VehicleGrade(
            id: doc.id,
            modelId: '',
            name: data['grade'] as String? ?? '',
            engineDisplacement: data['engineDisplacement'] as int?,
            fuelType: data['fuelType'] as String?,
            seatingCapacity: data['seatingCapacity'] as int?,
            vehicleWeight: data['vehicleWeight'] as int?,
            standardEquipment:
                List<String>.from(data['standardEquipment'] as List? ?? []),
          ),
          contributorCount: data['contributorCount'] as int? ?? 1,
          sampleImageUrl: data['sampleImageUrl'] as String?,
        );
      }).toList()
        ..sort((a, b) => b.contributorCount.compareTo(a.contributorCount));

      return Result.success(specs);
    } catch (e) {
      return Result.failure(AppError.unknown('fetchSpecsForModel failed: $e'));
    }
  }

  /// Saves spec data contributed by a user.
  ///
  /// - New document: created with contributorCount = 1 and all spec fields.
  /// - Existing document: contributorCount is incremented once per user.
  ///   Repeat saves by the same contributor are no-ops, so the verification
  ///   badge ("N人が確認") cannot be inflated by editing one's own vehicle.
  ///   The first contributor's data is preserved as the source of truth.
  Future<Result<void, AppError>> saveSpec(
      String maker, String model, int year, String grade, VehicleGrade specData,
      {required String contributorId, String? imageUrl}) async {
    if (maker.isEmpty) {
      return const Result.failure(
          AppError.validation('maker must not be empty', field: 'maker'));
    }
    if (model.isEmpty) {
      return const Result.failure(
          AppError.validation('model must not be empty', field: 'model'));
    }
    if (contributorId.isEmpty) {
      return const Result.failure(AppError.validation(
          'contributorId must not be empty',
          field: 'contributorId'));
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
          'sampleImageUrl': imageUrl,
          'contributorIds': [contributorId],
          'contributorCount': 1,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final data = snap.data()!;
        final contributorIds =
            List<String>.from(data['contributorIds'] as List? ?? []);
        if (contributorIds.contains(contributorId)) {
          // Already counted — repeat saves must not inflate the badge.
          return const Result.success(null);
        }
        final currentCount = (data['contributorCount'] as int?) ?? 0;
        final update = <String, dynamic>{
          'contributorIds': [...contributorIds, contributorId],
          'contributorCount': currentCount + 1,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        // Backfill the sample photo if no contributor has provided one yet.
        if (data['sampleImageUrl'] == null && imageUrl != null) {
          update['sampleImageUrl'] = imageUrl;
        }
        await ref.update(update);
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('saveSpec failed: $e'));
    }
  }
}
