import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// `Navigator.push` で開く画面に、戻る道が在るかを数える。
///
/// **開ける画面を足すことと、閉じられる画面を足すことは別の作業。**
///
/// 2026-09-14 に実際に起きた。`NotificationListScreen` は HomeScreen の
/// AppBar に body として差し込む前提で書かれていたので Scaffold を持たない。
/// 2026-09-07 に通知をタブから外してベルから `Navigator.push` するように
/// 変えたとき、この画面はそのまま全画面として積まれた。AppBar が無い＝
/// 戻るボタンが無い。既存のテストは「ベルを押すと通知一覧が開く」ことだけを
/// 見ていたので、開いたきり戻れないことに気づけなかった。
///
/// Android の戻るキーや iOS のスワイプバックがある端末では詰まないが、
/// **Web ではブラウザバック以外に戻る手段が無い**。
///
/// ## 判定
///
/// `lib/` の中で `Navigator...push(...)` に渡される `MaterialPageRoute` の
/// 行き先クラスを集め、その宣言ファイルが `AppBar(` を持つかを見る。
/// `pushReplacement` と `pushAndRemoveUntil` は前の画面を積まないので対象外。
///
/// AppBar があるかどうかは戻れることの必要条件でしかない（`leading` を潰す、
/// `automaticallyImplyLeading: false` にする、といった書き方はここでは拾えない）。
/// **画面を push で開くようにしたら、一度は自分で開いて閉じること。**
void main() {
  final libDir = Directory('lib');

  final classPattern = RegExp(
    r'^class\s+(\w+)\s+extends\s+(StatelessWidget|StatefulWidget)',
    multiLine: true,
  );

  final routePattern = RegExp(
    r'MaterialPageRoute[^(]*\(\s*builder:\s*\([^)]*\)\s*=>\s*(?:const\s+)?(\w+)\(',
  );

  /// AppBar を持たないまま push されてよいもの。
  ///
  /// 足すときは「なぜ戻る道が要らないか」を必ず書くこと。
  const allowedWithoutAppBar = <String, String>{};

  /// AppBar の戻るボタンを自分で消してよいもの。
  ///
  /// 消すなら、代わりの出口を画面の中に置くこと。
  const allowedWithoutBackButton = <String, String>{
    'DriveRecordingScreen': '記録中の誤操作で閉じないため。画面内の「記録終了」が出口',
  };

  test('Navigator.push で開く画面は AppBar（戻る導線）を持つ', () {
    final sources = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // クラス名 -> 宣言ファイル
    final declaredIn = <String, File>{};
    final contents = <File, String>{};
    for (final file in sources) {
      final src = file.readAsStringSync();
      contents[file] = src;
      for (final m in classPattern.allMatches(src)) {
        declaredIn[m.group(1)!] = file;
      }
    }

    // 行き先クラス -> push している場所
    final pushedFrom = <String, Set<String>>{};
    for (final file in sources) {
      final src = contents[file]!;
      for (final m in routePattern.allMatches(src)) {
        // 直前の push 系メソッドを見て、前の画面を積む push だけを拾う。
        final before = src.substring(max(0, m.start - 200), m.start);
        final lastPush = before.lastIndexOf('push');
        if (lastPush < 0) continue;
        final call = before.substring(lastPush);
        if (call.startsWith('pushReplacement') ||
            call.startsWith('pushAndRemoveUntil')) {
          continue;
        }
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        pushedFrom
            .putIfAbsent(m.group(1)!, () => <String>{})
            .add('${file.path}:$line');
      }
    }

    final offenders = <String>[];
    for (final entry in pushedFrom.entries) {
      final target = entry.key;
      if (allowedWithoutAppBar.containsKey(target)) continue;
      final file = declaredIn[target];
      if (file == null) continue; // lib の外（パッケージ）で宣言された画面
      if (contents[file]!.contains('AppBar(')) continue;
      offenders.add(
        '$target (${file.path}) — push 元: ${entry.value.join(', ')}',
      );
    }

    expect(
      offenders,
      isEmpty,
      reason: 'push で全画面に積まれるのに AppBar が無く、戻るボタンが出ない画面がある:\n'
          '${offenders.join('\n')}\n'
          'Scaffold + AppBar を持たせるか、body として差し込む画面なら push をやめること。',
    );
  });

  test('push で開く画面は AppBar の戻るボタンを自分で消さない', () {
    final sources = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final declaredIn = <String, File>{};
    final contents = <File, String>{};
    for (final file in sources) {
      final src = file.readAsStringSync();
      contents[file] = src;
      for (final m in classPattern.allMatches(src)) {
        declaredIn[m.group(1)!] = file;
      }
    }

    final pushed = <String>{};
    for (final file in sources) {
      final src = contents[file]!;
      for (final m in routePattern.allMatches(src)) {
        final before = src.substring(max(0, m.start - 200), m.start);
        final lastPush = before.lastIndexOf('push');
        if (lastPush < 0) continue;
        final call = before.substring(lastPush);
        if (call.startsWith('pushReplacement') ||
            call.startsWith('pushAndRemoveUntil')) {
          continue;
        }
        pushed.add(m.group(1)!);
      }
    }

    final offenders = <String>[];
    for (final target in pushed) {
      if (allowedWithoutBackButton.containsKey(target)) continue;
      final file = declaredIn[target];
      if (file == null) continue;
      final src = contents[file]!;
      if (!src.contains('automaticallyImplyLeading: false')) continue;
      // 自前の leading を置いているなら、そこに出口がある前提で通す。
      if (src.contains('leading:')) continue;
      offenders.add('$target (${file.path})');
    }

    expect(
      offenders,
      isEmpty,
      reason: 'automaticallyImplyLeading: false で戻るボタンを消したまま push される画面がある:\n'
          '${offenders.join('\n')}\n'
          '消すなら leading に別の出口を置くか、allowedWithoutBackButton に理由を書くこと。',
    );
  });
}
