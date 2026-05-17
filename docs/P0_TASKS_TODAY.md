# P0 タスク 本日対応ガイド

> **作成日**: 2026-05-17  
> **対象者**: 開発者本人（人間）  
> **所要時間合計**: 約 20 分  
> **重要度**: これが完了しないとストア申請がブロックされます

---

## タスク一覧

| # | タスク | 所要時間 | 完了 |
|---|--------|---------|------|
| 1 | GitHub Pages 有効化 | 約 5 分 | [ ] |
| 2 | RevenueCat 本番 API キー設定 | 約 15 分 | [ ] |

---

## Task 1: GitHub Pages 有効化（約 5 分）

### やらないと何が壊れるか

- プライバシーポリシー・利用規約が公開 URL を持てない
- **App Store / Google Play 審査で必須 URL の入力欄が埋められず、審査が通らない**
- ヘルプ画面・サポートページも機能しない

### 事前確認

HTML ファイルはすでにリポジトリに生成済みです（コード変更不要）:

```
docs/web/index.html        ← サポートページ
docs/web/privacy.html      ← プライバシーポリシー
docs/web/terms.html        ← 利用規約
```

### 手順

- [ ] **1.** ブラウザで `https://github.com/zashii5793/trust-car-platform` を開く

- [ ] **2.** 画面上部のタブから **「Settings」** をクリック  
  → ページ上部に歯車アイコン付きの「Settings」タブ

- [ ] **3.** 左サイドバーをスクロールし **「Pages」** をクリック  
  → 「Code and automation」セクション内にある

- [ ] **4.** **「Source」** のドロップダウンで **「Deploy from a branch」** を選択  
  → デフォルトで選択済みの場合はそのまま

- [ ] **5.** **「Branch」** の設定を行う  
  - ブランチ: **`main`** を選択  
  - フォルダ: **`/docs`** を選択  
  → 右側のドロップダウン（「/ (root)」となっている部分）を `/docs` に変更

  ```
  Branch: [main ▼]  [/docs ▼]
  ```

- [ ] **6.** **「Save」** ボタンをクリック  
  → ページがリロードされ「GitHub Pages」セクションに「Your site is ready to be published」と表示される

- [ ] **7.** **2〜3 分待つ**（初回デプロイには時間がかかります）

- [ ] **8.** 以下の URL にアクセスして動作確認する:

  | ページ | URL |
  |--------|-----|
  | サポートページ（トップ） | `https://zashii5793.github.io/trust-car-platform/` |
  | プライバシーポリシー | `https://zashii5793.github.io/trust-car-platform/privacy.html` |
  | 利用規約 | `https://zashii5793.github.io/trust-car-platform/terms.html` |

### 成功確認

- [ ] 上記 3 URL がブラウザで正常に表示される（404 ではない）
- [ ] プライバシーポリシーページに「TrustCar プライバシーポリシー」の見出しが表示される
- [ ] `docs/HUMAN_TASKS.md` の該当行を `- [x]` に更新する

### トラブルシューティング

- **「404 not found」が表示される場合**: デプロイに時間がかかっているだけです。5 分ほど待ってから再アクセスしてください
- **「Branch が見つからない」場合**: `main` ブランチが存在するか確認してください（`master` ではなく `main`）
- **「/docs フォルダが選択できない」場合**: フォルダ `docs/` がリポジトリに存在するか確認（`docs/web/` 内に HTML があれば問題なし）

---

## Task 2: RevenueCat 本番 API キー設定（約 15 分）

### やらないと何が壊れるか

- **課金機能が一切動作しない**（スタンダード・プレミアム・エンタープライズプランの購入が不可）
- RevenueCat SDK が初期化に失敗し、アプリ起動時にエラーログが出続ける
- ストア審査員が課金フローをテストできず、**審査が却下される**

### 現状のコード（修正が必要な箇所）

**ファイル**: `lib/services/revenue_cat_service.dart` — **46 行目**

```dart
static const String _apiKey = 'REVENUECAT_API_KEY_PLACEHOLDER';
```

この `'REVENUECAT_API_KEY_PLACEHOLDER'` を本物の Public SDK キーに置き換える必要があります。

### アプリ情報（手続きで使用）

| 項目 | 値 |
|------|-----|
| アプリ名 | TrustCar |
| Bundle ID（iOS） | `jp.trustcar.app` |
| Package Name（Android） | `jp.trustcar.app` |

### 手順

#### RevenueCat アカウント作成・プロジェクト設定

- [ ] **1.** `https://app.revenuecat.com/` をブラウザで開く

- [ ] **2.** アカウントを持っていない場合: **「Get started for free」** → 登録  
  すでにアカウントがある場合: **「Log in」** でログイン

- [ ] **3.** ダッシュボード左上の **「+ Create new project」** をクリック  
  → プロジェクト名: **`TrustCar`** と入力して作成

