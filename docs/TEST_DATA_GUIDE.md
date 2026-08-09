# テストデータ実機確認ガイド

社長（実機確認者）向けの案内です。シードデータを投入すると、テストアカウントで
ログインするだけで **アプリの全機能をデータ入りの状態で触れる** ようになります。

---

## 1. ログイン一覧（ペルソナ A〜I）

パスワードは全員共通で **`password123`** です。

| ペルソナ | メールアドレス | 立場 | 主な確認ポイント |
|---|---|---|---|
| A | persona.a@example.com | 個人・4台持ち | 車両一覧（乗用/貨物/リース/長期保管）、投稿・ドライブログ、パーツ出品、車検見積もり問い合わせ（返信あり） |
| B | persona.b@example.com | 法人・20台フリート | フリート管理画面、車検期限アラート（期限切れ/間近）、コメントでの助言役 |
| C | persona.c@example.com | 工場比較ユーザー | 工場検索・比較、コーティング見積もり問い合わせ（返信あり・未読1件）、質問投稿 |
| D | persona.d@example.com | プリウス長期オーナー | 4年分の整備履歴、DIY整備の投稿、パーツ出品、公開ドライブログ |
| E | persona.e@example.com | 新社会人・初マイカー | 初心者目線の投稿・コメント、初回点検の予約問い合わせ（**未返信**の見え方確認） |
| F | persona.f@example.com | 売却済みユーザー | 退役車両（データ保持）の表示、手放したパーツの出品 |
| G | persona.g@example.com | EVオーナー | EVの整備履歴（オイル交換なし）、電費レビュー投稿、EV長距離ドライブログ |
| H | persona.h@example.com | 旧車オーナー | レストア投稿・イベント告知、ビート用パーツ出品、旧車ミーティングのドライブログ |
| I | persona.i@example.com | 中古車購入検討者 | 車両未保有の状態、購入相談の質問投稿、購入問い合わせ |

> ⚠️ **Auth ユーザーが作成されるのは emulator モードのみ**です
> （`seed_personas.js --emulator` が Auth エミュレータに9名を作成します）。
> 本番環境にデータを流す場合は、Firebase コンソールで上記メールの Auth ユーザーを
> **別途手動作成し、uid をシードデータの uid（`user-a` / `president-uid` / `user-c` /
> `persona-d-user` 〜 `persona-i-user`）に合わせる**必要があります。

---

## 2. 投入コマンド（この順番で実行）

前提: Firebase Emulator を起動しておく（ローカル確認の場合）。

```bash
firebase emulators:start --only auth,firestore   # 別ターミナルで起動しておく

cd scripts && npm install   # 初回のみ

# ① ペルソナ本体（users / vehicles / Auth ユーザー）— 必ず最初に
node scripts/seed_personas.js --emulator
# ※ seed_personas.js が見当たらない場合は claude/seed-personas ブランチにあります

# ② 法人フリート100台 + 1年分の履歴（任意・大規模データの見え方確認用）
node scripts/seed_fleet_year.js --emulator

# ③ フル体験データ（投稿・コメント・いいね・出品・工場・スポット・問い合わせ・公開ドライブログ）
node scripts/seed_full_experience.js --emulator

# ④ 工場マスタ（タカヤモーター含む既存の工場データ）
node scripts/seed_shops.js --emulator

# ⑤ 安全情報
node scripts/seed_safety_tips.js --emulator

# ⑥ コミュニティトレンド
node scripts/seed_community_trends.js --emulator
```

- どのスクリプトも `--dry-run` を付けると **書き込まずに** 投入予定の内容を確認できます。
- 固定ID + merge 書き込みのため、**同じスクリプトを何度流してもデータは増殖しません**。
- ⚠️ `--emulator` を付けずに実行すると **本番 Firestore** に書き込みます。本番投入は
  必ず人手承認のうえで行ってください（CLAUDE.md の禁止事項参照）。

### seed_full_experience.js が投入するもの（153ドキュメント）

| 内容 | 件数 |
|---|---|
| 愛車投稿（posts） | 9 |
| コメント（comments・返信スレッド含む） | 34 |
| 投稿いいね（post_likes） | 27 |
| コメントいいね（comment_likes） | 13 |
| パーツ出品（user_part_listings・売切れ1件含む） | 12 |
| 整備工場（shops・提携4 / 未提携6、東京・神奈川・埼玉） | 10 |
| ドライブスポット（spots） | 6 |
| スポット評価（spot_ratings） | 14 |
| 問い合わせ（inquiries・返信あり3 / 未返信1） | 4 |
| 問い合わせ返信（inquiries/{id}/messages） | 5 |
| 公開ドライブログ（drive_logs, isPublic: true） | 5 |
| ドライブログいいね（drive_log_likes） | 14 |

