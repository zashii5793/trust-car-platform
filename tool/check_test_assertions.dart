// 確かめ（expect など）が1つも無い test / testWidgets を拾う。
//
//   dart run tool/check_test_assertions.dart               # test/ と integration_test/
//   dart run tool/check_test_assertions.dart test/screens  # 場所を絞る
//
// 1件でも見つかったら終了コード 1。CI（ci.yml の Analyze & Test）から呼ぶ。
//
// なぜ要るか（Issue #203）:
//   2026-09-20 に integration_test/year_of_use_app_test.dart が「All tests
//   passed」のまま、撮れていたのはログイン画面だった。手順がすべて
//   `if (見つかったら) { 押す }` で囲われていて expect が1つも無く、構造上
//   ぜったいに落ちなかった。落ちないテストは、確かめた気にさせるぶん無いより悪い。
//
// 何を「確かめ」と数えるか:
//   - expect / expectLater / expectAsync* / fail / assert
//     と、名前が expect・verify・assert で始まる呼び出し（mockito の verify、
//     expectNoOverflow のような補助関数、robot.expectLoggedIn() など）
//   - 同じファイルにある、上のどれかを含む関数の呼び出し（何段でも辿る）
//   - 補助ファイル（*_test.dart でないもの）にある、上のどれかを含む公開関数の
//     呼び出し（test/ と integration_test/ 全体から集める。collectHelperNames）
//
// 「落ちないこと」自体が目的のテストは、expectLater(f(), completes) や
// expect(tester.takeException(), isNull) のように、それを確かめとして書く。
//
// Dart の構文解析器（package:analyzer）は使わない。dev_dependencies に足すと
// pubspec が変わり、CI の iOS ビルド（macOS ランナー、課金10倍）が走るため。
// 代わりにコメントと文字列を空白で塗りつぶしてから括弧を数える。

import 'dart:io';

/// 確かめの無いテスト1件。
class Finding {
  final String path;

  /// 1 始まりの行番号（test( の行）
  final int line;

  /// 'test' か 'testWidgets'
  final String kind;

  /// test( の直後から1行ぶん（名前の文字列が入る）
  final String name;

  const Finding(this.path, this.line, this.kind, this.name);

  @override
  String toString() => '$path:$line: $kind $name';
}

/// 確かめの呼び出し。直前が識別子の文字なら別の名前の一部なので外す。
/// `.` は許す（robot.expectLoggedIn() のようなメソッドも数える）。
final _assertionCall = RegExp(
  r'(?<![A-Za-z0-9_$])_?(?:expect|verify|assert)[A-Za-z0-9_]*\s*\(|'
  r'(?<![A-Za-z0-9_$.])fail\s*\(',
);

/// テストの呼び出し。直前が `.` や識別子の文字なら対象外（r.test( など）。
final _testCall = RegExp(r'(?<![A-Za-z0-9_$.])(testWidgets|test)\s*\(');

/// 関数・メソッドの宣言の頭（名前と、引数の開き括弧）。
final _declHead = RegExp(
    r'(?<![A-Za-z0-9_$.])([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^()<>;]*>)?\s*\(');

/// 宣言の名前になり得ない語（制御構文など）。
const _keywords = {
  'if', 'for', 'while', 'switch', 'catch', 'return', 'await', 'assert', //
  'super', 'this', 'new', 'const', 'throw', 'yield', 'else', 'do', 'try',
};

/// コメントと文字列の中身を空白にした文字列を返す（長さと改行の位置は保つ）。
///
/// 文字列の中の括弧やコメントの中の expect に惑わされないようにするため。
/// 文字列補間 `${...}` の中も丸ごと塗る（中の括弧で範囲がずれないように）。
String maskCommentsAndStrings(String source) => _Masker(source).run();

class _Masker {
  final String s;
  final List<int> out;

  _Masker(this.s) : out = s.codeUnits.toList();

  static const _space = 0x20;

  String run() {
    _code(0, stopAtBrace: false);
    return String.fromCharCodes(out);
  }

  void _mask(int from, int to) {
    for (var i = from; i < to && i < s.length; i++) {
      if (s.codeUnitAt(i) != 0x0A) out[i] = _space;
    }
  }

  bool _isIdent(int i) {
    if (i < 0 || i >= s.length) return false;
    final c = s.codeUnitAt(i);
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        c == 0x5F ||
        c == 0x24;
  }

