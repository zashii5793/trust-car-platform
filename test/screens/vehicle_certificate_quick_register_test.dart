// OCR result screen — quick-register ("このまま登録") tests.
//
// The onboarding wedge is a friction-free OCR → 車検 reminder. When OCR has
// already captured every required field (maker / model / year / inspection
// expiry), the user should be able to register in one tap without walking the
// 3-step wizard.
//
// RED → GREEN → REFACTOR.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/vehicle_certificate_result_screen.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';

void main() {
  final dummyImage = File('test/assets/dummy.jpg');

  Future<VehicleRegistrationData?> pumpAndCapture(
    WidgetTester tester,
    VehicleCertificateData ocrData,
  ) async {
    VehicleRegistrationData? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await Navigator.push<VehicleRegistrationData>(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleCertificateResultScreen(
                    imageFile: dummyImage,
                    ocrData: ocrData,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return captured;
  }

  testWidgets('必須項目が揃っていれば「このまま登録」ボタンが表示される', (tester) async {
    final ocrData = VehicleCertificateData(
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2020,
      inspectionExpiryDate: DateTime(2027, 3, 1),
    );

    await pumpAndCapture(tester, ocrData);

    expect(find.text('このまま登録'), findsOneWidget);
  });

  testWidgets('車検満了日が欠けていれば「このまま登録」ボタンは表示されない', (tester) async {
    final ocrData = VehicleCertificateData(
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2020,
      // inspectionExpiryDate なし
    );

    await pumpAndCapture(tester, ocrData);

    expect(find.text('このまま登録'), findsNothing);
    // 通常の編集ボタンは常に存在する
    expect(find.text('この内容で登録'), findsOneWidget);
  });

  testWidgets('「このまま登録」をタップすると quickRegister=true で pop する', (tester) async {
    final ocrData = VehicleCertificateData(
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2020,
      inspectionExpiryDate: DateTime(2027, 3, 1),
    );

    final result = await pumpAndCaptureThenTapQuick(tester, ocrData);

    expect(result, isNotNull);
    expect(result!.quickRegister, isTrue);
    expect(result.maker, 'トヨタ');
    expect(result.inspectionExpiryDate, DateTime(2027, 3, 1));
  });

  testWidgets('通常の「この内容で登録」は quickRegister=false で pop する', (tester) async {
    final ocrData = VehicleCertificateData(
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2020,
      inspectionExpiryDate: DateTime(2027, 3, 1),
    );

    VehicleRegistrationData? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await Navigator.push<VehicleRegistrationData>(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleCertificateResultScreen(
                    imageFile: dummyImage,
                    ocrData: ocrData,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.quickRegister, isFalse);
  });
}

/// Open the result screen and tap the quick-register button, returning the
/// popped data.
Future<VehicleRegistrationData?> pumpAndCaptureThenTapQuick(
  WidgetTester tester,
  VehicleCertificateData ocrData,
) async {
  final dummyImage = File('test/assets/dummy.jpg');
  VehicleRegistrationData? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            captured = await Navigator.push<VehicleRegistrationData>(
              context,
              MaterialPageRoute(
                builder: (_) => VehicleCertificateResultScreen(
                  imageFile: dummyImage,
                  ocrData: ocrData,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('このまま登録'));
  await tester.pumpAndSettle();
  return captured;
}
