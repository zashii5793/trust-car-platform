import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 作ったのに、どこからも開けない画面を数える。
///
/// **ファイルが在ることは、使えることの保証ではない。**
///
/// 2026-08-23 に実際に起きた。`lib/screens/settings/feedback_screen.dart` と
/// `lib/widgets/getting_started_card.dart` は、テストごと一式が書かれていたのに
/// **どこからも参照されていなかった。** テストは通り、`flutter analyze` も
/// 黙っている。アプリを開いても、そこへ行く道が無いので誰も気づかない。
///
/// さらに同じ日、配線したつもりの導線が**使われていない画面のほう**に
/// 付いていたことも分かった。`ProfileScreen` にメニューを足したが、
/// 下タブの「プロフィール」が描くのは `home_screen.dart` の `_ProfileTab` で、
/// 別物だった。実際にアプリを触るまで分からなかった。
///
/// この検査は前者（どこからも参照されていない）を拾う。後者は参照が在るため
/// 拾えない。**画面を足したら一度は自分で開くこと。**
///
/// ## 判定
///
/// `lib/screens/` 配下で宣言された `〜Screen` クラスが、宣言元以外の
/// `lib/` のファイルから名前で参照されているか。参照が1件も無ければ未配線。
void main() {
  final libDir = Directory('lib');

  /// `class FooScreen extends StatelessWidget` / `StatefulWidget` を拾う。
  final classPattern = RegExp(
    r'^class\s+(\w*Screen)\s+extends\s+(StatelessWidget|StatefulWidget)',
    multiLine: true,
  );

  /// 参照されていなくても構わないもの。
  ///
  /// - ルート画面は Navigator ではなく main.dart / MaterialApp から立つため、
  ///   足したときはここに書く。
  const allowedUnwired = <String>{};

  test('どこからも開けない画面が無い', () {
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final contents = {
      for (final f in dartFiles) f.path: f.readAsStringSync(),
    };

    final declarations = <String, String>{}; // クラス名 -> 宣言元のパス
    for (final entry in contents.entries) {
      if (!entry.key.startsWith('lib/screens/')) continue;
      for (final m in classPattern.allMatches(entry.value)) {
        declarations[m.group(1)!] = entry.key;
      }
    }

    expect(
      declarations,
      isNotEmpty,
      reason: 'lib/screens/ から画面クラスを1つも拾えていない。'
          '検出の正規表現が実装と合っていない可能性がある。',
    );

    final unwired = <String, String>{};
    for (final entry in declarations.entries) {
      final name = entry.key;
      final declaredIn = entry.value;
      if (allowedUnwired.contains(name)) continue;

      // 宣言元以外のどこかで名前が出てくるか。
      final referenced = contents.entries.any((f) {
        if (f.key == declaredIn) return false;
        return RegExp('\\b$name\\b').hasMatch(f.value);
      });

      if (!referenced) unwired[name] = declaredIn;
    }

    expect(
      unwired,
      isEmpty,
      reason: 'どこからも参照されていない画面がある。'
          'アプリからは到達できないので、導線を足すか、'
          '意図的なら allowedUnwired に理由つきで入れること。\n'
          '${unwired.entries.map((e) => '  ${e.key}  (${e.value})').join('\n')}',
    );
  });
}
