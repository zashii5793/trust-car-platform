// OCR accuracy report test.
//
// Runs the text parsing logic against known fixture texts and prints a
// detailed accuracy report to test output. Fails only if accuracy falls
// below the threshold defined per fixture.
//
// Run with:
//   flutter test test/ocr/ocr_accuracy_test.dart --reporter expanded
//
// Does NOT require a real device or MLKit — uses parseRawTextForTest()
// which bypasses the platform channel.

import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/services/invoice_ocr_service.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';

import '../fixtures/ocr/invoice_fixtures.dart';
import '../fixtures/ocr/vehicle_certificate_fixtures.dart';

void main() {
  final vcService = VehicleCertificateOcrService();
  final invService = InvoiceOcrService();

  // Track totals for the overall summary.
  var totalChecked = 0;
  var totalPassed = 0;

  group('OCR Accuracy Report — Vehicle Certificate', () {
    for (final fixture in vehicleCertificateFixtures) {
      test(fixture.name, () {
        final result = vcService.parseRawTextForTest(fixture.rawText);
        final report = _evaluateVehicleCertificate(result, fixture.expected);

        _printVehicleReport(fixture.name, report);

        totalChecked += report.totalFields;
        totalPassed += report.passedFields;

        expect(
          report.accuracy,
          greaterThanOrEqualTo(fixture.minimumAccuracy),
          reason: '${fixture.name}: accuracy ${(report.accuracy * 100).toStringAsFixed(1)}% '
              '< minimum ${(fixture.minimumAccuracy * 100).toStringAsFixed(0)}%',
        );
      });
    }
  });

  group('OCR Accuracy Report — Invoice', () {
    for (final fixture in invoiceFixtures) {
      test(fixture.name, () {
        final result = invService.parseRawTextForTest(fixture.rawText);
        final report = _evaluateInvoice(result, fixture.expected);

        _printInvoiceReport(fixture.name, report);

        totalChecked += report.totalFields;
        totalPassed += report.passedFields;

        expect(
          report.accuracy,
          greaterThanOrEqualTo(fixture.minimumAccuracy),
          reason: '${fixture.name}: accuracy ${(report.accuracy * 100).toStringAsFixed(1)}% '
              '< minimum ${(fixture.minimumAccuracy * 100).toStringAsFixed(0)}%',
        );
      });
    }
  });

  // Known limitations documented (not asserted — informational only).
  group('Known Limitations', () {
    test('5-char VIN prefix (BNR35- style) extracts partial match', () {
      final result = vcService.parseRawTextForTest(
        '車台番号 BNR35-123456',
      );
      // The regex [A-Z0-9]{2,4} matches at most 4-char prefixes.
      // BNR35 (5 chars) causes extraction to return a partial match.
      // This documents the known limitation — not a pass/fail regression.
      // See REAL_DATA_VALIDATION_CHECKLIST.md § Known Limitations.
      printOnFailure('VIN extracted: ${result.vinNumber} (expected BNR35-123456)');
      // We do NOT assert equality here — just document the behaviour.
    });

    test('新様式A6 ICカード: 所有者情報はICタグに格納されOCR取得不可', () {
      // The 2023 electronic 車検証 stores owner name/address on an IC tag,
      // not on the printed A6 card. OCR of the card alone returns null.
      // Testers must scan the accompanying A4 "記録事項" sheet instead.
      // Reference: https://www.denshishakensho-portal.mlit.go.jp/
      final result = vcService.parseRawTextForTest(
        '自動車検査証\n品川 300 あ 1234\n（所有者情報はICタグに格納）',
      );
      expect(result.ownerName, isNull,
          reason: '新様式ICカードではOCRで所有者名は取得できない（仕様）');
    });
  });
}

// ---------------------------------------------------------------------------
// Evaluation helpers
// ---------------------------------------------------------------------------

class _FieldResult {
  final String fieldName;
  final Object? expected;
  final Object? actual;
  bool get passed {
    if (expected == null) return true; // not expected — skip
    return _equals(expected, actual);
  }

