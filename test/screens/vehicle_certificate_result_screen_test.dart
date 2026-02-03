import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/vehicle_certificate_result_screen.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';

void main() {
  // テスト用のモック画像ファイル
  late File mockImageFile;

  setUpAll(() {
    // テスト用の一時ファイルパス（実際には存在しなくてもWidgetテストは動く）
    mockImageFile = File('/tmp/test_image.jpg');
  });

  Widget createTestWidget({
    required VehicleCertificateData ocrData,
  }) {
    return MaterialApp(
      home: VehicleCertificateResultScreen(
        imageFile: mockImageFile,
        ocrData: ocrData,
      ),
    );
  }

  group('VehicleCertificateResultScreen', () {
    testWidgets('AppBarに「読み取り結果の確認」が表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      expect(find.text('読み取り結果の確認'), findsOneWidget);
    });

    testWidgets('OCRで読み取ったメーカーがテキストフィールドに表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      // TextFieldにトヨタが設定されていることを確認
      final textField = find.widgetWithText(TextField, 'トヨタ');
      expect(textField, findsOneWidget);
    });

    testWidgets('OCRで読み取った車種がテキストフィールドに表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(model: 'プリウス'),
      ));

      final textField = find.widgetWithText(TextField, 'プリウス');
      expect(textField, findsOneWidget);
    });

    testWidgets('OCRで読み取った年式がテキストフィールドに表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(year: 2020),
      ));

      final textField = find.widgetWithText(TextField, '2020');
      expect(textField, findsOneWidget);
    });

    testWidgets('信頼度スコアカードが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(
          maker: 'トヨタ',
          model: 'プリウス',
          year: 2020,
        ),
      ));

      // 読み取り精度のテキストを探す
      expect(find.textContaining('読み取り精度'), findsOneWidget);
    });

    testWidgets('高い信頼度スコアの場合、緑のアイコンが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(
          registrationNumber: '品川 300 あ 12-34',
          vinNumber: 'ZVW50-1234567',
          modelCode: 'DBA-ZVW50',
          maker: 'トヨタ',
          model: 'プリウス',
          year: 2020,
          inspectionExpiryDate: DateTime(2025, 5, 20),
          ownerName: '山田太郎',
          ownerAddress: '東京都品川区',
          engineDisplacement: 1800,
          fuelType: 'ハイブリッド',
        ),
      ));

      // check_circleアイコンを探す
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('低い信頼度スコアの場合、警告アイコンが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(
          maker: 'トヨタ',
        ),
      ));

      // warningまたはinfoアイコンを探す
      final warningIcon = find.byIcon(Icons.warning);
      final infoIcon = find.byIcon(Icons.info);
      expect(warningIcon.evaluate().isNotEmpty || infoIcon.evaluate().isNotEmpty, true);
    });

    testWidgets('セクションヘッダーが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      expect(find.text('基本情報'), findsOneWidget);
      expect(find.text('識別情報'), findsOneWidget);
      expect(find.text('車検・保険'), findsOneWidget);
      expect(find.text('詳細情報'), findsOneWidget);
    });

    testWidgets('車検・保険セクションに「重要」バッジが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      expect(find.text('重要'), findsOneWidget);
    });

    testWidgets('「この内容で登録」ボタンが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      expect(find.text('この内容で登録'), findsOneWidget);
    });

    testWidgets('「キャンセル」ボタンが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('車検満了日タイルが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(
          inspectionExpiryDate: DateTime(2025, 5, 20),
        ),
      ));

      expect(find.text('車検満了日'), findsOneWidget);
      // 日付がフォーマットされて表示される
      expect(find.textContaining('2025年5月20日'), findsOneWidget);
    });

    testWidgets('車検満了日が未設定の場合、「未設定」が表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      expect(find.text('車検満了日'), findsOneWidget);
      expect(find.textContaining('未設定'), findsOneWidget);
    });

    testWidgets('燃料タイプのChoiceChipが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      // 全ての燃料タイプが表示される
      expect(find.text('ガソリン'), findsOneWidget);
      expect(find.text('ディーゼル'), findsOneWidget);
      expect(find.text('ハイブリッド'), findsOneWidget);
      expect(find.text('電気'), findsOneWidget);
    });

    testWidgets('OCRで読み取った燃料タイプが選択されている', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(fuelType: 'ハイブリッド'),
      ));

      // ハイブリッドのChoiceChipが選択されている
      final chip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('ハイブリッド'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip.selected, true);
    });

    testWidgets('画像表示ボタンをタップすると画像ビューに切り替わる', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      // 画像表示ボタンをタップ
      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();

      // InteractiveViewerが表示される（画像ビューモード）
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('メーカーと車種が空の場合、登録ボタンを押すとエラーメッセージが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(),
      ));

      // 登録ボタンをタップ
      await tester.tap(find.text('この内容で登録'));
      await tester.pumpAndSettle();

      // エラーメッセージが表示される
      expect(find.text('メーカーまたは車種を入力してください'), findsOneWidget);
    });

    testWidgets('キャンセルボタンをタップすると画面が閉じる', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(maker: 'トヨタ'),
      ));

      // キャンセルボタンをタップ
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // 画面が閉じる（MaterialAppのみ残る）
      expect(find.byType(VehicleCertificateResultScreen), findsNothing);
    });

    testWidgets('OCRで読み取った項目にスターアイコンが表示される', (tester) async {
      await tester.pumpWidget(createTestWidget(
        ocrData: VehicleCertificateData(
          maker: 'トヨタ',
          vinNumber: 'ZVW50-1234567',
        ),
      ));

      // auto_awesomeアイコン（OCR読み取り済みマーク）が表示される
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    });
  });

  group('VehicleRegistrationData', () {
    test('正しく初期化される', () {
      final data = VehicleRegistrationData(
        maker: 'トヨタ',
        model: 'プリウス',
        year: 2020,
        licensePlate: '品川 300 あ 12-34',
        vinNumber: 'ZVW50-1234567',
        modelCode: 'DBA-ZVW50',
        inspectionExpiryDate: DateTime(2025, 5, 20),
        engineDisplacement: 1800,
        fuelType: FuelType.hybrid,
        color: '白',
      );

      expect(data.maker, 'トヨタ');
      expect(data.model, 'プリウス');
      expect(data.year, 2020);
      expect(data.licensePlate, '品川 300 あ 12-34');
      expect(data.vinNumber, 'ZVW50-1234567');
      expect(data.modelCode, 'DBA-ZVW50');
      expect(data.inspectionExpiryDate, DateTime(2025, 5, 20));
      expect(data.engineDisplacement, 1800);
      expect(data.fuelType, FuelType.hybrid);
      expect(data.color, '白');
    });

    test('オプショナルフィールドがnullでも初期化できる', () {
      final data = VehicleRegistrationData(
        maker: 'トヨタ',
        model: 'プリウス',
      );

      expect(data.maker, 'トヨタ');
      expect(data.model, 'プリウス');
      expect(data.year, null);
      expect(data.licensePlate, null);
      expect(data.vinNumber, null);
      expect(data.modelCode, null);
      expect(data.inspectionExpiryDate, null);
      expect(data.engineDisplacement, null);
      expect(data.fuelType, null);
      expect(data.color, null);
    });
  });
}
