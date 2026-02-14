import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle_master.dart';
import '../data/vehicle_master_data.dart';

/// Service for vehicle master data (makers, models, grades)
/// Uses static data as fallback when Firestore is unavailable
class VehicleMasterService {
  final FirebaseFirestore _firestore;

  // Cache for quick access
  List<VehicleMaker>? _makersCache;
  final Map<String, List<VehicleModel>> _modelsCache = {};
  final Map<String, List<VehicleGrade>> _gradesCache = {};

  VehicleMasterService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get all vehicle makers
  Future<Result<List<VehicleMaker>, AppError>> getMakers() async {
    // Return cached data if available
    if (_makersCache != null) {
      return Result.success(_makersCache!);
    }

    try {
      final snapshot = await _firestore
          .collection('vehicle_masters')
          .doc('makers')
          .collection('items')
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .get();

      if (snapshot.docs.isNotEmpty) {
        _makersCache = snapshot.docs
            .map((doc) => VehicleMaker.fromFirestore(doc))
            .toList();
        return Result.success(_makersCache!);
      }

      // Fallback to static data
      _makersCache = VehicleMasterData.getMakers();
      return Result.success(_makersCache!);
    } catch (e) {
      // Fallback to static data on error
      _makersCache = VehicleMasterData.getMakers();
      return Result.success(_makersCache!);
    }
  }

  /// Get vehicle models for a specific maker
  Future<Result<List<VehicleModel>, AppError>> getModelsForMaker(String makerId) async {
    // Return cached data if available
    if (_modelsCache.containsKey(makerId)) {
      return Result.success(_modelsCache[makerId]!);
    }

    try {
      final snapshot = await _firestore
          .collection('vehicle_masters')
          .doc('models')
          .collection('items')
          .where('makerId', isEqualTo: makerId)
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final models = snapshot.docs
            .map((doc) => VehicleModel.fromFirestore(doc))
            .toList();
        _modelsCache[makerId] = models;
        return Result.success(models);
      }

      // Fallback to static data
      final staticModels = VehicleMasterData.getModelsForMaker(makerId);
      _modelsCache[makerId] = staticModels;
      return Result.success(staticModels);
    } catch (e) {
      // Fallback to static data on error
      final staticModels = VehicleMasterData.getModelsForMaker(makerId);
      _modelsCache[makerId] = staticModels;
      return Result.success(staticModels);
    }
  }

  /// Get vehicle grades for a specific model
  Future<Result<List<VehicleGrade>, AppError>> getGradesForModel(String modelId) async {
    // Return cached data if available
    if (_gradesCache.containsKey(modelId)) {
      return Result.success(_gradesCache[modelId]!);
    }

    try {
      final snapshot = await _firestore
          .collection('vehicle_masters')
          .doc('grades')
          .collection('items')
          .where('modelId', isEqualTo: modelId)
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final grades = snapshot.docs
            .map((doc) => VehicleGrade.fromFirestore(doc))
            .toList();
        _gradesCache[modelId] = grades;
        return Result.success(grades);
      }

      // Fallback to common grades
      final commonGrades = VehicleMasterData.getCommonGrades(modelId);
      _gradesCache[modelId] = commonGrades;
      return Result.success(commonGrades);
    } catch (e) {
      // Fallback to common grades on error
      final commonGrades = VehicleMasterData.getCommonGrades(modelId);
      _gradesCache[modelId] = commonGrades;
      return Result.success(commonGrades);
    }
  }

  /// Search makers by name (Japanese or English)
  List<VehicleMaker> searchMakers(String query) {
    if (_makersCache == null || query.isEmpty) {
      return _makersCache ?? [];
    }

    final lowerQuery = query.toLowerCase();
    return _makersCache!.where((maker) =>
      maker.name.toLowerCase().contains(lowerQuery) ||
      maker.nameEn.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Search models by name (Japanese or English)
  List<VehicleModel> searchModels(String makerId, String query) {
    final models = _modelsCache[makerId];
    if (models == null || query.isEmpty) {
      return models ?? [];
    }

    final lowerQuery = query.toLowerCase();
    return models.where((model) =>
      model.name.toLowerCase().contains(lowerQuery) ||
      (model.nameEn?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  /// Get models available in a specific year
  List<VehicleModel> getModelsAvailableInYear(String makerId, int year) {
    final models = _modelsCache[makerId];
    if (models == null) return [];

    return models.where((model) => model.isAvailableInYear(year)).toList();
  }

  /// Get grades available in a specific year
  List<VehicleGrade> getGradesAvailableInYear(String modelId, int year) {
    final grades = _gradesCache[modelId];
    if (grades == null) return [];

    return grades.where((grade) => grade.isAvailableInYear(year)).toList();
  }

  /// Seed Firestore with initial master data
  /// This should be called once during app initialization or by admin
  Future<Result<void, AppError>> seedMasterData() async {
    try {
      final batch = _firestore.batch();

      // Seed makers
      for (final makerData in VehicleMasterData.makers) {
        final docRef = _firestore
            .collection('vehicle_masters')
            .doc('makers')
            .collection('items')
            .doc(makerData['id'] as String);
        batch.set(docRef, {
          ...makerData,
          'isActive': true,
        });
      }

      // Seed models
      for (final entry in VehicleMasterData.models.entries) {
        final makerId = entry.key;
        for (final modelData in entry.value) {
          final docRef = _firestore
              .collection('vehicle_masters')
              .doc('models')
              .collection('items')
              .doc(modelData['id'] as String);
          batch.set(docRef, {
            ...modelData,
            'makerId': makerId,
            'isActive': true,
          });
        }
      }

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.server('Failed to seed master data: $e'));
    }
  }

  /// Clear all caches
  void clearCache() {
    _makersCache = null;
    _modelsCache.clear();
    _gradesCache.clear();
  }
}