---

## 3. 各画面で見えるもの

### コミュニティ（投稿フィード）
- 9件の投稿（カーライフ / カスタム / レビュー / メンテナンス / 質問 / ドライブ / イベント）。
- 各投稿に 2〜6 件のコメントと「いいね」。一部は**返信スレッド**（コメントへの返信）付き。
- 車両タグ付き投稿（ロードスター / ビート / リーフ / プリウス / N-BOX / フィット）。

### パーツマーケット
- 中古ナビ・ホイール・マフラー・スタッドレス・車高調・EV充電ケーブルなど 12 出品。
  1件は「売り切れ」表示の確認用。
- ⚠️ **パーツマーケット（C2C）は機能フラグで無効化されています。**
  `lib/core/config/app_config.dart` の `FeatureFlag.c2cPartsMarketplace` が既定 `false` の
  ため、そのままでは画面の入口が表示されません。
  Firebase Remote Config でキー **`c2c_parts_marketplace`** に `true`（bool。文字列 `"true"` /
  `"1"`、数値 `1` でも可）を設定すると、`FeatureFlagService.sync()` が既定値を上書きして
  表示されます（`lib/services/feature_flag_service.dart` の `remoteKeys` 参照）。
  コード側の既定値は変更しないでください。

### 整備工場検索
- 東京（品川・世田谷・八王子・足立）、神奈川（横浜・川崎・藤沢）、埼玉（大宮・川口・所沢）
  に位置情報付きで 10 工場（すべて「テスト」を含む架空名。電話番号は誤発信防止のため未設定）。
- **提携 4 件**（subscriptionStatus: active、認証済みバッジ・問い合わせ受付あり）と
  **未提携 6 件**（free）の表示差を確認できます。
- 営業時間（定休日あり/なし）・サービス種別・評価・件数も入っています。

### 問い合わせ（ユーザー ⇔ 工場チャット）
| ログイン | スレッド | 状態 |
|---|---|---|
| persona.a | ハイエース車検見積もり → テストオート品川整備センター | 返信あり・やりとり3往復・**ユーザー側未読1件** |
| persona.h | ビート幌張り替え相談 → 横浜テストモータース | 対応中（返信1件） |
| persona.e | 初回点検の予約 → さいたまテストガレージ大宮店 | **未返信**（返信待ち表示の確認用） |
| persona.c | コーティング見積もり → 川崎テスト自動車工業 | 返信あり・未読1件 |

### ドライブ機能
- 公開ドライブログ 5 件（伊豆スカイライン / 軽井沢EV長距離 / 宮ヶ瀬 / 湘南 / 秩父）。
  距離・時間・平均/最高速度・燃費（EVは燃費なし）の統計と、他ペルソナからの「いいね」付き。
- ドライブスポット 6 件（大観山・宮ヶ瀬湖畔園地・海ほたるPA・羊山公園・奥多摩湖・架空カフェ）。
  各スポットに星評価とコメント（評価平均・件数はデータと整合済み）。

### 車両管理・フリート
- seed_personas: A の4台混在 / B の20台フリート（車検期限の警告色分け）。
- seed_fleet_year: 100台 + 12ヶ月分の整備履歴・業務ドライブログ（法人アカウントの
  Auth ユーザーは作成されないため、ログイン確認は persona.b 側で行ってください）。

---

## 4. 後片付け

投入の逆順で削除します（各スクリプトの seedTag を目印にシードデータだけを消します）。

```bash
node scripts/seed_full_experience.js --delete --emulator   # full_experience_v1 を削除
node scripts/seed_fleet_year.js --delete --emulator        # fleet_year_v1 を削除
```

- `seed_personas.js` / `seed_shops.js` / `seed_safety_tips.js` / `seed_community_trends.js` には
  `--delete` がありません。エミュレータなら再起動（またはエミュレータデータの破棄）で
  全消去できます。本番に投入してしまった場合は固定IDを手掛かりに個別削除が必要です。
- 本番で削除する場合は `--emulator` を外しますが、**実行前に必ず人手確認**してください。

---

## 5. 注意事項

- シードデータの全ドキュメントには `isSeed: true` と `seedTag` が付いています。
  本番のデータと混ざっても識別・一括削除できます。
- 工場・カフェ等の店名はすべて架空です（実在の企業名・人名は使用していません）。
- `seed_full_experience.js` は seed_personas の uid / vehicleId を参照するため、
  **必ず seed_personas.js の後に実行**してください（順番を守らないと投稿者名は
  表示されますがプロフィール等が欠けます）。
