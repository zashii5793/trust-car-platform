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
  final result = await Process.run('screencapture', ['-x', '$_outDir/$name.png']);
  if (result.exitCode == 0) {
    print('captured: $_outDir/$name.png');
  } else {
    print('capture failed ($name): ${result.stderr}');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1年使ったユーザーのホームを見る', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    await capture('01_起動直後');

    // ---- ログイン ----
    final emailField = find.byType(TextFormField);
    if (emailField.evaluate().length >= 2) {
      await tester.enterText(emailField.at(0), _email);
      await tester.pumpAndSettle();
      await tester.enterText(emailField.at(1), _password);
      await tester.pumpAndSettle();

      final loginButton = find.text('ログイン');
      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton.last);
        // Firestore の読み込みを待つ。1年ぶんのデータなので余裕をみる。
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }
    }

    await capture('02_ホーム上部');

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
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty)
        .toList();
    print('--- ホームに出ている文字 ---');
    for (final t in texts) {
      print(t);
    }
  });
}
