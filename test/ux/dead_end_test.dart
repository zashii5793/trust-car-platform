import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 空表示の行き止まりを数える。
///
/// **「何もありません」と出したまま、次の一手が無い画面を作らない。**
///
/// 2026-08-20、車両詳細のドライブタブで実際に起きた。ログが 0 件のとき
/// 「ドライブログがありません」と出るが、そこから記録する導線が無い。
/// 実装にはこう書いてあった。
///
/// ```dart
/// // The drive-only tab has its own recording flow, so no CTA there.
/// final showAddCta = widget.filter != _TimelineFilter.drive;
/// ```
///
/// 「別の画面に導線がある」は、**この画面から行けることの保証ではない。**
///
/// ペルソナのシナリオでは見つからない。シナリオは中身が入った状態から
/// 始まるので、**空の状態を一度も通らない**（`docs/PERSONA_SCENARIO_GUIDE.md`）。
/// 人が総当たりする前に、コードから拾えるものは拾う。
///
/// ## 判定
///
/// `buttonLabel` が**必ず**入るときだけ「次の一手がある」と数える。
/// 三項演算子で `null` になりうるものは行き止まりとして数える
/// （上の例がまさにそれで、`buttonLabel:` は書いてあった）。
///
/// ## 例外
///
/// 次の一手が本当に無い画面はある（通知・コメント）。
/// **黙って見逃さず、理由つきで [allowedDeadEnds] に書く。**
/// 理由を書けないものは、行き止まりとして直す。
void main() {
  // 次の一手が無くて正しい空表示。**必ず理由を書くこと。**
  const allowedDeadEnds = <String, String>{
    'lib/widgets/common/loading_indicator.dart':
        'AppEmptyState の定義そのもの。呼び出し側ではない',
    'lib/screens/notifications/notification_list_screen.dart':
        '通知は自分で作るものではないので、次の一手が無い',
    'lib/screens/notifications/social_notification_screen.dart':
        '同上',
    'lib/screens/sns/post_detail_screen.dart':
        'コメント欄は下に常設。空表示にボタンを足すと入力欄と二重になる',
    'lib/screens/newsletter/newsletter_list_screen.dart':
        'ニュースレターは運営が配信するもの。利用者側に作る手段が無い',
    // **これは「正しい」ではなく「まだ画面に出ていない」。**
    // 2026-08-20 時点で呼び出し 0 件（grep 済み）。組み込むときに
    // 「整備記録を追加」へ渡す導線を足し、この行を消すこと。
    'lib/widgets/maintenance/tire_info_card.dart':
        'どこからも呼ばれていない（呼び出し 0 件）。画面に出ないので踏めない',
  };

  test('空表示に、次の一手がある（行き止まりを作らない）', () {
    final findings = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = file.readAsStringSync();
      for (final m in RegExp(r'AppEmptyState\s*\(').allMatches(src)) {
        final block = _balanced(src, m.end - 1);
        if (block == null) continue;

        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        final label = _argOf(block, 'buttonLabel');
        final pressed = _argOf(block, 'onButtonPressed');

        // 「必ず入る」= 書いてあって、かつ **その式自体が** null になりえない。
        //
        // `contains('null')` で数えると、`() => filter(null)` のように
        // **引数に null を渡すだけの正しいコールバック**まで行き止まりになる。
        // 見るのは括弧の外（深さ 0）に出てくる null だけ。
        // 三項の `cond ? 'ラベル' : null` はここで捕まる。
        final sure = label != null &&
            !_nullableAtTopLevel(label) &&
            pressed != null &&
            !_nullableAtTopLevel(pressed);
        if (sure) continue;

        final reason = allowedDeadEnds[file.path];
        if (reason != null) continue;

        final title = _argOf(block, 'title') ?? '(動的)';
        findings.add('${file.path}:$line  $title');
      }
    }

    expect(
      findings,
      isEmpty,
      reason: '空表示から次に進めません。ボタンを足すか、'
          'それが正しいなら allowedDeadEnds に理由を書いてください。\n'
          '${findings.join('\n')}',
    );
  });
}

/// `start` の `(` に対応する `)` までの中身を返す。
String? _balanced(String src, int start) {
  var depth = 0;
  for (var i = start; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')') {
      depth--;
      if (depth == 0) return src.substring(start + 1, i);
    }
  }
  return null;
}

/// 名前つき引数の値を、次の引数の手前まで取り出す。
///
/// **入れ子の括弧を跨ぐ。** 跨がないと `onButtonPressed: () { ... }` の
/// 中身で切れて、判定が変わる。
String? _argOf(String block, String name) {
  final m = RegExp('(?:^|[,\\s])$name\\s*:').firstMatch(block);
  if (m == null) return null;
  var depth = 0;
  final buf = StringBuffer();
  for (var i = m.end; i < block.length; i++) {
    final c = block[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) break;
    buf.write(c);
  }
  return buf.toString().trim();
}

/// 括弧の外（深さ 0）に `null` が出てくるか。
///
/// **入れ子の中は見ない。** `() => provider.filterByVehicleModel(null)` は
/// 引数に null を渡しているだけで、**ボタンは必ず出る**。
bool _nullableAtTopLevel(String expr) {
  var depth = 0;
  final buf = StringBuffer();
  for (var i = 0; i < expr.length; i++) {
    final c = expr[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0) buf.write(c);
  }
  return RegExp(r'\bnull\b').hasMatch(buf.toString());
}
