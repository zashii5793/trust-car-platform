import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/encoding/csv_text_decoder.dart';

/// CSV の文字コード。
///
/// 整備管理ソフトの書き出しは Windows の Shift_JIS（CP932）。**素の
/// Shift_JIS の変換器では「髙」「㈱」「①」が読めない**（charset 2.0.1 で
/// 実測。社名や人名に普通に出てくる）。期待値は Python 標準の cp932 で
/// デコードした結果を正とした。
void main() {
  group('decodeCp932', () {
    final cases = <(String, List<int>, String)>[
      (
        '見出し',
        [0x8C, 0xDA, 0x8B, 0x71, 0x96, 0xBC, 0x2C, 0x8E, 0xD4, 0x96, 0xBC],
        '\u{9867}\u{5ba2}\u{540d},\u{8eca}\u{540d}'
      ),
      (
        'NEC特殊文字（㈱・①）',
        [
          0x87,
          0x8A,
          0x83,
          0x54,
          0x83,
          0x93,
          0x83,
          0x76,
          0x83,
          0x8B,
          0x89,
          0x5E,
          0x97,
          0x41,
          0x20,
          0x87,
          0x40,
          0x87,
          0x41,
          0x87,
          0x42
        ],
        '\u{3231}\u{30b5}\u{30f3}\u{30d7}\u{30eb}\u{904b}\u{8f38} \u{2460}\u{2461}\u{2462}'
      ),
      ('IBM拡張（髙 0xFBFC）', [0xFB, 0xFC], '\u{9ad9}'),
      ('NEC選定IBM拡張（髙 0xEEE0）', [0xEE, 0xE0], '\u{9ad9}'),
      (
        '半角カナと濁点',
        [0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0x20, 0xCA, 0xDF, 0xDD],
        '\u{ff71}\u{ff72}\u{ff73}\u{ff74}\u{ff75} \u{ff8a}\u{ff9f}\u{ff9d}'
      ),
      (
        '記号',
        [
          0x81,
          0x60,
          0x81,
          0x7C,
          0x81,
          0x61,
          0x81,
          0x91,
          0x81,
          0x92,
          0x81,
          0xCA
        ],
        '\u{ff5e}\u{ff0d}\u{2225}\u{ffe0}\u{ffe1}\u{ffe2}'
      ),
      ('異体字（﨑・德）', [0xED, 0x95, 0x20, 0xED, 0x9E], '\u{fa11} \u{5fb7}'),
      (
        '全角英数',
        [0x82, 0x6D, 0x81, 0x7C, 0x82, 0x61, 0x82, 0x6E, 0x82, 0x77],
        '\u{ff2e}\u{ff0d}\u{ff22}\u{ff2f}\u{ff38}'
      ),
    ];
    for (final (name, bytes, expected) in cases) {
      test(name, () {
        final r = decodeCp932(bytes);
        expect(r.text, expected);
        expect(r.malformed, 0);
      });
    }

    group('Edge Cases', () {
      test('空なら空', () {
        expect(decodeCp932(const []).text, '');
      });

      test('末尾で途切れた2バイト文字は U+FFFD にして数える', () {
        final r = decodeCp932([0x41, 0x8C]);
        expect(r.text, 'A\u{fffd}');
        expect(r.malformed, 1);
      });

      test('2バイト目が範囲外なら U+FFFD にして数え、次のバイトから読み直す', () {
        final r = decodeCp932([0x8C, 0x0A, 0x41]);
        expect(r.text, '\u{fffd}\nA');
        expect(r.malformed, 1);
      });
    });
  });

  group('decodeCsvBytes', () {
    test('UTF-8 なら UTF-8 として読む', () {
      final r = decodeCsvBytes(utf8.encode('顧客名,車名'));
      expect(r.encoding, CsvEncoding.utf8);
      expect(r.text, '顧客名,車名');
    });

    test('UTF-8 として読めなければ CP932 として読む', () {
      // 「顧客名」の CP932
      final r = decodeCsvBytes([0x8C, 0xDA, 0x8B, 0x71, 0x96, 0xBC]);
      expect(r.encoding, CsvEncoding.cp932);
      expect(r.text, '顧客名');
    });

    group('Edge Cases', () {
      test('ASCII だけなら UTF-8 扱い（どちらで読んでも同じ）', () {
        final r = decodeCsvBytes(ascii.encode('a,b'));
        expect(r.encoding, CsvEncoding.utf8);
      });

      test('空なら UTF-8 の空文字', () {
        final r = decodeCsvBytes(const []);
        expect(r.text, '');
      });
    });
  });
}
