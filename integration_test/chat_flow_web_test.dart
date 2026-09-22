// ignore_for_file: avoid_print
/// 店舗とお客様のチャットを、**実際に画面を操作して**通す。
///
/// ゴールデンは静止画で、操作の結果は分からない。ここでは本物のアプリを
/// エミュレータにつないで動かし、ログイン → マーケット → 問い合わせ →
/// スレッドを開く、までを**タップと入力で**進める。
///
/// Web で走らせるのは、macOS のアプリだと最前面に出せない環境
/// （ssh・自動実行）でログインが完了しないため。Chrome なら背景でも動く。
/// タップは Flutter のテストバインディング経由で出るので、**座標もフォーカスも
/// 関係ない**（ブラウザ自動化で詰まるのはここ）。
///
/// 前提:
///   1. firebase emulators:start --only auth,firestore,storage
///   2. ./scripts/seed_all.sh
///   3. chromedriver --port=4444 &
///   4. flutter drive \
///        --driver=test_driver/integration_test.dart \
///        --target=integration_test/chat_flow_web_test.dart \
///        -d chrome --dart-define=USE_EMULATOR=true
///
/// スクリーンショットは docs/screenshots/ に出る（test_driver 側で保存）。
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trust_car_platform/main.dart' as app;

const _email = 'persona.a@example.com';
const _password = 'password123';

/// アニメーションが止まらない画面でも進めるよう、pumpAndSettle を使わずに
/// 一定回数 pump する。`until` が真になったら抜ける。
Future<bool> _pumpUntil(
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

/// 入力欄に文字を入れる。
///
/// Web の profile ビルドでは `tester.enterText` だけだと**入力欄が空のまま**に
/// なることがある（テスト用のテキスト入力の配線が debug 前提のため）。
/// 実際 2026-09-21 に「メールアドレスを入力してください」で弾かれた。
///
/// タップして焦点を当ててから enterText し、それでも入っていなければ
/// コントローラに直接入れる。**入ったことをここで確かめてから先へ進む。**
Future<void> _typeInto(WidgetTester tester, Finder field, String text) async {
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
    print('[typeInto] enterText が効かなかったのでコントローラに直接入れた: $text');
  }
}

