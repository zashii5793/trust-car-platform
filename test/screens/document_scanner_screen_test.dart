// DocumentScannerScreen Widget Tests
//
// Note: The camera plugin requires platform hardware unavailable in the test
// environment. The MethodChannel call for availableCameras() remains pending
// indefinitely, so only the AppBar and loading view (rendered before camera
// init completes) can be reliably tested here.
//
// Coverage:
//   AppBar:
//     1. Shows document type name in title (車検証をスキャン)
//     2. Shows invoice document type name (請求書をスキャン)
//     3. Shows maintenance-record document type name (整備記録簿をスキャン)
//   Loading view (camera pending):
//     4. Shows loading indicator
//     5. Shows カメラを起動中... text
//     6. No exception during camera init
//   DocumentType enum:
//     7. vehicleCertificate displayName / instruction
//     8. invoice displayName / instruction
//     9. maintenanceRecord displayName / instruction

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

  group('DocumentScannerScreen — Loading view', () {
    testWidgets('4. カメラ起動中はCircularProgressIndicatorが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(DocumentType.vehicleCertificate));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('5. カメラ起動中は「カメラを起動中...」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(DocumentType.vehicleCertificate));
      await tester.pump();

      expect(find.text('カメラを起動中...'), findsOneWidget);
    });

    testWidgets('6. カメラ初期化中に例外が発生しない', (tester) async {
      await tester.pumpWidget(_buildScreen(DocumentType.invoice));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('DocumentType enum', () {
    test('7. vehicleCertificate のdisplayNameとinstructionが正しい', () {
      const t = DocumentType.vehicleCertificate;
      expect(t.displayName, '車検証');
      expect(t.instruction, '車検証を枠内に収めてください');
    });

    test('8. invoice のdisplayNameとinstructionが正しい', () {
      const t = DocumentType.invoice;
      expect(t.displayName, '請求書');
      expect(t.instruction, '請求書を枠内に収めてください');
    });

    test('9. maintenanceRecord のdisplayNameとinstructionが正しい', () {
      const t = DocumentType.maintenanceRecord;
      expect(t.displayName, '整備記録簿');
      expect(t.instruction, '整備記録簿を枠内に収めてください');
    });
  });
}

