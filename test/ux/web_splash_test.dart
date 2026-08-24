import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Web を開いた直後の見え方を守る。
///
/// 2026-08-23 に Firebase Emulator 版を実際にブラウザで開いて分かったこと:
///
/// 1. アプリが立ち上がるまで**真っ白**な画面が数秒続く。
/// 2. 立ち上がった直後、日本語が **□□□** で表示される。Flutter Web は
///    日本語のフォントを後から取りに行くため、届くまで豆腐になる。
///
/// どちらも不具合ではないが、**初見の人はここで「壊れている」と判断する。**
/// テストユーザーに配る画面の第一印象なので、読み込み中であることが分かる
/// スプラッシュで覆う。スプラッシュ自身は HTML なので、ブラウザが持っている
/// システムフォントで即座に日本語が出る（豆腐にならない）。
///
/// この検査は `web/index.html` の中身を読むだけ。ブラウザは要らない。
/// **消す処理が入っているか**まで見るのは、消えないスプラッシュは
/// 白画面より悪いから。
void main() {
  late String html;

  setUpAll(() {
    html = File('web/index.html').readAsStringSync();
  });

  group('Web の起動スプラッシュ', () {
    test('スプラッシュの要素がある', () {
      expect(html, contains('id="splash"'));
    });

    test('読み込み中であることが日本語で書いてある', () {
      expect(html, contains('TrustCar'));
      expect(
        html.contains('読み込'),
        isTrue,
        reason: '「読み込んでいます」など、待てば出ると分かる文言が要る',
      );
    });

    test('スプラッシュ自身はシステムフォントで描く（ここが豆腐だと本末転倒）', () {
      expect(html, contains('font-family'));
      expect(
        html.contains('sans-serif'),
        isTrue,
        reason: 'Web フォントを待つ指定だとスプラッシュ自体が □□□ になる',
      );
    });

    test('最初のフレームが出たら消す', () {
      expect(html, contains('flutter-first-frame'));
    });

    test('日本語フォントが届くまで消さない', () {
      // 2026-08-24 実測: 最初のフレームで消すと、その先に □□□ が残った。
      // 日本語フォントの取得は描画の後に始まり、終わるまで 1.5〜6.7 秒
      // かかっていた。固定の待ち時間ではなく、取得そのものを見て判断する。
      expect(html, contains('fonts.gstatic.com'));
      expect(html, contains('PerformanceObserver'));
    });

    test('待つ相手を日本語フォントに限っている', () {
      // 最初の実装は fonts.gstatic.com への取得すべてを数えていた。
      // Flutter は Roboto も同じ配布元から取りに行き、そちらは 1.4 秒で
      // 届く（Noto Sans JP は 3.2 秒）。Roboto の到着で消してしまい、
      // 消えた先が □□□ のままだった。
      expect(html, contains('notosansjp'));
    });

    test('あとから実測できる痕跡を残す', () {
      // 「直したつもり」を目視だけで確かめるのは高くつく。
      // window.__splashTrace に、最初のフレーム・フォント到着・消した時刻を
      // 残しておけば、ブラウザのコンソール1行で確かめられる。
      expect(html, contains('__splashTrace'));
    });

    test('フォントの取得が始まらない場合も消える', () {
      // キャッシュ済みなどで取りに行かないことがある。その場合に
      // 「フォント待ち」で固まらないよう、待たずに消す道が要る。
      expect(html, contains('NO_FONT_MS'));
    });

    test('フォントの配布元へ先に接続しておく', () {
      expect(html, contains('rel="preconnect"'));
      expect(html, contains('https://fonts.gstatic.com'));
    });

    test('最初のフレームが来なくても消える逃げ道がある', () {
      // ビルドが壊れて Flutter が立ち上がらないと、first-frame は永遠に来ない。
      // その場合にスプラッシュが残り続けると、何が起きているのか分からない。
      expect(html, contains('setTimeout'));
    });

    test('時間がかかっているときの案内がある', () {
      expect(
        html.contains('時間がかかって'),
        isTrue,
        reason: '待たせるなら、待たせている自覚を画面に出す',
      );
    });

    group('Edge Cases', () {
      test('スプラッシュはアプリの上に重なる（z-index 指定がある）', () {
        expect(html, contains('z-index'));
      });

      test('外部のフォントやスクリプトに依存しない', () {
        // CDN が遅い/届かない環境でスプラッシュまで出ないのでは意味がない。
        final splashStart = html.indexOf('id="splash"');
        expect(splashStart, greaterThan(-1));
        final splash = html.substring(splashStart);
        final splashEnd = splash.indexOf('</div>');
        final splashMarkup = splash.substring(0, splashEnd);

        expect(splashMarkup.contains('http://'), isFalse);
        expect(splashMarkup.contains('https://'), isFalse);
      });
    });
  });
}
