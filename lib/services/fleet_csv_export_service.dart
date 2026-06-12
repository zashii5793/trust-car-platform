import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle.dart';
import 'fleet_service.dart';

/// Service for exporting fleet vehicle lists as CSV.
///
/// Output starts with a UTF-8 BOM so Excel opens Japanese text correctly.
/// Cell values are sanitized against CSV formula injection (cells starting
/// with `=`, `+`, `-`, `@` would otherwise execute as formulas in Excel).
class FleetCsvExportService {
  const FleetCsvExportService();

  static const _bom = '\u{FEFF}';

  static const _headers = [
    'メーカー',
    '車種',
    '年式',
    'グレード',
    'ナンバープレート',
    '走行距離(km)',
    '車検満了日',
    '担当者',
    'リース満了日',
    '直近整備日',
    '累計整備費用(円)',
  ];

  /// Builds a CSV string for the given fleet vehicles.
  ///
  /// [maintenanceSummaries] maps vehicleId → aggregated maintenance history;
  /// vehicles without an entry get blank maintenance columns.
  Result<String, AppError> buildCsv(
    List<Vehicle> vehicles, {
    Map<String, MaintenanceSummary> maintenanceSummaries = const {},
  }) {
    try {
      final buffer = StringBuffer(_bom);
      buffer.writeln(_headers.map(_escape).join(','));

      for (final v in vehicles) {
        final summary = maintenanceSummaries[v.id];
        final row = [
          v.maker,
          v.model,
          v.year.toString(),
          v.grade,
          v.licensePlate ?? '',
          v.mileage.toString(),
          _formatDate(v.inspectionExpiryDate),
          v.assigneeName ?? '',
          _formatDate(v.leaseInfo?.contractEndDate),
          _formatDate(summary?.lastMaintenanceDate),
          summary?.totalCost.toString() ?? '',
        ];
        buffer.writeln(row.map(_escape).join(','));
      }

      return Result.success(buffer.toString());
    } catch (e) {
      return Result.failure(AppError.unknown('buildCsv failed: $e'));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) { return ''; }
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Sanitizes and quotes a field.
  ///
  /// 1. Formula injection guard: values starting with =, +, -, @ are
  ///    prefixed with a single quote so spreadsheet apps treat them as text.
  /// 2. RFC 4180 quoting for commas, quotes, and newlines.
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
