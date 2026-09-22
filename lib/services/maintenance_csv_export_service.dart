import 'package:intl/intl.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/maintenance_record.dart';
import '../models/vehicle.dart';

/// Exports one vehicle's maintenance history as CSV.
///
/// Being able to hand the history over at sale time is part of what this app
/// is for. A PDF is something to read; a buyer or the next owner needs rows
/// they can work with.
///
/// Personal exports were PDF only (the vehicle karte and the maintenance
/// report). The CSV that existed was the fleet one, which writes one row per
/// vehicle and carries no service detail at all — two summary columns.
///
/// The provenance column matters as much as the rows: a table that cannot
/// tell a shop-issued record from something typed in by hand is not usable
/// at trade-in.
class MaintenanceCsvExportService {
  const MaintenanceCsvExportService();

  /// Excel on Windows reads UTF-8 as Shift-JIS without this.
  static const _bom = '\u{FEFF}';

  static const _headers = [
    '実施日',
    '区分',
    '内容',
    '費用(円)',
    '部品代(円)',
    '工賃(円)',
    '走行距離(km)',
    '工場名',
    '出所',
    '備考',
  ];

  Result<String, AppError> buildCsv({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
  }) {
    try {
      final dateFormat = DateFormat('yyyy/MM/dd');
      final buffer = StringBuffer(_bom);

      // Which car this is, so a detached file still means something.
      buffer.writeln(_escape(
        '${vehicle.maker} ${vehicle.model} (${vehicle.year}年式)',
      ));
      buffer.writeln();

      buffer.writeln(_headers.map(_escape).join(','));

      final sorted = List<MaintenanceRecord>.from(records)
        ..sort((a, b) => b.date.compareTo(a.date));

      for (final r in sorted) {
        buffer.writeln([
          dateFormat.format(r.date),
          r.type.displayName,
          r.title,
          r.cost.toString(),
          r.partsCost?.toString() ?? '',
          r.laborCost?.toString() ?? '',
          r.mileageAtService?.toString() ?? '',
          r.shopName ?? '',
          // 「工場を通ったか」は、買い手が最初に見るところ。
          r.isVerified ? '工場' : '自己申告',
          r.description ?? '',
        ].map(_escape).join(','));
      }

      return Result.success(buffer.toString());
    } catch (e) {
      return Result.failure(
        AppError.unknown('CSVの作成に失敗しました', originalError: e),
      );
    }
  }

  /// Sanitizes and quotes a field.
  ///
  /// Same guard as the fleet export: a value starting with `=`, `+`, `-` or
  /// `@` is executed as a formula by spreadsheet apps, so it is prefixed with
  /// a quote. Then RFC 4180 quoting for commas, quotes and newlines.
  String _escape(String value) {
    var v = value;
    if (v.isNotEmpty && ['=', '+', '-', '@'].contains(v[0])) {
      v = "'$v";
    }
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
