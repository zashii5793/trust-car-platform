import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

/// 画面の見え方が、端末の幅で壊れないことを確かめる。
///
/// **狭い端末で試していない画面は、狭い端末で壊れる。**
/// Flutter のはみ出し（RenderFlex overflow）は debug ビルドで例外になるので、
/// 各サイズで描いて `takeException()` が空かどうかを見れば機械的に拾える。
///
/// 2026-08-20 に直したもの（空表示の次の一手・チップの縦位置）は、
/// **どれも文字数が増える方向の変更**なので、狭い端末でこそ崩れやすい。
/// 直したその日に、崩れないことまで見ておく。
///
/// ## 見ているサイズ
///
/// いちばん狭い 320 は iPhone SE(1st)/小型 Android の実寸。
/// ここが通れば、それより広い端末は基本的に通る。
/// タブレットは逆に「間延び」で崩れる形があるので別に見る。
void main() {
  const sizes = <String, Size>{
    '320x568 (小型)': Size(320, 568),
    '390x844 (標準)': Size(390, 844),
    '430x932 (大型)': Size(430, 932),
    '768x1024 (タブレット)': Size(768, 1024),
  };

  /// 実際に画面で使っている文面。**短い見本で試さない。**
  /// 短い文で試すと、いちばん折り返しが起きる本番の文面を通していない。
  const emptyStates = <(String, String, String?, String?)>[
    (
      'ドライブ（車両詳細）',
      'ドライブログがありません',
      'ドライブログを記録してみましょう',
      'ドライブログを記録',
    ),
    (
      'ドライブログ一覧',
      'ドライブログがありません',
      '「記録開始」でGPS記録を始めるか、\n走った分を手で入力できます',
      '手動で記録する',
    ),
    (
      '整備履歴を検索',
      '該当する整備記録がありません',
      'キーワードや種類の絞り込みを外すと、すべての整備記録が表示されます',
      '絞り込みをクリア',
    ),
    (
      '整備工場・業者',
      '整備工場・業者が見つかりません',
      '絞り込みを外すと、登録されている工場がすべて表示されます',
      '条件をクリアして再読み込み',
    ),
    (
      '問い合わせ一覧',
      '問い合わせはありません',
      '整備工場を探して、詳細画面から問い合わせを送れます',
      '整備工場を探す',
    ),
    (
      'パーツ一覧（絞り込み中）',
      'パーツが見つかりません',
      '絞り込みを外すと、出品されているパーツがすべて表示されます',
      '絞り込みをクリア',
    ),
    (
      'パーツ提案（0件）',
      '現在ご利用いただける提案はありません',
      'マーケットプレイスにパーツが登録されると、ここに提案が出ます',
      'マーケットプレイスを見る',
    ),
    (
      '読み込み失敗（再試行不可）',
      '記録を読み込めませんでした',
      'データベースの設定が不足しています。時間をおいて再度お試しください。',
      'もう一度読み込む',
    ),
  ];

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  group('空表示が、どの端末幅でも崩れない', () {
    for (final entry in sizes.entries) {
      for (final (label, title, desc, button) in emptyStates) {
        testWidgets('${entry.key} — $label', (tester) async {
          await pumpAt(
            tester,
            entry.value,
            AppEmptyState(
              icon: Icons.directions_car_outlined,
              title: title,
              description: desc,
              buttonLabel: button,
              onButtonPressed: () {},
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text(title), findsOneWidget);
          if (button != null) {
            expect(find.text(button), findsOneWidget);
          }
        });
      }
    }
  });

  group('横スクロールのチップが、潰れない', () {
    // **原因は引き伸ばしではなく圧縮だった**（2026-08-20 実測）。
    //
    //   自然な高さ                      40.0
    //   固定高さ42 − 上下padding8ずつ    26.0  ← ここまで潰されていた
    //
    // 最初は Center で包んだが、**まったく効かなかった**（34.0 のまま）。
    // Center は余った空間で中央に寄せる道具で、**足りない空間は作れない**。
    // 固定高さをやめ、中身の高さで行が決まる形にして直した。
    Widget chip() => ChoiceChip(
          label: const Text('エアロパーツ'),
          selected: false,
          onSelected: (_) {},
          visualDensity: VisualDensity.compact,
          labelStyle: const TextStyle(fontSize: 12),
        );

    testWidgets('自然な高さは 40。ここを下回ると文字が沈む', (tester) async {
      await pumpAt(tester, const Size(390, 844),
          Align(alignment: Alignment.topLeft, child: chip()));
      expect(tester.getSize(find.byType(ChoiceChip)).height, 40.0);
    });

    testWidgets('内容で高さが決まる行では、チップが潰れない', (tester) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [chip(), chip(), chip()]),
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ChoiceChip).first).height, 40.0,
          reason: 'チップが自然な高さを保てていません（文字が沈む原因）');
    });

    testWidgets('固定高さの行に入れると潰れる（元の壊れ方の記録）', (tester) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: chip(),
              ),
            ],
          ),
        ),
      );
      // 直した形との差をここに残す。**再発したらこの数字に戻る。**
      expect(tester.getSize(find.byType(ChoiceChip).first).height, 26.0);
    });

    for (final entry in sizes.entries) {
      testWidgets('${entry.key} — チップ行がはみ出さない', (tester) async {
        await pumpAt(
          tester,
          entry.value,
          Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: List.generate(18, (_) => chip())),
            ),
          ]),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('長い日本語のラベルでも、ボタンが読める', () {
    testWidgets('320 幅で、いちばん長いボタン文言が省略されない', (tester) async {
      const longest = '条件をクリアして再読み込み';
      await pumpAt(
        tester,
        const Size(320, 568),
        AppEmptyState(
          icon: Icons.store_outlined,
          title: '整備工場・業者が見つかりません',
          description: '絞り込みを外すと、登録されている工場がすべて表示されます',
          buttonLabel: longest,
          // **両方渡さないとボタンは描かれない**（AppEmptyState の実装）。
          // 片方だけ渡して「出るはず」と書くと、テストが嘘をつく。
          onButtonPressed: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(longest));
      expect(text.overflow, isNot(TextOverflow.ellipsis),
          reason: 'ボタンの文言が省略されると、何が起きるか読めません');
    });
  });
}
