# 【P0手順書】Firestore セキュリティルール / インデックスの本番デプロイ

> リリースブロッカー P0 #1。**人間が実行**（AIはConsole/CLIログイン不可）。
> 所要: 5〜10分（インデックス構築完了はバックグラウンドで数分〜数十分）。
> 対象プロジェクト: **`trust-car-platform`**（`.firebaserc` で確認済み）

> ⚠️ このコマンドは**本番Firebaseに即時反映**されます。`firebase deploy` の `--only` を必ず付け、
> Functions やアプリ本体を巻き込まないこと。

---

## 0. 事前検証（AI実施済み・結果サマリー）

このセッションでファイル内容を検証済み:

- ✅ `firebase.json` は `firestore.rules` / `firestore.indexes.json` / `storage.rules` を正しく参照
- ✅ `firestore.indexes.json` は **41インデックス**で構造的に正常（`//` コメントはCJSON形式。firebase-tools が許容）
- ✅ `safety_tips` 複合インデックス2本（`isActive+publishedAt`, `isActive+category+publishedAt`）存在
- ✅ ルールに新規コレクション（`community_maintenance_trends`, `fleet_members`, `accessory_showcases`, `car_purchase_inquiries`, `safety_tips`, `shop_chains` 等）の match ブロックが存在
- ✅ `rules_version = '2'`

→ **デプロイ可能な状態**。あとは下記コマンドを実行するだけ。

---

## 1. 前提条件（初回のみ）

```bash
# Firebase CLI 未インストールの場合
npm install -g firebase-tools

# バージョン確認（comments付きindexes.jsonのため 11.x 以降推奨。最新が安全）
firebase --version

# ログイン（ブラウザが開く）
firebase login
```

**必要権限**: `trust-car-platform` プロジェクトの **編集者 / オーナー**（Firestore ルール書き込み権限）。

---

## 2. デプロイ元コードの確認（重要）

ルール/インデックスは**本番に出す版**からデプロイすること。基本は `main`:

```bash
cd /path/to/trust-car-platform
git checkout main
git pull origin main

# 使用プロジェクトが trust-car-platform であることを確認
firebase use
#   → 'default' が trust-car-platform でなければ:
firebase use trust-car-platform
```

> 補足: ルール/インデックスのファイルは PR #28 では変更していないため、`main` の内容と同一です。

---

## 3. デプロイ（ルール → インデックスの順に、分けて実行）

**失敗を切り分けるため、必ず2回に分けて実行する。**

### 3-1. ルールを先にデプロイ（即時反映・低リスク）

```bash
firebase deploy --only firestore:rules
```

- 期待出力: `✔ Deploy complete!` と `firestore: released rules firestore.rules to cloud.firestore`
- ルールは**即時反映**。失敗時はエラー行が表示される（構文エラー等）→ 反映されないだけで実害なし。

### 3-2. インデックスをデプロイ

```bash
firebase deploy --only firestore:indexes
```

- ⚠️ **対話プロンプトに注意**: 既存に「ファイルに無いインデックス」があると
  「削除しますか?」と聞かれることがある。**意図しない削除を避けるため、内容を読んでから回答**。
  迷ったら `No`（削除しない）を選ぶ。
- インデックスの**構築は非同期**。コマンド完了後も Console 上で "Building" → "Enabled" になるまで数分〜数十分かかる。
- ⚠️ 構築完了前は該当クエリが一時的に失敗し得る → **公開ユーザーへの告知前にEnabled化を待つこと**。

> 補足: `firestore.indexes.json` に `//` コメントがあるが firebase-tools は許容する。
> 万一 `JSON parse error` が出る古いCLIなら、`npm i -g firebase-tools` で最新化してから再実行。

---

## 4. デプロイ後の検証

### 4-1. ルール反映の確認
- Firebase Console → Firestore Database → **ルール** タブ → 右上「バージョン履歴」で
  **今のデプロイ日時**が最新になっていることを確認。

### 4-2. インデックス状態の確認
- Firebase Console → Firestore Database → **インデックス** タブ →
  すべてのインデックスが **Enabled（有効）**（"Building" が残っていない）ことを確認。
- 特に `safety_tips` の複合インデックス2本が Enabled であること
  （これが無いと安全運転情報の絞り込みクエリが500エラーになる）。

### 4-3. ルールの動作確認（任意・推奨）
- Console → Firestore → ルール → **Rules Playground（シミュレータ）** で:
  - 認証済みユーザーが自分の `vehicles/{id}` を read/write → **許可**されること
  - 他人の `vehicles/{id}` を write → **拒否**されること
  - `community_maintenance_trends` を未認証で read → **拒否**、認証済みで read → **許可**

---

## 5. ロールバック（問題が起きたら）

- **ルール**: Console → ルール → バージョン履歴 → 直前のバージョンを選んで「復元」。
  またはローカルで前バージョンの `firestore.rules` に戻して再 `firebase deploy --only firestore:rules`。
- **インデックス**: 追加されたインデックスは害が少ない（クエリ高速化のみ）。
  不要なら Console のインデックス一覧から個別削除。

---

## 6. やってはいけないこと（ガードレール）

- ❌ `firebase deploy`（`--only` 無し）— Functions / Hosting / Storage を巻き込む
- ❌ `firebase deploy --only functions` を**このタスクで一緒に**実行（別タスク・別検証が必要）
- ❌ インデックス削除プロンプトを確認せず `--force` で流す
- ❌ feature ブランチの古いルールからデプロイ（必ず本番想定版 = `main` から）

---

## 7. 完了条件（このP0タスクのDONE定義）

- [ ] `firebase deploy --only firestore:rules` 成功（バージョン履歴に反映）
- [ ] `firebase deploy --only firestore:indexes` 成功
- [ ] Console のインデックスが全て **Enabled**
- [ ] シミュレータで自分/他人の vehicles read/write の許可・拒否を確認
- [ ] `CLAUDE_SESSION_NOTES.md` / `HUMAN_TASKS.md` の該当項目にデプロイ日時を記録

> 完了したら次の P0: **#2 Firebase Authentication 本番有効化**（`HUMAN_TASKS.md` 参照）へ。
