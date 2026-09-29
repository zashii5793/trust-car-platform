// 利用規約・プライバシーポリシーのアプリ内の文面を、Web 版（正本）から作る。
//
//   dart run tool/gen_policy_texts.dart
//
// 正本は web/terms.html と web/privacy.html。アプリ内の画面は、この道具が
// 書き出す lib/screens/settings/policy_texts.g.dart を表示するだけにする。
//
// 以前はアプリ内の文面を手で写していて、2026-09-29 に次のずれが見つかった:
//   - 規約第12条: アプリは「退会後30日間保持」のまま（Web と実装は即時削除）
//   - プライバシーポリシー: 章の構成が違う（Cookie の章がアプリに無い）
// test/core/policy_texts_sync_test.dart が、生成物が Web 版と同じかを確かめる。

import 'dart:io';

class PolicySectionData {
  final String title;
  final String content;
  const PolicySectionData(this.title, this.content);
}

class PolicyData {
  final String meta;
  final List<PolicySectionData> sections;
  const PolicyData(this.meta, this.sections);
}

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ');

/// タグを外して文字だけにする。ソースの改行・字下げは詰め、`<br>` だけを
/// 改行として残す（順番が逆だと `<br>` の改行まで消える）。
String _text(String html) => _unescape(html
        .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ''))
    .trim();

/// HTML の本文を、見出し（h2）ごとの文面に分ける。
///
/// - `<ol>` は「1. 」から番号を振る
/// - `<ul>` は「・」を付ける
/// - `<p>` はそのまま
/// ブロックの間は改行1つ。
PolicyData parsePolicyHtml(String html) {
  final body = html.substring(html.indexOf('<body'));
  final meta = RegExp(r'<p class="meta">([\s\S]*?)</p>').firstMatch(body);
  final sections = <PolicySectionData>[];
  final h2 = RegExp(r'<h2>([\s\S]*?)</h2>');
  final matches = h2.allMatches(body).toList();
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].end;
    var end = i + 1 < matches.length ? matches[i + 1].start : body.length;
    final footer = body.indexOf('<footer', start);
    if (footer != -1 && footer < end) end = footer;
    final chunk = body.substring(start, end);
    final lines = <String>[];
    final block = RegExp(r'<(ol|ul|p)(?:\s[^>]*)?>([\s\S]*?)</\1>');
    for (final b in block.allMatches(chunk)) {
      final tag = b.group(1)!;
      final inner = b.group(2)!;
      if (tag == 'p') {
        final t = _text(inner);
        if (t.isNotEmpty) lines.add(t);
        continue;
      }
      final items = RegExp(r'<li(?:\s[^>]*)?>([\s\S]*?)</li>')
          .allMatches(inner)
          .map((m) => _text(m.group(1)!))
          .toList();
      for (var k = 0; k < items.length; k++) {
        lines.add(tag == 'ol' ? '${k + 1}. ${items[k]}' : '・${items[k]}');
      }
    }
    sections.add(PolicySectionData(_text(matches[i].group(1)!), lines.join('\n')));
  }
  return PolicyData(meta == null ? '' : _text(meta.group(1)!), sections);
}

String _dartString(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}

String renderDart(PolicyData terms, PolicyData privacy) {
  final b = StringBuffer()
    ..writeln('// 生成物。手で直さない。')
    ..writeln('// 正本は web/terms.html と web/privacy.html。直したら次で作り直す:')
    ..writeln('//   dart run tool/gen_policy_texts.dart')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln('class PolicySectionText {')
    ..writeln('  final String title;')
    ..writeln('  final String content;')
    ..writeln('  const PolicySectionText(this.title, this.content);')
    ..writeln('}')
    ..writeln()
    ..writeln('class PolicyText {')
    ..writeln('  final String meta;')
    ..writeln('  final List<PolicySectionText> sections;')
    ..writeln('  const PolicyText(this.meta, this.sections);')
    ..writeln('}')
    ..writeln();
  void write(String name, PolicyData d) {
    b
      ..writeln('const $name = PolicyText(')
      ..writeln('  ${_dartString(d.meta)},')
      ..writeln('  [');
    for (final s in d.sections) {
      b.writeln(
          '    PolicySectionText(${_dartString(s.title)}, ${_dartString(s.content)}),');
    }
    b
      ..writeln('  ],')
      ..writeln(');')
      ..writeln();
  }

  write('termsText', terms);
  write('privacyText', privacy);
  return b.toString();
}

const outputPath = 'lib/screens/settings/policy_texts.g.dart';

String generate() => renderDart(
      parsePolicyHtml(File('web/terms.html').readAsStringSync()),
      parsePolicyHtml(File('web/privacy.html').readAsStringSync()),
    );

void main() {
  File(outputPath).writeAsStringSync(generate());
  stdout.writeln('wrote $outputPath');
}
