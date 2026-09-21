// 特定商取引法に基づく表示のページを見張る。
//
// なぜ要るか:
//   同じ内容のファイルが **2か所** にある。
//
//     web/tokushoho.html        公開サイト（アプリの設定画面から開く先）
//     docs/web/tokushoho.html   GitHub Pages 用
//
//   片方だけ直すと、アプリから開くページと公開ページで表示が食い違う。
//   法定表示なので、食い違ったまま気づかないのがいちばん困る。
//
//   人間が埋める箇所（氏名・所在地・電話番号・公開日）が残っていることも
//   ここで数えておく。**残数が変わったら気づける**ようにしておくと、
//   「埋めたつもりで1つ残っていた」を防げる。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// テストの作業ディレクトリはリポジトリのルート。
File _file(String path) => File(path);

void main() {
  group('特商法ページ', () {
    test('web/ と docs/web/ の内容が一致している', () {
      final a = _file('web/tokushoho.html');
      final b = _file('docs/web/tokushoho.html');

      expect(a.existsSync(), isTrue, reason: 'web/tokushoho.html が無い');
      expect(b.existsSync(), isTrue, reason: 'docs/web/tokushoho.html が無い');

      expect(
        a.readAsStringSync(),
        b.readAsStringSync(),
        reason: '2つの tokushoho.html が食い違っています。'
            '**片方だけ直していないか確認してください。**',
      );
    });

    test('人間が埋める箇所の数が分かる', () {
      final text = _file('web/tokushoho.html').readAsStringSync();

      // 冒頭のチェックリスト（コメント）は数えない。本文だけを見る。
      //
      // **コロン付きだけを数える。** 「【要記入】 の欄は…」という説明文が
      // 本文中にあり、これは埋める対象ではない（2026-09-22 に数え違えた）。
      final body = text.split('-->').last;
      final remaining = RegExp('【(要記入|公開前に確認):').allMatches(body).length;

      // 2026-09-22 時点で 5 か所（公開日・氏名・所在地・電話番号・価格の確認）。
      // **埋めたらこの数を減らすこと。** 0 になったら公開できる状態。
      expect(
        remaining,
        5,
        reason: '未記入の箇所が $remaining 件です（期待 5 件）。'
            '埋めたならこのテストの期待値も一緒に直してください。'
            '新しく増えたなら、増えた理由を確かめてください。',
      );
    });
  });
}
