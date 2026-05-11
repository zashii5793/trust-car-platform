// ExportDialog Widget Tests
//
// Coverage:
//   Title:
//     1. Shows 'メンテナンス履歴をエクスポート' title
//     2. Shows vehicle name in subtitle
//     3. Shows record count in subtitle
//   Loading state:
//     4. Shows 'PDFを生成中...' while generating
//   Actions (after PDF generated):
//     5. Shows 'プレビュー / 印刷' option
//     6. Shows '共有' option
//     7. Shows 'ダイレクト印刷' option
//   Cancel:
//     8. Shows 'キャンセル' button
//   Edge Cases:
//     9. Vehicle name displayed in title
//    10. Record count 0 shown in subtitle

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/screens/export/export_dialog.dart';
import 'package:trust_car_platform/services/pdf_export_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';

// ---------------------------------------------------------------------------
// Stub PdfExportService
// ---------------------------------------------------------------------------

class _StubPdfExportService implements PdfExportService {
  // Returns empty PDF bytes to avoid heavy processing in tests
  @override
  Future<Uint8List> generateMaintenanceReport({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
  }) async {
    return Uint8List(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String maker = 'トヨタ',
  String model = 'カムリ',
}) {
  final now = DateTime(2025, 1, 1);
  return Vehicle(
    id: 'vehicle-1',
    userId: 'user-1',
    maker: maker,
    model: model,
    year: 2021,
    grade: 'G',
    mileage: 20000,
    createdAt: now,
    updatedAt: now,
  );
}

MaintenanceRecord _makeRecord({String id = 'rec-1'}) {
  final now = DateTime(2025, 6, 1);
  return MaintenanceRecord(
    id: id,
    vehicleId: 'vehicle-1',
    userId: 'user-1',
    type: MaintenanceType.oilChange,
    title: 'オイル交換',
    cost: 5000,
    date: now,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder — wraps showExportDialog in a scaffold
// ---------------------------------------------------------------------------

Widget _buildLauncher({
  required Vehicle vehicle,
  required List<MaintenanceRecord> records,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showExportDialog(
              context: context,
              vehicle: vehicle,
              records: records,
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    ServiceLocator.instance.override<PdfExportService>(
      _StubPdfExportService(),
    );
  });

  tearDown(() {
    ServiceLocator.instance.unregister<PdfExportService>();
  });

  group('ExportDialog — Title', () {
    testWidgets('1. shows メンテナンス履歴をエクスポート title', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('メンテナンス履歴をエクスポート'), findsOneWidget);
    });

    testWidgets('2. shows vehicle name in subtitle', (tester) async {
      final vehicle = _makeVehicle(maker: 'ホンダ', model: 'シビック');
      await tester.pumpWidget(
        _buildLauncher(vehicle: vehicle, records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ホンダ'), findsWidgets);
      expect(find.textContaining('シビック'), findsWidgets);
    });

    testWidgets('3. shows record count in subtitle', (tester) async {
      final records = [
        _makeRecord(id: '1'),
        _makeRecord(id: '2'),
        _makeRecord(id: '3'),
      ];
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: records),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3件'), findsOneWidget);
    });
  });

  group('ExportDialog — Loading state', () {
    testWidgets('4. shows PDFを生成中 while loading', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump(); // single tick — still loading

      expect(find.textContaining('PDFを生成中'), findsOneWidget);
    });
  });

  group('ExportDialog — Actions', () {
    testWidgets('5. shows プレビュー / 印刷 option after generation', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('プレビュー / 印刷'), findsOneWidget);
    });

    testWidgets('6. shows 共有 option', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('共有'), findsOneWidget);
    });

    testWidgets('7. shows ダイレクト印刷 option', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('ダイレクト印刷'), findsOneWidget);
    });
  });

  group('ExportDialog — Cancel', () {
    testWidgets('8. shows キャンセル button', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('キャンセル'), findsOneWidget);
    });
  });

  group('ExportDialog — Edge Cases', () {
    testWidgets('9. vehicle name shown in subtitle', (tester) async {
      final vehicle = _makeVehicle(maker: 'スバル', model: 'インプレッサ');
      await tester.pumpWidget(
        _buildLauncher(vehicle: vehicle, records: [_makeRecord()]),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('スバル'), findsWidgets);
      expect(find.textContaining('インプレッサ'), findsWidgets);
    });

    testWidgets('10. record count 0 shown in subtitle', (tester) async {
      await tester.pumpWidget(
        _buildLauncher(vehicle: _makeVehicle(), records: []),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('0件'), findsOneWidget);
    });
  });
}
