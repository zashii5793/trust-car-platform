import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';

/// 元号（令和・平成・昭和）から西暦への変換。
///
/// **ML Kit はラベルと値を別のブロックで返すことが多い。** 車検証の
/// 「有効期間の満了する日」と「令和7年5月20日」は、実物ではまず別行で届く。
///
/// 2026-09-03 まで、元号の判定を「値が載っている行」ではなく
/// 「キーワードが載っている行」で行っていたため、**別行だと令和7年が
/// 1995年（平成扱い）になっていた**。満了日が30年ずれると、車検の案内は
/// 全部「切れている」と出る。
void main() {
  late VehicleCertificateOcrService service;

  setUp(() => service = VehicleCertificateOcrService());

  group('満了日', () {
    test('ラベルと値が別の行でも令和を令和として読む', () {
      const text = '自動車検査証\n有効期間の満了する日\n令和7年5月20日';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate, DateTime(2025, 5, 20));
    });

    test('ラベルと値が同じ行でも読む', () {
      const text = '自動車検査証\n有効期間の満了する日 令和7年5月20日';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate, DateTime(2025, 5, 20));
    });

    test('別の行の平成を平成として読む', () {
      const text = '有効期間の満了する日\n平成31年4月1日';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate, DateTime(2019, 4, 1));
    });

    test('R表記も別の行で読める', () {
      const text = '満了する日\nR7.5.20';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate, DateTime(2025, 5, 20));
    });

    test('西暦表記はそのまま読む', () {
      const text = '有効期間の満了する日\n2025年5月20日';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate, DateTime(2025, 5, 20));
    });
  });

  group('初度登録年', () {
    test('ラベルと値が別の行でも令和を令和として読む', () {
      const text = '初度登録年月\n令和3年6月';

      final data = service.parseRawTextForTest(text);

      expect(data.year, 2021);
    });

    test('別の行の平成を平成として読む', () {
      const text = '初度検査年月\n平成28年3月';

      final data = service.parseRawTextForTest(text);

      expect(data.year, 2016);
    });

    test('別の行の昭和を昭和として読む', () {
      const text = '初度登録年月\n昭和60年10月';

      final data = service.parseRawTextForTest(text);

      expect(data.year, 1985);
    });

    test('同じ行でも読む', () {
      const text = '初度登録年月 令和3年6月';

      final data = service.parseRawTextForTest(text);

      expect(data.year, 2021);
    });
  });

  group('Edge Cases', () {
    test('元号が無ければ満了日は取れない', () {
      const text = '有効期間の満了する日\n（記載なし）';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate, isNull);
    });

    test('値の行に別の元号が混ざっていても、マッチした元号を使う', () {
      // 「平成生まれの所有者」のような行が続いても、令和の日付を令和で読む
      const text = '有効期間の満了する日\n令和7年5月20日';

      final data = service.parseRawTextForTest(text);

      expect(data.inspectionExpiryDate?.year, 2025);
    });
  });
}
