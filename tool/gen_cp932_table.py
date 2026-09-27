#!/usr/bin/env python3
"""CP932（Windows の Shift_JIS）の変換表を Dart に書き出す。

整備管理ソフトの CSV は Windows で書き出されるため、素の Shift_JIS ではなく
CP932 になる。「髙」「㈱」「①」のような拡張文字は素の Shift_JIS の変換器では
読めない（charset 2.0.1 で実測: 髙 = 0xFBFC で FormatException）。

Python 標準の cp932 コーデックを正として、2バイト文字の表を作る。

    python3 tool/gen_cp932_table.py > lib/core/encoding/cp932_table.dart
"""

LEADS = list(range(0x81, 0xA0)) + list(range(0xE0, 0xFD))
TRAILS = [t for t in range(0x40, 0xFD) if t != 0x7F]

def ch(lead, trail):
    try:
        s = bytes([lead, trail]).decode("cp932")
    except UnicodeDecodeError:
        return "�"
    return s if len(s) == 1 else "�"

def dart_escape(s):
    out = []
    for c in s:
        if c in "\\'$":
            out.append("\\" + c)
        elif ord(c) < 0x20 or 0xD800 <= ord(c) <= 0xDFFF or c == "�":
            out.append("\\u{%x}" % ord(c))
        else:
            out.append(c)
    return "".join(out)

print("// 生成物。手で直さない。tool/gen_cp932_table.py で作り直す。")
print("// ignore_for_file: lines_longer_than_80_chars")
print()
print("/// 2バイト文字の先頭バイト（0x81-0x9F, 0xE0-0xFC）ごとの文字列。")
print("/// 2バイト目 0x40-0xFC（0x7F を除く）の順に並べてある。読めない所は U+FFFD。")
print("const List<String> cp932DoubleByteTable = [")
for lead in LEADS:
    row = "".join(ch(lead, t) for t in TRAILS)
    assert len(row) == len(TRAILS)
    print("  '%s', // 0x%02X" % (dart_escape(row), lead))
print("];")
