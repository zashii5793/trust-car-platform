// ゴールデン画像に、アイコンと日本語を実際に描かせるための読み込み。
//
// **これを呼ばないゴールデンは、文字もアイコンも豆腐（□）で写る。**
// 2026-08-20 に既存のゴールデン（login_screen.png ほか17枚）を目視して分かった。
// `docs/TEST_SCREENSHOT_REPORT.md` はそれを「スクリーンショット」として載せていたが、
// **画面の文字は一度も検証されていなかった。** 検証できていたのは配置と色だけ。
//
// テスト用の embedder は、**バンドルされたフォントしか見ない。**
// 端末に入っているフォントは自動では使われない。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter SDK が持っているアイコンフォント。**どの開発機にも在る。**
Future<void> loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      _rootFromExecutable() ??
      '/usr/local/share/flutter';
  final file = File('$root/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf');
  if (!file.existsSync()) return; // 無い環境では黙って諦める（テストは落とさない）
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

/// 日本語フォント。**在れば読む。無ければ読まない。**
///
/// ## 限界（2026-08-20 実測）
///
/// **`fontWeight: w500` の文字だけは、まだ豆腐で写る。**
/// macOS の日本語は `.ttc`（複数の太さを 1 ファイルに束ねた形）でしか
/// 手に入らず、`FontLoader` が 2 面目以降を読まない。W5 を渡しても
/// w500 に当たらない。ボタンの文字（`elevatedButtonTheme` が w500）が該当する。
///
/// **見出しと説明文は読める**ので、折り返し・行数・詰まりの確認には使える。
/// **ボタンの文字の見え方を確かめたいときは、シミュレータで撮ること。**
/// 直すなら、日本語フォントを 1 ファイル 1 太さで同梱する（未着手）。
///
/// 端末のフォントを使うので、**機械が変われば絵も変わる。**
/// だから比較用のゴールデン（CI で差分を見るもの）には使わない。
/// 使うのは「人が目で見るための画像」を出すときだけ
/// （`ux_golden_test.dart` は目視用で、CI の比較対象ではない）。
Future<bool> loadJapaneseFont() async {
  // **太さ違いを全部まとめて渡す。**
  // 1 本だけ渡すと、`fontWeight: w500` の文字（ボタンなど）が日本語を持たない
  // 書体に落ちて豆腐になる。2026-08-20 に実際そうなった。
  // `FontLoader` は書体が持つ太さの情報で選ぶので、並べておけば足りる。
  //
  // **W0〜W9 を全部渡す。** 2026-08-27 に、AppBar のタイトル
  // （`fontWeight: w600`）だけが豆腐で写った。W2/W3/W5/W6/W7/W8 の6本では
  // w600 が当たらなかった。抜けを作ると、その太さの文字だけ静かに豆腐になる。
  const files = [
    '/System/Library/Fonts/ヒラギノ角ゴシック W0.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W1.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W2.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc',
    '/System/Library/Fonts/ヒラギノ角ゴシック W9.ttc',
    // Linux（CI）に在れば使う
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
  ];

  // アプリは書体を指定していないので、既定で当たる名前すべてに載せる。
  const families = ['Roboto', '.SF UI Text', '.SF UI Display', 'sans-serif'];

  final data = <ByteData>[];
  for (final path in files) {
    final f = File(path);
    if (f.existsSync()) data.add(ByteData.sublistView(f.readAsBytesSync()));
  }
  if (data.isEmpty) return false;

  for (final family in families) {
    final loader = FontLoader(family);
    for (final d in data) {
      loader.addFont(Future.value(d));
    }
    await loader.load();
  }
  return true;
}

String? _rootFromExecutable() {
  final exe = Platform.resolvedExecutable; // .../bin/cache/dart-sdk/bin/dart
  final i = exe.indexOf('/bin/cache/');
  return i > 0 ? exe.substring(0, i) : null;
}

/// ゴールデンを撮るためだけのテーマ調整。
///
/// **アプリの見え方を変えるものではない。**
///
/// 2026-08-27 に、AppBar のタイトルだけが □ で写った。原因は太さではなく
/// **フォント名の指定が無いこと**だった。`AppBarTheme.titleTextStyle` は
/// `fontFamily` を持たない生の `TextStyle` で、テスト用の embedder では
/// 名前が解決できず「全部 □ で描く既定フォント」に落ちる。
/// 本文が無事だったのは `TextTheme` 経由で名前が付いていたため。
///
/// [loadJapaneseFont] が載せた名前を明示的に指すと、同じ名前の中から近い
/// 太さが選ばれ、日本語が出る。**実機は system font を持っているので、
/// この問題はゴールデンの中だけで起きる。**
ThemeData goldenTheme(ThemeData base) {
  const family = 'Roboto';

  TextStyle? withFamily(TextStyle? style) =>
      style?.fontFamily == null ? style?.copyWith(fontFamily: family) : style;

  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: withFamily(base.appBarTheme.titleTextStyle),
      toolbarTextStyle: withFamily(base.appBarTheme.toolbarTextStyle),
    ),
  );
}
