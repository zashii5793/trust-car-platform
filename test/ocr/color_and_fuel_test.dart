import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';

/// 色と燃料の読み取り。
///
/// どちらも「ラベルの行」と「その次の行」を見る。**ML Kit はラベルと値を
/// 別ブロックで返すことが多い**ので、次の行を見ないと値が取れない。
///
/// 2026-09-03 まで、燃料は次の行を見るのに**色だけ見ていなかった**。
void main() {
  late VehicleCertificateOcrService service;

  setUp(() => service = VehicleCertificateOcrService());

  group('色', () {
    test('ラベルと値が同じ行', () {
      expect(service.parseRawTextForTest('車体の色 白').color, '白');
    });

    test('ラベルと値が別の行 — 以前は取れなかった', () {
      expect(service.parseRawTextForTest('車体の色\n白').color, '白');
    });

    test('カタカナ表記も別の行で読める', () {
      expect(service.parseRawTextForTest('車体の色\nシルバー').color, 'シルバー');
    });

    test('同じ行の値が、次の行より優先される', () {
      // 次の行に住所（青森）が来ても、ラベル行の「灰」を採る
      expect(service.parseRawTextForTest('車体の色 灰\n青森県青森市1-2').color, '灰');
    });
  });

  group('燃料', () {
    test('ラベルと値が同じ行', () {
      expect(service.parseRawTextForTest('燃料の種類 ガソリン').fuelType, 'ガソリン');
    });

    test('ラベルと値が別の行', () {
      expect(service.parseRawTextForTest('燃料の種類\n軽油').fuelType, '軽油');
    });

    test('同じ行の値が、次の行より優先される', () {
      expect(
        service.parseRawTextForTest('燃料の種類 軽油\nガソリンスタンド利用可').fuelType,
        '軽油',
      );
    });
  });

  group('Edge Cases', () {
    test('色のラベルが無ければ何も取らない', () {
      expect(service.parseRawTextForTest('所有者 東京都港区白金1-2').color, isNull);
    });

    test('値が候補に無ければ null', () {
      expect(service.parseRawTextForTest('車体の色\n（記載なし）').color, isNull);
    });
  });
}
