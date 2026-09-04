# 非公開ドキュメントの置き場所

事業側の資料（事業性評価・コスト試算・マーケティング）は、このリポジトリには置きません。

**置き場所**: https://github.com/zashii5793/trust-car-platform-internal （private）

| 移したもの | 旧パス |
|---|---|
| 事業性評価（辛口レビュー） | `docs/BUSINESS_VIABILITY_ASSESSMENT.md` |
| 運用コスト試算 | `docs/OPERATIONS_COST_ESTIMATE.md` |
| ソフトローンチの運用コスト試算 | `docs/SOFT_LAUNCH_COST_ESTIMATE.md` | 
| マーケティングアピールレポート | `docs/MARKETING_APPEAL_REPORT.md` |
| App Store ローンチ実現性評価 | `docs/APP_STORE_LAUNCH_READINESS_2026-07.md` |

## なぜ

**このリポジトリは public です。** `docs/` 配下の Markdown は GitHub 上で誰でも読めます。

```
https://raw.githubusercontent.com/zashii5793/trust-car-platform/main/docs/OPERATIONS_COST_ESTIMATE.md  → 200
```

2026-08-24 に GitHub Pages を止めましたが、それで止まるのは「Jekyll が描画した HTML」だけで、
**ソースは元から公開されています。** Pages を止めたことと、この件は別です。

リポジトリごと private にする案は見送りました。**GitHub Actions の無料枠が月2,000分に
なる**ためです（public は無制限）。iOS ビルドは 10 倍課金で実測 18 分＝180 分なので、
月10回程度で枠を使い切ります。

技術ドキュメント（アーキテクチャ・機能仕様・デザインシステム・運用ランブック）は
公開したままです。読まれて困る内容ではなく、隠すと開発の見通しが悪くなるためです。

## 注意

**移したファイルは、このリポジトリの git 履歴に残っています。**
最新の状態から消えるだけで、過去のコミットを辿れば読めます。完全に消すには履歴の
書き換えと force push が要りますが、未マージの PR が全て壊れます。

**すでに公開された情報として扱ってください。** 今回の対応で止まるのは、これ以降の
追記・更新です。

## これから書くとき

金額・収益見込み・競合の評価を含むものは internal 側へ。
コードの読み方・設計・手順はこちらで構いません。迷ったら internal 側に置いてください。
