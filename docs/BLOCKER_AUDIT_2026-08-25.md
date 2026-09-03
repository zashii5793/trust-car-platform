# ブロッカー再監査（2026-08-25）

**目的**: 内部リポジトリの `APP_STORE_LAUNCH_READINESS_2026-07.md`（7月）と
`BUSINESS_VIABILITY_ASSESSMENT.md`（6月）の指摘が、**いまのコードでまだ成り立つか**を
実地で確かめる。古い前提のまま優先順位を決めると、済んだ仕事をやり直すことになる。

**方法**: すべてコード・設定ファイル・GitHub の実測。文書の記述は根拠にしない。

---

## 0. 結論

**7月に挙がっていた提出ブロッカーは、ほぼ片付いている。** 残っているのは1件だけ。
一方、**7月の文書に無い、より重い問題が2件**見つかった。

| 重さ | 項目 | 状態 |
|---|---|---|
| **最重** | iOS がそもそも起動しない（Firebase の Bundle ID 不一致） | **未解決** |
| **重** | 未マージPR **30本**（愛車カルテPDF・OCR修正・地図を含む） | **未解決・悪化** |
| 中 | B-2 購入を復元するUI（B2C側） | **未解決** |
| — | A-1 / A-2 / A-3 / B-3 / B-4 / B-5 | **解決済み** |
| — | D-2 ROI可視化UI・7.1 業態拡張・7.2 網羅表示・7.3 需要蓄積 | **実装済み** |

---

## 1. 提出ブロッカー（7月 §A）— すべて解決済み

| # | 7月の指摘 | いまの実測 | 判定 |
|---|---|---|---|
| A-1 | Sign in with Apple 未実装 | `auth_service.dart:135` に `signInWithApple()`。`signup_screen.dart:76` から配線 | **解決** |
| A-2 | アカウント削除 未実装＋規約に虚偽記載 | `AuthService.deleteAccount()`（`auth_service.dart:243`）／`settings_screen.dart:111` に退会導線 | **解決** |
| A-3 | Privacy Manifest 未作成 | `ios/Runner/PrivacyInfo.xcprivacy` が存在 | **解決** |

---

## 2. 却下リスク（7月 §B）— 1件だけ残っている

| # | 7月の指摘 | いまの実測 | 判定 |
|---|---|---|---|
| B-1 | RevenueCat APIキーがプレースホルダ | プレースホルダは撤去済み。`--dart-define` → `.env` の順で解決し、未設定なら空文字を返す（`revenue_cat_service.dart:57`）。**本番キーの投入は人間の作業として残る** | 実装は解決 |
| **B-2** | **購入を復元するUIが無い** | **未解決。しかも場所が変わった**（下記） | **未解決** |
| B-3 | B2Cプレミアムの購入経路が不在 | `settings/plan_screen.dart:311` で `purchasePremium` | **解決** |
| B-4 | Always位置情報の過剰宣言 | `Info.plist` は `NSLocationWhenInUseUsageDescription` のみ | **解決** |
| B-5 | Bundle ID不整合 | `project.pbxproj` は全て `jp.trustcar.app` | **解決** |

### B-2 は7月より状況が悪い

```
 工場向けプラン画面   shop_plan_screen.dart:118  → restorePurchases あり
 B2Cプレミアム画面    settings/plan_screen.dart  → 復元が無い
 UserSubscriptionProvider                        → restore メソッド自体が無い
```

7月時点は「B2Cプレミアムは購入導線が無い」（B-3）ので、復元も問われなかった。
**その後 B-3 を解消して買えるようにした結果、「買えるのに復元できない」状態になった。**
自動更新サブスクリプションで復元手段が無いのは、ガイドライン 3.1.1 の指摘対象。

**直し方**: `UserSubscriptionProvider` に `restorePurchases` を足し、
`RevenueCatService.restorePurchases`（既にある・`revenue_cat_service.dart:184`）を呼ぶ。
`settings/plan_screen.dart` に導線を置く。工場側に前例があるので迷う余地は少ない。

---

## 3. 7月の文書に無い、より重い問題

### 3-1. iOS がそもそも起動しない（最重）

`ios/Runner/GoogleService-Info.plist`:

```
 BUNDLE_ID      com.example.trustCarPlatform
 GOOGLE_APP_ID  1:31421119456:ios:4320af5d1401f02c80c985
```

実際のアプリは `jp.trustcar.app`。**この食い違いで iOS は白画面のまま起動しない。**
審査以前に、ビルドが動かない。

**Firebase の iOS アプリは、後から Bundle ID を変更できない。** `jp.trustcar.app` で
新規登録し、`GoogleService-Info.plist` を差し替える必要がある（Firebase Console での
作業＝人間）。Android は 2026-08-23 に同じ手当てを済ませてある。

詳細: `docs/TESTUSER_ROLLOUT_2026-08.md`

### 3-2. 未マージPRが30本（重・7月より悪化）

7月 D-4 は「積み上がった未マージPRの価値が本番未反映」。**いま30本ある。**
中身を見ると、事業性評価が「差別化機能」と呼んだものが軒並み止まっている。

