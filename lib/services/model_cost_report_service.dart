import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/model_cost_report.dart';

/// 車種別の維持費レポートを読む（書くのはサーバーだけ）。
class ModelCostReportService {
  final FirebaseFirestore _firestore;

  ModelCostReportService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  static const String collection = 'model_cost_reports';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(collection);

  /// この車種のレポート。車種で人数が足りなければメーカー全体のものを返す。
  /// どちらも無ければ null（**推定で埋めない**）。
  ///
  /// 持ち主が [modelCostMinOwners] に満たないレポートは、在っても無いものとして
  /// 扱う（サーバーは書かない決まりだが、アプリでも重ねて確かめる）。
  Future<Result<ModelCostReport?, AppError>> forVehicle({
    required String maker,
    required String model,
  }) async {
    if (modelCostKey(maker).isEmpty) return const Result.success(null);
    try {
      if (modelCostKey(model).isNotEmpty) {
        final id = modelCostReportId(maker, model);
        final doc = await _col.doc(id).get();
        final data = doc.data();
        if (doc.exists && data != null) {
          final report = ModelCostReport.fromMap(doc.id, data);
          if (report.isPublishable) return Result.success(report);
        }
      }
      final makerDoc = await _col.doc(modelCostKey(maker)).get();
      final makerData = makerDoc.data();
      if (makerDoc.exists && makerData != null) {
        final report = ModelCostReport.fromMap(makerDoc.id, makerData);
        if (report.isPublishable) return Result.success(report);
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// 見られる車種の一覧（持ち主の多い順）。買う前に調べる人のため。
  ///
  /// レポートは車種の数だけしかないので、上位だけを読み、絞り込みは画面側で行う。
  /// 持ち主が [modelCostMinOwners] に満たないものは返さない。
  Future<Result<List<ModelCostReport>, AppError>> listAvailable({
    int limit = 200,
  }) async {
    try {
      final snap =
          await _col.orderBy('ownerCount', descending: true).limit(limit).get();
      return Result.success(snap.docs
          .map((d) => ModelCostReport.fromMap(d.id, d.data()))
          .where((r) => r.isPublishable)
          .toList());
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
