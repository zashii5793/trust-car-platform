// ignore_for_file: avoid_print
/// 画面操作テストの共通処理。
///
/// ここに集めてあるのは、**2026-09-21 に実際に踏んだ落とし穴の対策**。
/// 新しい画面操作テストを書くときは、まずこのファイルを読むこと。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// アニメーションが止まらない画面でも進めるよう、pumpAndSettle を使わずに
/// 一定回数 pump する。`until` が真になったら抜ける。
///
/// `pumpAndSettle` は読み込み中のスピナーが回り続けると例外で落ちる。
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() until, {
  int maxPumps = 120,
  Duration step = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (until()) return true;
    await tester.pump(step);
  }
  return until();
}

/// いま画面に出ている Text を集める。落ちたときの手掛かりに使う。
List<String> visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .where((t) => t.trim().isNotEmpty)
    .toList();

/// 入力欄に文字を入れる。
///
/// Web の profile ビルドでは `tester.enterText` だけだと**入力欄が空のまま**に
/// なることがある（テスト用のテキスト入力の配線が debug 前提のため）。
/// 実際 2026-09-21 に「メールアドレスを入力してください」で弾かれた。
///
/// タップして焦点を当ててから enterText し、それでも入っていなければ
/// コントローラに直接入れる。**入ったことをここで確かめてから先へ進む。**
Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 200));

  final editable =
      find.descendant(of: field, matching: find.byType(EditableText));
  if (editable.evaluate().isEmpty) return;

  final controller = tester.widget<EditableText>(editable).controller;
  if (controller.text != text) {
    controller.text = text;
    await tester.pump(const Duration(milliseconds: 200));
    print('[typeInto] enterText が効かなかったのでコントローラに直接入れた');
  }
}

/// オンボーディング → ログイン → ホームの中身が出るまで。
///
/// **タブ名や AppBar の文字で「画面が出た」と判定してはいけない。**
/// 'マイカー' はタブの label なので中身が空でも即座に出る。2026-09-21 に
/// これで2回、正常に動いているアプリを「空だ」と読み違えた。
/// 呼び出し側から `homeReady` に**中身の条件**を渡すこと。
Future<void> loginAndWaitHome(
  WidgetTester tester, {
  required String email,
  required String password,
  required bool Function() homeReady,
}) async {
  await pumpUntil(
    tester,
    () =>
        find.byType(TextFormField).evaluate().length >= 2 ||
        find.text('スキップ').evaluate().isNotEmpty,
  );

  // 新しいブラウザプロファイル（＝CI や初回実行）では、ログイン画面の前に
  // オンボーディングが出る。手元で一度触ったブラウザだと localStorage に
  // 残っていて出ないため、**環境によって最初の画面が違う。**
  if (find.text('スキップ').evaluate().isNotEmpty) {
    await tester.tap(find.text('スキップ').first);
    await pumpUntil(
      tester,
      () => find.byType(TextFormField).evaluate().length >= 2,
    );
  }

  final fields = find.byType(TextFormField);
  expect(fields, findsAtLeast(2), reason: 'ログイン画面の入力欄が出ない');

  await typeInto(tester, fields.at(0), email);
  await typeInto(tester, fields.at(1), password);

  final loginButton = find.widgetWithText(ElevatedButton, 'ログイン');
  expect(loginButton, findsOneWidget, reason: 'ログインボタンが無い');
  await tester.tap(loginButton);

  final ok = await pumpUntil(tester, homeReady, maxPumps: 400);
  expect(ok, isTrue,
      reason: 'ログイン後の画面が出ない。画面の文字: ${visibleTexts().join(' / ')}');
}