  const _FieldResult(this.fieldName, this.expected, this.actual);

  static bool _equals(Object? a, Object? b) {
    if (a is DateTime && b is DateTime) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }
    return a == b;
  }
}

class _AccuracyReport {
  final List<_FieldResult> results;
  _AccuracyReport(this.results);

  int get totalFields => results.where((r) => r.expected != null).length;
  int get passedFields => results.where((r) => r.expected != null && r.passed).length;
  double get accuracy => totalFields == 0 ? 1.0 : passedFields / totalFields;
}

_AccuracyReport _evaluateVehicleCertificate(
  VehicleCertificateData actual,
  ExpectedVehicleCertificate expected,
) {
  return _AccuracyReport([
    _FieldResult('registrationNumber', expected.registrationNumber, actual.registrationNumber),
    _FieldResult('vinNumber', expected.vinNumber, actual.vinNumber),
    _FieldResult('modelCode', expected.modelCode, actual.modelCode),
    _FieldResult('maker', expected.maker, actual.maker),
    _FieldResult('model', expected.model, actual.model),
    _FieldResult('year', expected.year, actual.year),
    _FieldResult('inspectionExpiryDate', expected.inspectionExpiryDate, actual.inspectionExpiryDate),
    _FieldResult('ownerName', expected.ownerName, actual.ownerName),
    _FieldResult('engineDisplacement', expected.engineDisplacement, actual.engineDisplacement),
    _FieldResult('fuelType', expected.fuelType, actual.fuelType),
    _FieldResult('color', expected.color, actual.color),
    _FieldResult('maxCapacity', expected.maxCapacity, actual.maxCapacity),
    _FieldResult('vehicleWeight', expected.vehicleWeight, actual.vehicleWeight),
    _FieldResult('grossWeight', expected.grossWeight, actual.grossWeight),
  ]);
}

_AccuracyReport _evaluateInvoice(
  InvoiceData actual,
  ExpectedInvoice expected,
) {
  final itemCountMatch = expected.itemCount == null
      ? null
      : expected.itemCount;
  final actualItemCount = actual.items.length;

  return _AccuracyReport([
    _FieldResult('date', expected.date, actual.date),
    _FieldResult('totalAmount', expected.totalAmount, actual.totalAmount),
    _FieldResult('taxAmount', expected.taxAmount, actual.taxAmount),
    _FieldResult('subtotalAmount', expected.subtotalAmount, actual.subtotalAmount),
    _FieldResult('shopName', expected.shopName, actual.shopName),
    _FieldResult('shopPhone', expected.shopPhone, actual.shopPhone),
    _FieldResult('mileage', expected.mileage, actual.mileage),
    _FieldResult('itemCount', itemCountMatch, actualItemCount == 0 ? null : actualItemCount),
  ]);
}

// ---------------------------------------------------------------------------
// Report printers
// ---------------------------------------------------------------------------

void _printVehicleReport(String name, _AccuracyReport report) {
  // ignore: avoid_print
  print('\n[車検証] $name');
  for (final r in report.results) {
    if (r.expected == null) continue;
    final mark = r.passed ? '✓' : '✗';
    // ignore: avoid_print
    print('  $mark ${r.fieldName}: expected=${r.expected}, got=${r.actual}');
  }
  final pct = (report.accuracy * 100).toStringAsFixed(1);
  // ignore: avoid_print
  print('  Accuracy: ${report.passedFields}/${report.totalFields} = $pct%');
}

void _printInvoiceReport(String name, _AccuracyReport report) {
  // ignore: avoid_print
  print('\n[請求書] $name');
  for (final r in report.results) {
    if (r.expected == null) continue;
    final mark = r.passed ? '✓' : '✗';
    // ignore: avoid_print
    print('  $mark ${r.fieldName}: expected=${r.expected}, got=${r.actual}');
  }
  final pct = (report.accuracy * 100).toStringAsFixed(1);
  // ignore: avoid_print
  print('  Accuracy: ${report.passedFields}/${report.totalFields} = $pct%');
}
