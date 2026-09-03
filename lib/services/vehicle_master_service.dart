import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle_master.dart';
import '../data/vehicle_master_data.dart';

/// Service for vehicle master data (makers, models, grades)
/// Uses static data as fallback when Firestore is unavailable
class VehicleMasterService {
  // Lazy Firestore access: avoids calling FirebaseFirestore.instance at
  // construction time so the service can be created before Firebase.initializeApp().
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? (_firestoreInstance ??= FirebaseFirestore.instance);

  // Cache for quick access
  List<VehicleMaker>? _makersCache;
  final Map<String, List<VehicleModel>> _modelsCache = {};
  final Map<String, List<VehicleGrade>> _gradesCache = {};

  VehicleMasterService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

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

  /// Records a catalog-absent maker/model the user typed by hand so operations
  /// can later curate it into the master. [type] is 'maker' or 'model'.
  ///
  /// - Empty values are rejected (validation failure).
  /// - Values that already match a catalog entry are skipped (success no-op).
  /// - De-duplicated by a deterministic document id, so repeated submissions of
  ///   the same value collapse into a single suggestion document.
  Future<Result<void, AppError>> recordCustomEntrySuggestion({
    required String userId,
    required String type,
    required String value,
    String? makerName,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return Result.failure(AppError.validation('候補が空です'));
    }

    try {
      // Already in the catalog → nothing to suggest.
      final inCatalog = type == 'model'
          ? await _matchesCatalogModel(trimmed, makerName)
          : await _matchesCatalogMaker(trimmed);
      if (inCatalog) {
        return Result.success(null);
      }

      final maker = makerName?.trim();
      final docId = _suggestionDocId(type, trimmed);
      await _firestore
          .collection('vehicle_master_suggestions')
          .doc(docId)
          .set({
        'userId': userId,
        'type': type,
        'value': trimmed,
        if (maker != null && maker.isNotEmpty) 'makerName': maker,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown('候補の記録に失敗しました'));
    }
  }

  /// Deterministic id so the same typed value maps to one suggestion document.
  String _suggestionDocId(String type, String value) {
    final safe = value
        .toLowerCase()
        .replaceAll(RegExp(r'[/\\.#$\[\]\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final capped = safe.length > 200 ? safe.substring(0, 200) : safe;
    return '${type}__$capped';
  }

  Future<bool> _matchesCatalogMaker(String value) async {
    final makers = (await getMakers()).getOrElse(const <VehicleMaker>[]);
    final v = value.toLowerCase();
    return makers.any(
      (m) => m.name.toLowerCase() == v || m.nameEn.toLowerCase() == v,
    );
  }

  Future<bool> _matchesCatalogModel(String value, String? makerName) async {
    final mk = makerName?.trim().toLowerCase() ?? '';
    if (mk.isEmpty) return false;
    final makers = (await getMakers()).getOrElse(const <VehicleMaker>[]);
    final matched = makers.where(
      (m) => m.name.toLowerCase() == mk || m.nameEn.toLowerCase() == mk,
    );
    if (matched.isEmpty) return false; // custom maker → model can't be catalog
    final modelsResult = await getModelsForMaker(matched.first.id);
    final models = modelsResult.getOrElse(const <VehicleModel>[]);
    final v = value.toLowerCase();
    return models.any((m) => m.name.toLowerCase() == v);
  }

  /// Get vehicle models for a specific maker
  Future<Result<List<VehicleModel>, AppError>> getModelsForMaker(
      String makerId) async {
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
  Future<Result<List<VehicleGrade>, AppError>> getGradesForModel(
      String modelId) async {
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

      // この車種のグレードがカタログに無い場合は**空を返す**。
      //
      // 以前は全車種共通の汎用リスト（S / G / X / Z / ハイブリッド …）へ
      // フォールバックしていた。しかしこれはトヨタ系の呼称で、ホンダにも
      // 日産にもマツダにも同じものが出ていた。シビックに「S・G・X・Z」が
      // 並ぶような、車種と噛み合わない候補を見せていたことになる。
      //
      // カタログが埋まるまでは、間違った候補を出すより何も出さないほうが
      // よい。グレード欄は自由入力に対応しているので、入力自体は妨げない。
      _gradesCache[modelId] = const [];
      return Result.success([]);
    } catch (e) {
      _gradesCache[modelId] = const [];
      return Result.success([]);
    }
  }

  /// Search makers by name (Japanese or English)
  List<VehicleMaker> searchMakers(String query) {
    if (_makersCache == null || query.isEmpty) {
      return _makersCache ?? [];
    }

    final lowerQuery = query.toLowerCase();
    return _makersCache!
        .where((maker) =>
            maker.name.toLowerCase().contains(lowerQuery) ||
            maker.nameEn.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Search models by name (Japanese or English)
  List<VehicleModel> searchModels(String makerId, String query) {
    final models = _modelsCache[makerId];
    if (models == null || query.isEmpty) {
      return models ?? [];
    }

    final lowerQuery = query.toLowerCase();
    return models
        .where((model) =>
            model.name.toLowerCase().contains(lowerQuery) ||
            (model.nameEn?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
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
