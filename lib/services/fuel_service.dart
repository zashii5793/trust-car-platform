import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/fuel_record.dart';

/// Stores what went into the tank.
///
/// `docs/HABIT_DESIGN.md` 打ち手1。給油は月2〜4回あり、**唯一の月単位の接点**。
class FuelService {
  final FirebaseFirestore _firestore;

  FuelService({required FirebaseFirestore firestore}) : _firestore = firestore;

  static const String collection = 'fuel_records';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(collection);

  /// 1件足す。保存できたら、その時点の燃費も返す。
  ///
  /// **保存した瞬間に燃費を返すのが肝。** 記録が増えただけでは何も返ってこず、
  /// 続かない。毎回違う数字が出るから見たくなる。
  Future<Result<FuelSaveResult, AppError>> add(FuelRecord record) async {
    if (record.vehicleId.trim().isEmpty) {
      return const Result.failure(AppError.validation('車両が選ばれていません'));
    }
    if (record.userId.trim().isEmpty) {
      return const Result.failure(AppError.auth('記録するにはログインが必要です'));
    }
    if (record.liters <= 0) {
      return const Result.failure(AppError.validation('給油量を入力してください'));
    }
    if (record.liters > FuelRecord.maxLiters) {
      return const Result.failure(
        AppError.validation('給油量が大きすぎます。桁をお確かめください'),
      );
    }
    if (record.cost < 0) {
      return const Result.failure(AppError.validation('金額を入力してください'));
    }

    try {
      final doc = await _ref.add(record.toMap());

      final history = await recordsFor(record.vehicleId);
      final efficiency = history.valueOrNull == null
          ? null
          : FuelEfficiency.latestFor(history.valueOrNull!);

      return Result.success(
        FuelSaveResult(id: doc.id, efficiencyKmPerLiter: efficiency),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// その車の給油履歴を、新しい順で返す。
  Future<Result<List<FuelRecord>, AppError>> recordsFor(
    String vehicleId, {
    int limit = 100,
  }) async {
    if (vehicleId.trim().isEmpty) return const Result.success([]);

    try {
      final snapshot = await _ref
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return Result.success(
        snapshot.docs.map((d) => FuelRecord.fromMap(d.data(), d.id)).toList(),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 1件消す。
  Future<Result<void, AppError>> delete(String id) async {
    if (id.trim().isEmpty) {
      return const Result.failure(AppError.validation('記録が指定されていません'));
    }

    try {
      await _ref.doc(id).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}

/// 保存した結果。**燃費を一緒に返す**のが要点。
class FuelSaveResult {
  final String id;

  /// そのとき出せた燃費（km/L）。出せなければ null。
  final double? efficiencyKmPerLiter;

  const FuelSaveResult({required this.id, this.efficiencyKmPerLiter});
}
