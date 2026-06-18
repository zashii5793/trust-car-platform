import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/maintenance_preferences.dart';

/// 車両ごとの「交換目安（メンテナンス間隔）」のユーザー設定を永続化する。
///
/// 保存先: `vehicles/{vehicleId}/maintenance_prefs/intervals`（単一ドキュメント）。
class MaintenancePreferenceService {
  final FirebaseFirestore _firestore;

  MaintenancePreferenceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _docId = 'intervals';

  DocumentReference<Map<String, dynamic>> _doc(String vehicleId) => _firestore
      .collection(FirestoreCollections.vehicles)
      .doc(vehicleId)
      .collection(FirestoreCollections.maintenancePrefs)
      .doc(_docId);

  /// 設定を取得する。未設定なら空の設定（＝すべて標準値）を返す。
  Future<Result<MaintenancePreferences, AppError>> getPreferences(
    String vehicleId,
    String userId,
  ) async {
    try {
      final doc = await _doc(vehicleId).get();
      if (!doc.exists) {
        return Result.success(MaintenancePreferences.empty(vehicleId, userId));
      }
      return Result.success(
          MaintenancePreferences.fromFirestore(vehicleId, doc));
    } catch (e) {
      return Result.failure(AppError.server('交換目安の取得に失敗しました: $e'));
    }
  }

  /// 設定を保存する。
  Future<Result<void, AppError>> savePreferences(
      MaintenancePreferences prefs) async {
    try {
      await _doc(prefs.vehicleId).set(prefs.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.server('交換目安の保存に失敗しました: $e'));
    }
  }
}