List<String> _visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .where((t) => t.trim().isNotEmpty)
    .toList();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('お客様が店舗とのやりとりを開くまでを操作で通す', (tester) async {
    app.main();
    await _pumpUntil(
      tester,
      () =>
          find.byType(TextFormField).evaluate().length >= 2 ||
          find.text('スキップ').evaluate().isNotEmpty,
    );
    await binding.takeScreenshot('flow_01_start');

    // ---- オンボーディング ----
    //
    // 新しいブラウザプロファイル（＝CI や初回実行）では、ログイン画面の前に
    // オンボーディングが出る。手元で一度触ったブラウザだと localStorage に
    // 残っていて出ないため、**環境によって最初の画面が違う。**
    // ここを見落として「ログイン画面の入力欄が無い」で落ちた。
    if (find.text('スキップ').evaluate().isNotEmpty) {
      await tester.tap(find.text('スキップ').first);
      await _pumpUntil(
        tester,
        () => find.byType(TextFormField).evaluate().length >= 2,
      );
    }
    await binding.takeScreenshot('flow_02_login');

    // ---- ログイン ----
    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeast(2), reason: 'ログイン画面の入力欄が出ない。起動に失敗している');

    await _typeInto(tester, fields.at(0), _email);
    await _typeInto(tester, fields.at(1), _password);

    final loginButton = find.widgetWithText(ElevatedButton, 'ログイン');
    expect(loginButton, findsOneWidget, reason: 'ログインボタンが無い');
    await tester.tap(loginButton);

    // **ログイン欄が消えただけでは足りない。** 消えた直後はまだ読み込み中の
    // スピナーで、中身は何も出ていない（2026-09-21 にその瞬間を撮って気づいた）。
    // ホームの中身が出るまで待つ。1年ぶんのデータを読むので長めに見る。
    // **タブ名で判定してはいけない。** 'マイカー' は AppBar とタブの label なので
    // 中身が何も無くても即座に出る。2026-09-21 に、読み込み途中の空表示を
    // 「車両が出ていない」と読み違えた。
    //
    // 車が並んだ（車名が出た）か、1年の集計が出たか、どちらかを待つ。
    final loggedIn = await _pumpUntil(
      tester,
      () => _visibleTexts().any((t) =>
          t.contains('この1年で') ||
          t.contains('Toyota') ||
          t.contains('ハイエース') ||
          t.contains('アルファード')),
      maxPumps: 400,
    );

    // 落ちる前に必ず撮る。Web の integration_test は失敗の理由が
    // driver 側に届かない（details が空になる）ので、**画像が唯一の手掛かり**。
    await binding.takeScreenshot('flow_03_after_login_tap');
    print('--- ログイン後の画面 ---');
    for (final t in _visibleTexts()) {
      print(t);
    }

    expect(loggedIn, isTrue,
        reason: 'ログインできていない。画面の文字: ${_visibleTexts().join(' / ')}');

    await binding.takeScreenshot('flow_04_home');

    // **接続先をここで晒す。** バナーは「emulator mode」と出ていても、
    // --dart-define が効かず本番につながっていることがある（既知の罠）。
    // 空の画面を見たとき、データが無いのか、別の場所を見ているのかは
    // これを出さないと分からない。
    //
    // print は Web では driver に届かない。driver の結果 JSON に載る
    // `binding.reportData` に入れる。**Web でアプリ側の値を外に出す唯一の道。**
    final fs = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final diag = <String, dynamic>{
      // host は emulator 接続でも null で返ることがある。**接続先の判定には
      // 使えない**（2026-09-21 に「本番につながっている」と誤読した）。
      // 実際の判定は vehiclesForUid が返るかどうかで見る。
      'firestoreHost': fs.settings.host ?? '(null)',
      'sslEnabled': fs.settings.sslEnabled,
      'uid': uid ?? '(未ログイン)',
      'homeTexts': _visibleTexts().take(30).toList(),
    };
    try {
      final snap =
          await fs.collection('vehicles').where('userId', isEqualTo: uid).get();
      diag['vehiclesForUid'] = snap.size;
    } catch (e) {
      diag['vehiclesQueryError'] = e.toString();
    }
    binding.reportData = diag;

    // ---- ホーム: 車が並んでいるか ----
    //
    // 「この1年で」の集計は画面のずっと下にあり、遅延構築なので最初は
    // ウィジェットが存在しない。**見えていないものを条件にすると、
    // 正しく動いていても落ちる**（2026-09-21 に踏んだ）。
    // ここでは上部に必ず出るダッシュボードと車名で見る。
    final homeTexts = _visibleTexts();
    expect(
      homeTexts.any((t) => t.contains('登録車両')),
      isTrue,
      reason: 'ホームのダッシュボードが出ていない。画面の文字: ${homeTexts.join(' / ')}',
    );
    expect(
      homeTexts.any((t) =>
          t.contains('Toyota') || t.contains('Nissan') || t.contains('Mazda')),
      isTrue,
      reason: '車両が1台も並んでいない。画面の文字: ${homeTexts.join(' / ')}',
    );

    // ---- マーケット → 問い合わせ ----
    final market = find.text('マーケット');
    expect(market, findsWidgets, reason: 'マーケットの導線が無い');
    await tester.tap(market.first);
    await _pumpUntil(tester, () => find.text('問い合わせ').evaluate().isNotEmpty);
    await binding.takeScreenshot('flow_05_market');

    final inquiriesTab = find.text('問い合わせ');
    expect(inquiriesTab, findsWidgets, reason: '問い合わせタブが無い');
    await tester.tap(inquiriesTab.first);

    // 一覧にスレッドが並ぶまで待つ。
    await _pumpUntil(
      tester,
      () => _visibleTexts().any((t) => t.contains('車検見積もり')),
      maxPumps: 160,
    );
    await binding.takeScreenshot('flow_06_inquiry_list');

    final listTexts = _visibleTexts();
    expect(
      listTexts.any((t) => t.contains('車検見積もり')),
      isTrue,
      reason: '問い合わせ一覧に1年ぶんのスレッドが出ていない。'
          '画面の文字: ${listTexts.join(' / ')}',
    );

    // ---- スレッドを開く ----
    final thread = find.textContaining('車検見積もり');
    await tester.tap(thread.first);

    // **どのスレッドが開くかは一覧の並び次第。** 特定の本文を待つと、
    // 別のスレッドが開いただけで落ちる（2026-09-21 に踏んだ）。
    // 「工場の吹き出しが出たか」で待つ。
    await _pumpUntil(
      tester,
      () => _visibleTexts().any((t) => t == '工場'),
      maxPumps: 160,
    );
        // 画面遷移のアニメーションが終わるまで待ってから撮る。
    // 途中を撮ると内容が横にずれ、右端が切れた画像になる。**それを
    // 「吹き出しがはみ出している」というレイアウト不具合と読み違えた**
    // （2026-09-22）。
    await tester.pump(const Duration(seconds: 1));
await binding.takeScreenshot('flow_07_chat_thread');

    final threadTexts = _visibleTexts();
    binding.reportData = {
      ...?binding.reportData,
      'threadTexts': threadTexts.take(30).toList(),
    };

    // 店舗からの返信が読めること。ルールに弾かれると**空のスレッド**になるので、
    // 「工場」の見出しと、本文が1つ以上あることを見る。
    expect(
      threadTexts.any((t) => t == '工場'),
      isTrue,
      reason: '店舗からのメッセージが読めていない（空スレッド）。'
          '画面の文字: ${threadTexts.join(' / ')}',
    );
    expect(
      threadTexts.any((t) => t.length > 20),
      isTrue,
      reason: 'メッセージ本文が1つも出ていない。'
          '画面の文字: ${threadTexts.join(' / ')}',
    );

    // 日付が出ること（2026-09-21 に直した分）。時刻だけだと月をまたいだ
    // やりとりが見分けられない。
    final hasDatedStamp = threadTexts.any(
      (t) => RegExp(r'^\d{1,2}/\d{1,2} \d{2}:\d{2}$').hasMatch(t),
    );
    expect(
      hasDatedStamp,
      isTrue,
      reason: 'メッセージに日付が出ていない。画面の文字: ${threadTexts.join(' / ')}',
    );

    print('--- スレッドに出ている文字 ---');
    for (final t in threadTexts) {
      print(t);
    }
  });
}