| PR | 内容 | 事業上の意味 |
|---|---|---|
| #90 | 愛車カルテPDF（Issue #64） | **「溜めた記録を売却材料に変える」の中核。実装済みで止まっている** |
| #145 | 日本語OCR修正＋カタログ外入力の候補記録 | 車検証OCRはテストの最重要確認項目 |
| #126 / #106 | 工場詳細の地図プレビュー／近隣工場の色分けピン（Issue #41） | 7.2 網羅表示の残り |
| #98 / #88 | AppTextField統一（Issue #29） | 7月 D-5 |
| #148 / #144 / #142 | 事業フォーカス戦略・人間タスク計画・オンボーディング文言 | — |
| #127〜#141 | dependabot 15本 | — |

**前回のセッションで「愛車カルテPDF は未着手」と述べたのは誤り。** 実装済みで、
PR #90 として止まっている。訂正する。

---

## 4. 事業性評価（6月）の主張 — 実装で追い越している項目

| 主張 | 6月時点 | いまの実測 | 判定 |
|---|---|---|---|
| 2.2 B2BのROIを証明できていない | 未実装 | `shop_owner_screen.dart:586` `_MonthlyReportCard`（今月の問い合わせ数・未対応・回答済み・前月比）が `loadMonthlyReport` 経由で稼働 | **実装済み** |
| 2.3 KYC不在 | 検証フロー無し | **フローは今も無い。** ただし `shop_map_utils.dart:38` で「（審査済）」表示、`shop_registration_screen.dart:112` で `isVerified` を扱う。**手動審査＋バッジ表示の土台はある** | 部分的 |
| 2.5 C2C は凍結すべき | — | `kEnableC2cParts` の既定が `false`。`--dart-define` でしか開かず、本番は Remote Config 切替 | **凍結済み** |
| 7.1 ガソリンスタンドを ShopType に | 無し | `ShopType.gasStation('ガソリンスタンド')` が存在（Issue #40 CLOSED） | **実装済み** |
| 7.2 非提携先も表示・審査済バッジ | 未 | `nearby_shops_map_screen.dart` が `isPartner` で色分け（Issue #41 CLOSED）。残りは PR #126/#106 | **ほぼ実装済み** |
| 7.3 質問は提携先のみ／需要蓄積 | 未 | `shop_demand_service.dart` が存在し、`inquiry_screen` / `shop_owner_screen` から使われている（Issue #41 CLOSED） | **実装済み** |
| 7.4 B2C ¥980 は未実装 | 未実装 | `_productBtocPremium = 'trustcar_btoc_premium_monthly'` と購入導線が存在。**金額はアプリ側に持たず、ストア側の商品定義に委ねる形**（正しい） | **実装済み** |
| 7.5 初期パートナー価格 | 未 | Issue #42 が OPEN のまま | **未着手** |

**6月に「最優先」とされた D（ROI可視化）は、既に片付いている。**
順序の鉄則「D → B/C → E」でいうと、E（キャンペーン価格）の番まで来ている。

---

## 5. 実データの穴（6月 D-1 / 今日の指摘）

| 項目 | 実測 |
|---|---|
| 工場データ | `seed_shops.js` の実在店は **`shop_takaya_motor_okayama` の1件のみ**。他は `demo_*` の架空8件 |
| パーツデータ | `seed_parts.js` は「商品名・ブランド名・型番はすべて架空」と明記。架空12件 |
| 車種マスタ | 2026-08-25 に 9メーカー/88車種 → **15メーカー/403車種**（トラック34・バン32）へ拡張済み |
| 貨物車ユーザー | ペルソナJ（配送業）を追加済み。それまで貨物は1台のみ、軽貨物・事業用はゼロ |

**D-1（実在工場ゼロ）は6月から動いていない。** これは営業＝人間の仕事なので、
AI側でできるのは「登録しやすい形にする」「架空データを本番に出さない」まで。

---

## 6. 潰す順序（提案）

| # | 項目 | 誰が | なぜこの順か |
|---|---|---|---|
| 1 | **iOS の Firebase アプリ再登録** | 人間（Console）＋AI（差し替え） | **動かないものは審査に出せない。** 他の全部の前提 |
| 2 | **B-2 購入を復元するUI** | AI | 小さく、確実に却下理由を1つ消す。工場側に前例あり |
| 3 | **未マージPRの棚卸しとマージ** | AI＋人間レビュー | 30本。特に #90（愛車カルテPDF）と #145（OCR修正）は事業価値が止まっている |
| 4 | KYC の手動審査フロー | 人間（運用）＋AI（管理UI） | 「Trust」の看板。初期は手動でよい |
| 5 | 実在工場の登録 | 人間（営業） | AIでは作れない。1商圏に絞る |

**1 と 2 は今日中に着手できる。** 3 は本数が多いので、まず分類（依存関係・CI状態）から。

---

*監査日: 2026-08-25 / すべてコード・設定・GitHub の実測に基づく*
