import 'dart:convert';

import 'cp932_table.dart';

/// CSV ファイルの文字コード。
enum CsvEncoding {
  utf8('UTF-8'),
  cp932('Shift_JIS（Windows）');

  final String label;
  const CsvEncoding(this.label);
}

/// 読み取った CSV の本文と、どの文字コードで読んだか。
class DecodedCsvText {
  final String text;
  final CsvEncoding encoding;

  /// 読めなかったバイトの数。0 でなければ、画面で注意を出す。
  final int malformed;

  const DecodedCsvText(this.text, this.encoding, {this.malformed = 0});
}

/// CSV のバイト列を文字列にする。
///
/// **まず UTF-8 として厳密に読み、読めなければ CP932 として読む。**
/// 日本語の業務ソフトの書き出しはほぼ CP932（Windows の Shift_JIS）で、
/// Excel の「CSV UTF-8」で保存し直したものは UTF-8 になる。
/// どちらでも店が変換せずに取り込めるようにする。
///
/// CP932 の日本語を UTF-8 として読むと、ほぼ確実に不正な並びになるので、
/// 「UTF-8 で読めたら UTF-8」で取り違えは起きない。
DecodedCsvText decodeCsvBytes(List<int> bytes) {
  try {
    return DecodedCsvText(
      const Utf8Decoder(allowMalformed: false).convert(bytes),
      CsvEncoding.utf8,
    );
  } on FormatException {
    return decodeCp932(bytes);
  }
}

/// CP932 のバイト列を文字列にする。読めない文字は U+FFFD にして数える。
DecodedCsvText decodeCp932(List<int> bytes) {
  final out = StringBuffer();
  var malformed = 0;
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      out.writeCharCode(b);
      i++;
    } else if (b >= 0xA1 && b <= 0xDF) {
      // 半角カナ
      out.writeCharCode(0xFF61 + (b - 0xA1));
      i++;
    } else if (_leadIndex(b) != null && i + 1 < bytes.length) {
      final trail = bytes[i + 1];
      final t = _trailIndex(trail);
      if (t == null) {
        out.writeCharCode(0xFFFD);
        malformed++;
        i++;
        continue;
      }
      final c = cp932DoubleByteTable[_leadIndex(b)!].codeUnitAt(t);
      if (c == 0xFFFD) malformed++;
      out.writeCharCode(c);
      i += 2;
    } else {
      // 0x80, 0xA0, 0xFD-0xFF、または末尾で途切れた先頭バイト
      out.writeCharCode(0xFFFD);
      malformed++;
      i++;
    }
  }
  return DecodedCsvText(out.toString(), CsvEncoding.cp932,
      malformed: malformed);
}

int? _leadIndex(int b) {
  if (b >= 0x81 && b <= 0x9F) return b - 0x81;
  if (b >= 0xE0 && b <= 0xFC) return b - 0xE0 + 31;
  return null;
}

int? _trailIndex(int t) {
  if (t < 0x40 || t > 0xFC || t == 0x7F) return null;
  return t < 0x7F ? t - 0x40 : t - 0x41;
}
