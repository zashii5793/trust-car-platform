import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/maintenance_record.dart';
import 'maintenance_history_import.dart';

/// 取込の結果。
class HistoryImportResult {
  final int added;

  /// 既に取り込み済みで飛ばした件数。
  final int skipped;

  const HistoryImportResult({required this.added, required this.skipped});
}

/// 過去の整備記録を、利用者の `maintenance_records` にまとめて書く。
///
/// - 移した記録は**自己申告**として入る（工場の印は付けられない。
///   ルールでも止めている）
/// - 同じ行（同じ車・日付・内容・金額）は同じIDになる。**2回取り込んでも
///   二重にならず、取り込んだあとに本人が直した記録も上書きしない**
///   （既にあるIDは飛ばす）
class MaintenanceHistoryImportService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  MaintenanceHistoryImportService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  static const int _batchLimit = 400;

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection(FirestoreCollections.maintenanceRecords);

  /// 行から決まるID。同じ行なら同じIDになる。
  static String idFor(String vehicleId, HistoryImportRow row) {
    final key = '$vehicleId|${row.date.toIso8601String().substring(0, 10)}|'
        '${row.title}|${row.cost}';
    // FNV-1a（32bit）。暗号である必要はなく、同じ行から同じ値が出ればよい
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return 'imp_${vehicleId}_${h.toRadixString(16).padLeft(8, '0')}';
  }

  Future<Result<HistoryImportResult, AppError>> importRows({
    required String userId,
    required String vehicleId,
    required List<HistoryImportRow> rows,
    void Function(int done, int total)? onProgress,
  }) async {
    if (userId.isEmpty || vehicleId.isEmpty) {
      return const Result.failure(
        AppError.validation('車両を選んでから取り込んでください'),
      );
    }
    try {
      // 既にある記録（本人の、この車の）。userId で絞るのはルールの都合でもある
      final existing = (await _records
              .where('userId', isEqualTo: userId)
              .where('vehicleId', isEqualTo: vehicleId)
              .get())
          .docs
          .map((d) => d.id)
          .toSet();

      final now = _now();
      final toWrite = <String, MaintenanceRecord>{};
      var skipped = 0;
      for (final row in rows) {
        final id = idFor(vehicleId, row);
        if (existing.contains(id) || toWrite.containsKey(id)) {
          skipped++;
          continue;
        }
        toWrite[id] = MaintenanceRecord(
          id: id,
          vehicleId: vehicleId,
          userId: userId,
          type: row.type,
          title: row.title,
          description: row.memo,
          cost: row.cost,
          shopName: row.shopName,
          date: row.date,
          mileageAtService: row.mileage,
          createdAt: now,
        );
      }

      final entries = toWrite.entries.toList();
      onProgress?.call(0, entries.length);
      for (var i = 0; i < entries.length; i += _batchLimit) {
        final batch = _firestore.batch();
        for (final e in entries.skip(i).take(_batchLimit)) {
          batch.set(_records.doc(e.key), e.value.toMap());
        }
        await batch.commit();
        onProgress?.call(
            (i + _batchLimit).clamp(0, entries.length), entries.length);
      }
      return Result.success(
        HistoryImportResult(added: entries.length, skipped: skipped),
      );
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
