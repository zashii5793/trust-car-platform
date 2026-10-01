import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';

/// 車台番号の読み取り。
///
/// **車台番号は車両の一意識別子で、1文字欠けたら別の車になる。**
///
/// 2026-09-03 まで、プレフィックスを `[A-Z0-9]{2,4}` で拾っていたため、
/// 5文字以上のプレフィックスで**先頭が落ちていた**（`BNR35-123456` →
/// `NR35-123456`）。日本車では6文字のプレフィックスも珍しくない。
void main() {
  late VehicleCertificateOcrService service;

  setUp(() => service = VehicleCertificateOcrService());

  String? vin(String text) =>
      service.parseRawTextForTest('車台番号 $text').vinNumber;

  group('プレフィックスの長さ', () {
    test('3文字（ZN6-012345）', () {
      expect(vin('ZN6-012345'), 'ZN6-012345');
    });

    test('5文字（BNR35-123456）— 以前は先頭のBが落ちていた', () {
      expect(vin('BNR35-123456'), 'BNR35-123456');
    });

    test('6文字・英字終わり（ZVW30W-1234567）— 以前はZVが落ちていた', () {
      expect(vin('ZVW30W-1234567'), 'ZVW30W-1234567');
    });

    test('6文字・数字終わり（NCP131-0123456）— 以前はNCが落ちていた', () {
      expect(vin('NCP131-0123456'), 'NCP131-0123456');
    });

    test('6文字（GRS182-0012345）', () {
      expect(vin('GRS182-0012345'), 'GRS182-0012345');
    });
  });

  group('Edge Cases', () {
    test('ラベルと値が別の行でも読む', () {
      const text = '車台番号\nBNR35-123456';

      expect(service.parseRawTextForTest(text).vinNumber, 'BNR35-123456');
    });

    test('ナンバープレートの行を車台番号として拾わない', () {
      const text = '自動車検査証\n品川 300 あ 1234';

      expect(service.parseRawTextForTest(text).vinNumber, isNull);
    });

    test('電話番号を車台番号として拾わない', () {
      const text = '使用者 03-1234-5678';

      expect(service.parseRawTextForTest(text).vinNumber, isNull);
    });

    test('型式の行を車台番号として拾わない', () {
      const text = '型式 DBA-ZN6';

      expect(service.parseRawTextForTest(text).vinNumber, isNull);
    });
  });
}
