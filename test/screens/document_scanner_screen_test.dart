// DocumentScannerScreen Widget Tests
//
// Note: The camera plugin requires platform hardware unavailable in the test
// environment. The MethodChannel call for availableCameras() remains pending
// indefinitely, so only the AppBar (rendered before camera init completes)
// can be reliably tested here.
//
// Coverage:
//   AppBar:
//     1. Shows document type name in title (車検証をスキャン)
//     2. Shows invoice document type name (請求書をスキャン)
//     3. Shows maintenance-record document type name (整備記録簿をスキャン)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/document_scanner_screen.dart';

Widget _buildScreen(DocumentType type) {
  return MaterialApp(home: DocumentScannerScreen(documentType: type));
}

void main() {
  group('DocumentScannerScreen — AppBar', () {
    testWidgets('1. 車検証タイプで「車検証をスキャン」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(DocumentType.vehicleCertificate));
      await tester.pump();

      expect(find.text('車検証をスキャン'), findsOneWidget);
    });

    testWidgets('2. 請求書タイプで「請求書をスキャン」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(DocumentType.invoice));
      await tester.pump();

      expect(find.text('請求書をスキャン'), findsOneWidget);
    });

    testWidgets('3. 整備記録簿タイプで「整備記録簿をスキャン」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(DocumentType.maintenanceRecord));
      await tester.pump();

      expect(find.text('整備記録簿をスキャン'), findsOneWidget);
    });
  });
}
