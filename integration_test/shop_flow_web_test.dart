// ignore_for_file: avoid_print
/// **店舗側**の画面を、実際に操作して通す。
///
/// なぜ要るか:
///   2026-09-20 まで、店主の uid が店の文書ID とずれていたため、
///   **店側の画面は一度も実データで開けていなかった。**
///   アプリは `shops/{uid}` を直接引き、ルールも `uid == shopId` で当事者を
///   判定するので、ずれていると店が見つからず、問い合わせもチャットも空になる。
///
///   直したあと、**本当に開けるようになったのかを画面で確かめる**のがこのテスト。
///
/// 前提:
///   1. firebase emulators:start --only auth,firestore,storage
///   2. ./scripts/seed_all.sh
///   3. chromedriver --port=4444 &
///   4. flutter drive \
///        --driver=test_driver/integration_test.dart \
///        --target=integration_test/shop_flow_web_test.dart \
///        -d web-server --browser-name=chrome --profile \
///        --dart-define=USE_EMULATOR=true
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trust_car_platform/main.dart' as app;

import 'flow_helpers.dart';

const _email = 'shop.owner@example.com';
const _password = 'password123';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('店主が自分の店と問い合わせを開くまでを操作で通す', (tester) async {
    app.main();

    // 店主も車両は持っていないので、ホームは空表示で正しい。
    // タブが出てタップできる状態になったことだけを待つ。
    await loginAndWaitHome(
      tester,
      email: _email,
      password: _password,
      homeReady: () => visibleTexts().any((t) => t.contains('マーケット')),
    );
    await binding.takeScreenshot('shop_01_home');

    // ---- マーケットタブへ ----
    // 店舗掲載の入口は「マーケットタブの AppBar にある店舗アイコン」。
    // ホームのタブでは出ない（home_screen.dart の _currentIndex == 1）。
    await tester.tap(find.text('マーケット').first);
    await pumpUntil(
      tester,
      () => find.byTooltip('店舗を掲載する').evaluate().isNotEmpty,
    );
    await binding.takeScreenshot('shop_02_market');

    final storefront = find.byTooltip('店舗を掲載する');
    expect(storefront, findsOneWidget,
        reason: '店舗掲載の入口が無い。画面の文字: ${visibleTexts().join(' / ')}');
    await tester.tap(storefront);

    // ---- 掲載管理（自分の店が引けているか） ----
    //
    // ここが本題。`getMyShop(uid)` が `shops/{uid}` を引けないと、
    // 「店舗を登録」の空状態になる。
    //
    // **待つ文字は遷移先にしか無いものを選ぶ。** 最初「タカヤモーター」で
    // 待ったが、それは遷移前の工場一覧にも出ているので即成立してしまい、
    // 遷移していないのにテストが緑になった（2026-09-22。この手の取り違えは
    // これで3回目）。'掲載管理' は掲載管理画面の AppBar にしか無い。
    final shopLoaded = await pumpUntil(
      tester,
      () => visibleTexts().any((t) => t == '掲載管理'),
      maxPumps: 400,
    );
    await binding.takeScreenshot('shop_03_owner_dashboard');

    final ownerTexts = visibleTexts();
    binding.reportData = {'ownerTexts': ownerTexts.take(40).toList()};

    expect(
      shopLoaded,
      isTrue,
      reason: '掲載管理の画面に遷移していない。'
          '画面の文字: ${ownerTexts.join(' / ')}',
    );

    // 自分の店が引けていること。引けていないと「店舗を登録」の空状態になる。
    expect(
      ownerTexts.any((t) => t.contains('タカヤモーター')),
      isTrue,
      reason: '店主でログインしても自分の店が出ない（shops/{uid} が引けていない）。'
          '画面の文字: ${ownerTexts.join(' / ')}',
    );

    // ---- 店舗側の問い合わせ一覧へ ----
    //
    // 「問い合わせ 全7件（未読1件）」のカードから入る。
    //
    // 件数の行（「全 7 件（未読 1 件）」）は色分けのため RichText で、
    // `find.byType(Text)` にも `find.textContaining` にも当たらない。
    // **画面の文字を目で見て選ぶと、こういう当たらない的を選ぶ。**
    // カードの中のメールアイコンを的にする。
    // アイコンだけを的にすると、統計欄のメールアイコン（押せない）に当たる。
    // カードそのもの（'問い合わせ' を含む InkWell）を取る。
    //
    // **`.last` を使う。** 遷移元のマーケット画面もツリーに残っていて
    // '問い合わせ' タブを持っているので、`.first` だと下の画面に当たる。
    // あとから push された画面の方が後ろに来る。
    final inquiryCard = find.ancestor(
      of: find.text('問い合わせ'),
      matching: find.byType(InkWell),
    );
    binding.reportData = {
      ...?binding.reportData,
      'inquiryCardMatches': inquiryCard.evaluate().length,
    };
    expect(inquiryCard, findsWidgets,
        reason: '問い合わせのカードが無い。画面の文字: ${ownerTexts.join(' / ')}');
    await tester.tap(inquiryCard.last);

    // 待つのは遷移先にしか無い '問い合わせ一覧'（AppBar）。
    final listOpened = await pumpUntil(
      tester,
      () => visibleTexts().any((t) => t == '問い合わせ一覧'),
      maxPumps: 400,
    );
    // 一覧が読み込まれるまでもう少し待つ（件数が出てから撮る）。
    await pumpUntil(
      tester,
      () => visibleTexts().any((t) => t.contains('車検') || t.contains('オイル')),
      maxPumps: 400,
    );
    await binding.takeScreenshot('shop_04_inquiry_list');

    final listTexts = visibleTexts();
    binding.reportData = {
      ...?binding.reportData,
      'shopInquiryTexts': listTexts.take(40).toList(),
    };

    expect(listOpened, isTrue,
        reason: '問い合わせ一覧に遷移していない。画面の文字: ${listTexts.join(' / ')}');

    // 店側に、お客様から届いた問い合わせが並ぶこと。
    // ルールに弾かれると**一覧ごと空**になる（今回直した不具合の本丸）。
    expect(
      listTexts.any((t) => t.contains('車検') || t.contains('オイル')),
      isTrue,
      reason: '店側の問い合わせ一覧が空。画面の文字: ${listTexts.join(' / ')}',
    );

    // ---- スレッドを開く（詳細シート） ----
    //
    // 未対応の「ロードスターから異音がします（相談）」が先頭に来る。
    await tester.tap(find.textContaining('ロードスターから異音').first);

    // 待つのはシートにしか無い返信欄の hint。
    final sheetOpened = await pumpUntil(
      tester,
      () => find.text('返信メッセージを入力...').evaluate().isNotEmpty,
      maxPumps: 400,
    );
        // 画面遷移のアニメーションが終わるまで待ってから撮る。
    // 途中を撮ると内容が横にずれ、右端が切れた画像になる。**それを
    // 「吹き出しがはみ出している」というレイアウト不具合と読み違えた**
    // （2026-09-22）。
    await tester.pump(const Duration(seconds: 1));
await binding.takeScreenshot('shop_05_thread_sheet');

    final sheetTexts = visibleTexts();
    binding.reportData = {
      ...?binding.reportData,
      'sheetTexts': sheetTexts.take(40).toList(),
    };

    expect(sheetOpened, isTrue,
        reason: '詳細シートが開かない。画面の文字: ${sheetTexts.join(' / ')}');

    // お客様の相談内容が店側から読めること。
    expect(
      sheetTexts.any((t) => t.contains('コトコト')),
      isTrue,
      reason: 'お客様のメッセージが店側に出ていない。'
          '画面の文字: ${sheetTexts.join(' / ')}',
    );

    // ---- 店舗として返信する ----
    //
    // ここが「店とお客様のやりとり」の本丸。**送信は実データで一度も
    // 確かめられていなかった。** エミュレータのデータは書き換わるので、
    // 流し直したいときは ./scripts/seed_all.sh。
    const reply = 'ご連絡ありがとうございます。今週末の土曜9時で空いております。'
        '足回りを見ますので、1時間ほどお預かりします。';

    final replyField = find.byType(TextField).last;
    await typeInto(tester, replyField, reply);
    await binding.takeScreenshot('shop_06_reply_typed');

    final sendButton = find.byIcon(Icons.send);
    expect(sendButton, findsWidgets, reason: '送信ボタンが無い');
    await tester.tap(sendButton.last);

    // 送信が**終わる**まで待つ。
    //
    // 本文が出ただけだと、まだ送信中（スレッドにスピナーが出て、入力欄に
    // 文面が残っている）瞬間を撮ってしまう。2026-09-22 にその瞬間を撮って
    // 「ステータスが変わっていない」と読み違えた。
    // 店舗の初回返信で 未対応 → 回答済み に変わるので、そこまで待つ。
    final sent = await pumpUntil(
      tester,
      () =>
          visibleTexts().any((t) => t.contains('今週末の土曜9時')) &&
          visibleTexts().any((t) => t == '回答済み'),
      maxPumps: 400,
    );
    await binding.takeScreenshot('shop_07_reply_sent');

    final afterTexts = visibleTexts();
    binding.reportData = {
      ...?binding.reportData,
      'afterSendTexts': afterTexts.take(40).toList(),
    };

    expect(
      sent,
      isTrue,
      reason: '店舗からの返信がスレッドに出ない（送信に失敗している）。'
          '画面の文字: ${afterTexts.join(' / ')}',
    );

    // 送ったのにステータスが「未対応」のままだと、店主は送れたか分からない。
    expect(
      afterTexts.any((t) => t == '回答済み'),
      isTrue,
      reason: '返信後もステータスが変わっていない。'
          '画面の文字: ${afterTexts.join(' / ')}',
    );

    print('--- 返信後のスレッド ---');
    for (final t in afterTexts) {
      print(t);
    }
  });
}