  /// コードを読み進める。stopAtBrace なら、対応する `}` の直後の位置を返す。
  int _code(int i, {required bool stopAtBrace}) {
    var depth = 0;
    while (i < s.length) {
      final c = s[i];
      final next = i + 1 < s.length ? s[i + 1] : '';
      if (c == '/' && next == '/') {
        final end = s.indexOf('\n', i);
        final stop = end < 0 ? s.length : end;
        _mask(i, stop);
        i = stop;
      } else if (c == '/' && next == '*') {
        i = _blockComment(i);
      } else if (c == "'" || c == '"') {
        i = _string(i, raw: false);
      } else if ((c == 'r' || c == 'R') &&
          (next == "'" || next == '"') &&
          !_isIdent(i - 1)) {
        i = _string(i + 1, raw: true);
      } else if (c == '{') {
        depth++;
        i++;
      } else if (c == '}') {
        if (stopAtBrace && depth == 0) return i + 1;
        depth--;
        i++;
      } else {
        i++;
      }
    }
    return i;
  }

  /// `/* */`（入れ子あり）を塗る。終わりの直後の位置を返す。
  int _blockComment(int start) {
    var i = start + 2;
    var depth = 1;
    while (i < s.length && depth > 0) {
      if (s.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (s.startsWith('*/', i)) {
        depth--;
        i += 2;
      } else {
        i++;
      }
    }
    _mask(start, i);
    return i;
  }

  /// 引用符の位置から文字列を読み、中身を塗る。閉じ引用符の直後を返す。
  int _string(int start, {required bool raw}) {
    final q = s[start];
    final triple = s.startsWith('$q$q$q', start);
    final delim = triple ? '$q$q$q' : q;
    var i = start + delim.length;
    while (i < s.length) {
      if (s.startsWith(delim, i)) return i + delim.length;
      final c = s[i];
      if (!raw && c == r'\') {
        _mask(i, i + 2);
        i += 2;
        continue;
      }
      if (!raw && c == r'$' && i + 1 < s.length && s[i + 1] == '{') {
        final end = _code(i + 2, stopAtBrace: true);
        _mask(i, end);
        i = end;
        continue;
      }
      // 閉じていない1行の文字列は行末で打ち切る（壊れた入力でも先へ進む）
      if (!triple && c == '\n') return i;
      _mask(i, i + 1);
      i++;
    }
    return i;
  }
}

/// `open`（開き括弧の位置）に対応する閉じ括弧の位置。見つからなければ末尾。
/// masked はコメントと文字列を塗った後の文字列。
int _matching(String masked, int open) {
  var depth = 0;
  for (var i = open; i < masked.length; i++) {
    final c = masked[i];
    if (c == '(' || c == '{' || c == '[') {
      depth++;
    } else if (c == ')' || c == '}' || c == ']') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return masked.length - 1;
}

/// 関数・メソッドの宣言（名前と本体の範囲）。
class _Decl {
  final String name;
  final int bodyStart;
  final int bodyEnd;
  const _Decl(this.name, this.bodyStart, this.bodyEnd);
}

final _afterParams = RegExp(r'\s*(?:async\*?|sync\*)?\s*(\{|=>)');

List<_Decl> _declarations(String masked) {
  final decls = <_Decl>[];
  for (final m in _declHead.allMatches(masked)) {
    final name = m.group(1)!;
    if (_keywords.contains(name)) continue;
    final close = _matching(masked, m.end - 1);
    final after = _afterParams.matchAsPrefix(masked, close + 1);
    if (after == null) continue;
    if (after.group(1) == '{') {
      final open = after.end - 1;
      decls.add(_Decl(name, open, _matching(masked, open)));
    } else {
      // => 式本体。深さ 0 の ; か , か閉じ括弧まで
      var depth = 0;
      var i = after.end;
      for (; i < masked.length; i++) {
        final c = masked[i];
        if (c == '(' || c == '{' || c == '[') depth++;
        if (c == ')' || c == '}' || c == ']') {
          if (depth == 0) break;
          depth--;
        }
        if (depth == 0 && (c == ';' || c == ',')) break;
      }
      decls.add(_Decl(name, after.end, i));
    }
  }
  return decls;
}

bool _callsAny(String text, Set<String> names) {
  if (names.isEmpty) return false;
  for (final m in RegExp(
          r'(?<![A-Za-z0-9_$])([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^()<>;]*>)?\s*\(')
      .allMatches(text)) {
    if (names.contains(m.group(1))) return true;
  }
  return false;
}

/// ファイルの中で「確かめを含む」関数の名前（何段呼んでいても辿る）。
Set<String> _assertingNames(String masked, Set<String> sharedHelpers) {
  final decls = _declarations(masked);
  final known = <String>{...sharedHelpers};
  var changed = true;
  while (changed) {
    changed = false;
    for (final d in decls) {
      if (known.contains(d.name)) continue;
      final body = masked.substring(d.bodyStart, d.bodyEnd + 1);
      if (_assertionCall.hasMatch(body) || _callsAny(body, known)) {
        known.add(d.name);
        changed = true;
      }
    }
  }
  return known;
}

/// 確かめを含む**公開**関数の名前。ほかのファイルから呼ばれる補助関数を数えるのに使う。
/// `_` で始まる名前はそのファイルの中でしか呼べないので入れない。
Set<String> collectHelperNames(String source) {
  final masked = maskCommentsAndStrings(source);
  return _assertingNames(masked, const {})
      .where((n) => !n.startsWith('_') && n != 'main')
      .toSet();
}

/// 確かめが1つも無い test / testWidgets を返す。
///
/// sharedHelpers は、ほかのファイルにある「確かめを含む公開関数」の名前。
List<Finding> findAssertionFreeTests(
  String source, {
  required String path,
  Set<String> sharedHelpers = const {},
}) {
  final masked = maskCommentsAndStrings(source);
  final helpers = _assertingNames(masked, sharedHelpers);
  final findings = <Finding>[];
  for (final m in _testCall.allMatches(masked)) {
    final open = m.end - 1;
    final close = _matching(masked, open);
    final args = masked.substring(open, close + 1);
    if (_assertionCall.hasMatch(args) || _callsAny(args, helpers)) continue;
    final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
    final lineEnd = source.indexOf('\n', open);
    final name = source
        .substring(open + 1, lineEnd < 0 ? source.length : lineEnd)
        .trim();
    findings.add(Finding(path, line, m.group(1)!, name));
  }
  return findings;
}

List<File> _dartFiles(List<String> roots) {
  final files = <File>[];
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.file) {
      files.add(File(root));
    } else if (type == FileSystemEntityType.directory) {
      files.addAll(
        Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.contains('/node_modules/')),
      );
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void main(List<String> args) {
  final roots = args.isEmpty ? ['test', 'integration_test'] : args;
  final files = _dartFiles(roots);
  final sources = {for (final f in files) f.path: f.readAsStringSync()};

  // ほかのファイルの補助関数は、test/ と integration_test/ のうち *_test.dart で
  // ない補助ファイル（test/helpers/ など）から集める（場所を絞って走らせた時も）。
  // *_test.dart の main の中の関数はそのファイルでしか呼べないので入れない。
  final helperFiles = _dartFiles(['test', 'integration_test'])
      .where((f) => !f.path.endsWith('_test.dart'));
  final shared = <String>{};
  for (final f in helperFiles) {
    shared.addAll(collectHelperNames(sources[f.path] ?? f.readAsStringSync()));
  }

  final findings = <Finding>[];
  var tests = 0;
  for (final e in sources.entries) {
    if (!e.key.endsWith('_test.dart')) continue;
    tests += _testCall.allMatches(maskCommentsAndStrings(e.value)).length;
    findings.addAll(
      findAssertionFreeTests(e.value, path: e.key, sharedHelpers: shared),
    );
  }

  if (findings.isEmpty) {
    stdout.writeln('確かめの無いテストはありません（$tests 件を確認）');
    return;
  }
  for (final f in findings) {
    // GitHub Actions の注釈として出す（PR の差分に行で表示される）
    if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
      stdout.writeln(
        '::error file=${f.path},line=${f.line}::'
        '${f.kind} に確かめ（expect など）が1つもありません',
      );
    }
    stdout.writeln(f);
  }
  stderr.writeln(
    '\n確かめ（expect / expectLater / verify / fail など）が1つも無いテストが '
    '${findings.length} 件あります（$tests 件中）。\n'
    '「落ちないこと」自体を見るなら expectLater(f(), completes) や '
    'expect(tester.takeException(), isNull) で明示してください。',
  );
  exitCode = 1;
}