#### Apple App Store アプリを追加

- [ ] **4.** プロジェクト画面で **「+ Add app」** → **「App Store」** を選択  
  → 右側に「App information」フォームが表示される

- [ ] **5.** 以下の情報を入力:
  - **App name**: `TrustCar`
  - **Bundle ID**: `jp.trustcar.app`
  - In-App Purchase Key（App Store Connect で生成が必要な場合は後回し可）

- [ ] **6.** **「Add app」** をクリックして保存

#### Google Play アプリを追加

- [ ] **7.** 同じプロジェクトで **「+ Add app」** → **「Play Store」** を選択

- [ ] **8.** 以下の情報を入力:
  - **App name**: `TrustCar`
  - **Package name**: `jp.trustcar.app`

- [ ] **9.** **「Add app」** をクリックして保存

#### API キーを取得する

- [ ] **10.** 左サイドバーの **「Project Settings」** をクリック  
  → サイドバー上部の歯車アイコンまたは「Settings」

- [ ] **11.** **「API Keys」** タブを開く

- [ ] **12.** **「Public app-specific keys」** セクションを探す  
  → iOS 用と Android 用それぞれのキーが表示される

  > **注意**: `appl_` で始まるキーが iOS 用（App Store）、`goog_` で始まるキーが Android 用です。  
  > Flutter（クロスプラットフォーム）の場合は **プラットフォームに応じて切り替える実装**が必要ですが、  
  > まずはいずれか 1 つのキーでも動作確認できます。

- [ ] **13.** 使用するキー（例: iOS 用）の **「Copy」** ボタンをクリックしてコピー

  > キーの形式例: `appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

#### コードを更新する

- [ ] **14.** テキストエディタ（または VSCode）で以下のファイルを開く:
  ```
  lib/services/revenue_cat_service.dart
  ```

- [ ] **15.** **46 行目** を見つける:
  ```dart
  static const String _apiKey = 'REVENUECAT_API_KEY_PLACEHOLDER';
  ```

- [ ] **16.** `'REVENUECAT_API_KEY_PLACEHOLDER'` の部分を **コピーしたキー** に置き換える:
  ```dart
  static const String _apiKey = 'appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  ```
  → シングルクォート `'...'` の中身だけを置き換え、行の他の部分は変更しない

- [ ] **17.** ファイルを保存する（`Ctrl+S` / `Cmd+S`）

#### 動作確認

- [ ] **18.** ターミナルで静的解析を実行し、エラーがないか確認:
  ```bash
  flutter analyze lib/services/revenue_cat_service.dart
  ```

- [ ] **19.** テストを実行して既存のテストが通ることを確認:
  ```bash
  flutter test test/services/revenue_cat_service_test.dart
  ```

### 成功確認

- [ ] `flutter analyze` でエラーが出ない
- [ ] `flutter test test/services/revenue_cat_service_test.dart` が全件パス（15件）
- [ ] `lib/services/revenue_cat_service.dart` の 46 行目に `PLACEHOLDER` の文字列が残っていない
- [ ] `docs/HUMAN_TASKS.md` の該当行を `- [x]` に更新する

### 重要な注意事項

> **Public キーはコードにコミット可能です**（RevenueCat の Public SDK Key はクライアントアプリに埋め込む前提で設計されています）。
>
> ただし **Secret key（`sk_` で始まるキー）は絶対にコードにコミットしないでください**。  
> Secret キーは RevenueCat ダッシュボードの「Secret API keys」セクションにあり、サーバーサイド（Cloud Functions）からのみ使用します。

### プラットフォーム別キー対応（将来の対応）

現在のコードは 1 つの `_apiKey` 定数で管理されています。iOS/Android で異なるキーを使う場合は、将来以下のように対応することも検討できます（現時点では不要）:

```dart
// 例（参考）
static const String _apiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: 'REVENUECAT_API_KEY_PLACEHOLDER',
);
```

---

## 完了後の次のステップ

両タスクが完了したら、以下を続けて実施することを推奨します（優先度順）:

1. **Firebase Authentication 有効確認**（Firebase Console → Authentication → Sign-in method → メール/パスワードが ON になっているか確認）
2. **RevenueCat Products / Entitlements 設定**（`docs/HUMAN_TASKS.md` の P1 セクション参照 — 所要時間 2〜4 時間）
3. **Apple Developer Program 登録**（`https://developer.apple.com/programs/` — 審査に最大 48 時間かかるため早めに着手）

---

> このファイルは AI（Claude）が `docs/HUMAN_TASKS.md` と `CLAUDE_SESSION_NOTES.md` および  
> `lib/services/revenue_cat_service.dart` をもとに自動生成しました。  
> 完了後は `docs/HUMAN_TASKS.md` のチェックボックスを更新してください。
