import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle.dart';

/// Service for exporting fleet vehicle lists as CSV.
///
/// Output starts with a UTF-8 BOM so Excel opens Japanese text correctly.
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
  ];

  /// Builds a CSV string for the given fleet vehicles.
  Result<String, AppError> buildCsv(List<Vehicle> vehicles) {
    try {
      final buffer = StringBuffer(_bom);
      buffer.writeln(_headers.map(_escape).join(','));

      for (final v in vehicles) {
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

  /// Quotes a field when it contains commas, quotes, or newlines (RFC 4180).
  String _escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
