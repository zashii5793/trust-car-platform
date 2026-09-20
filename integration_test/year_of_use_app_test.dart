// ignore_for_file: avoid_print
/// 1年ぶんのデータが入った状態で、実際のアプリを起動して画面を撮る。
///
/// なぜ要るか:
///   ウィジェットテストは作り物のデータで動くので、「溜まったときにどう
///   見えるか」は分からない。ルールもインデックスも評価されない。
///   ここでは**本物のアプリ**をエミュレータにつないで動かし、ログインから
///   ホームまでを通し、画面を撮る。
///
/// 前提:
///   1. `firebase emulators:start --only auth,firestore`
///   2. シード投入（docs/TEST_DATA_GUIDE.md の順 → 最後に seed_year_of_use.js）
///   3. `flutter test integration_test/year_of_use_app_test.dart -d macos`
///
///   デバッグビルドは kDebugMode でエミュレータに自動接続する（main.dart）。
///
/// 画像の保存先は `docs/screenshots/year_of_use/`。macOS では
/// `binding.takeScreenshot` が使えないため、`screencapture` で画面を撮る。
/// アプリのウィンドウが最前面にある前提。
///
/// ⚠️ **対話的なデスクトップセッションが要る**（2026-09-20 時点）:
///   ssh や自動実行のような GUI セッションの無いところから走らせると、
///   `Failed to foreground app; open returned 1` のあとログインが完了せず、
///   ログイン画面のまま止まる（60秒待っても変わらない）。最前面に出せない
///   アプリは macOS に抑制されるため。**人が自分の Mac で打つぶんには通る。**
///
///   2026-09-20 まではこの状況でも「All tests passed」と出ていた。手順が
///   すべて `if` で囲われていて、ログインできなくても素通りしていたため。
///   いまは落ちる。落ちたときは画面に出ている文字が一緒に出る。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trust_car_platform/main.dart' as app;

const _email = 'persona.a@example.com';
const _password = 'password123';
const _outDir = 'docs/screenshots/year_of_use';

Future<void> capture(String name) async {
  await Directory(_outDir).create(recursive: true);
  final result =
      await Process.run('screencapture', ['-x', '$_outDir/$name.png']);
  if (result.exitCode == 0) {
    print('captured: $_outDir/$name.png');
  } else {
    print('capture failed ($name): ${result.stderr}');
  }
}

/// いま画面に出ている Text を集める。落ちたときの手掛かりに使う。
List<String> _visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .where((t) => t.trim().isNotEmpty)
    .toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1年使ったユーザーのホームを見る', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    await capture('01_起動直後');

    // ---- ログイン ----
    //
    // ここは **if で囲って素通りさせない**。2026-09-20 まで全部 if だったため、
    // ログインできずログイン画面を撮っただけでも「All tests passed」と出ていた。
    // 落ちないテストは、無いのと同じどころか、確かめた気にさせるぶん悪い。
    final fields = find.byType(TextFormField);
    expect(
      fields,
      findsAtLeast(2),
      reason: 'ログイン画面の入力欄が見つからない。起動に失敗している可能性がある',
    );

    await tester.enterText(fields.at(0), _email);
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), _password);
    await tester.pumpAndSettle();

    final loginButton = find.widgetWithText(ElevatedButton, 'ログイン');
    expect(loginButton, findsOneWidget, reason: 'ログインボタンが見つからない');
    await tester.tap(loginButton);

    // Firestore の読み込みを待つ。1年ぶんのデータなので余裕をみる。
    // pumpAndSettle はアニメーションが止まらないと例外で落ちるので、
    // 一定回数 pump する方式にする（ローディング表示が回り続けても進む）。
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(TextFormField).evaluate().length < 2) break;
    }

    await capture('02_ホーム上部');

    // ログイン画面のままなら、その先を撮っても意味がない。何が出ているかを
    // 添えて落とす（認証エラーの文言がそのまま手掛かりになる）。
    if (find.byType(TextFormField).evaluate().length >= 2) {
      fail('ログインできていない。画面に出ている文字: ${_visibleTexts().join(' / ')}');
    }

    // ---- ホームを下へ ----
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollable.first, const Offset(0, -600));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await capture('03_ホーム_スクロール${i + 1}');
      }
    }

    // 何が出ているかを、テキストで残す（画像が撮れなかったときの手掛かり）。
    final texts = _visibleTexts();
    print('--- ホームに出ている文字 ---');
    for (final t in texts) {
      print(t);
    }
  });
}
