# ローンチReadiness チェックリスト（データ層）

**目的**: ローンチ前に「Firestoreルール／インデックスの本番反映」を安全に完了させるための、検証済みチェックリスト。
**対象読者**: `firebase deploy` を実行するプロジェクトオーナー（人間）。
**前提**: AIが実装・自動検証を完了済み。本ドキュメントは「何が未反映で、何を確認済みか」を引き渡すためのもの。

> 関連: 全体の人手タスクは `docs/HUMAN_TASKS.md`、運用・コストは `docs/MAINTENANCE_RUNBOOK.md` を参照。

---

## TL;DR

- 🔴 **ローンチブロッカー**: `firestore.rules` / `firestore.indexes.json` が**本番未デプロイ**。反映しないと一部機能が全ユーザーでエラーになる。
- ✅ **AI検証済み**: ルールはコンパイル成功・ルールテスト 35件全パス。インデックスは構造的に妥当（42件）。申告された未反映項目はすべてファイルに存在。
- ⏳ **残作業（人間）**: `firebase deploy --only firestore:rules,firestore:indexes`（要オーナー権限）。

---

## 1. AI自動検証の結果（このブランチ時点）

| 検証項目 | 方法 | 結果 |
|----------|------|------|
| ルールのコンパイル | `test/rules` の Emulator テスト（`firebase emulators:exec`） | ✅ コンパイル成功（構文・予約語エラーなし） |
| ルールの挙動 | `@firebase/rules-unit-testing` + Jest | ✅ **35件 / 35件パス**（2スイート） |
| インデックスの構造 | JSONパース（コメント除去後） | ✅ 妥当（42インデックス / 16コレクション） |
| 未反映ルールの存在 | `firestore.rules` 内 `match` 照合 | ✅ 6コレクションすべて定義済み |
| 未反映インデックスの存在 | `firestore.indexes.json` 照合 | ✅ 申告項目すべて存在 |

再現コマンド:

```bash
# ルールテスト（Java 21+ 必須）
cd test/rules && npm install && npm test
# → Test Suites: 2 passed, Tests: 35 passed
```

---

## 2. 未デプロイ項目の内訳（本番反映が必要）

### 2-1. セキュリティルール（`firestore.rules`）

以下のコレクションのルールは追加済みだが**本番未反映**。反映しないと該当機能の読み書きがルールで弾かれる。

| コレクション | 影響（未反映時） |
|--------------|------------------|
| `community_maintenance_trends` | 車両詳細の「コミュニティの傾向」が読めない |
| `safety_tips` | 安全運転情報が表示されない |
| `accessory_showcases/{id}/comments`（サブコレクション） | ショーケースのコメント投稿・いいねが全て弾かれる |
| `fleet_members` | フリートメンバー管理が機能しない |
| `car_purchase_inquiries` | 車両買取問い合わせが弾かれる |
| `shop_chains` | チェーン店データにアクセスできない |

### 2-2. 複合インデックス（`firestore.indexes.json`）

| コレクション | インデックス | 影響（未反映時） |
|--------------|--------------|------------------|
| `inquiries` | `shopId + createdAt`（ASC） | 工場ダッシュボードの月次レポート（ROI可視化 #39）がクエリエラー |
| `safety_tips` | `isActive + publishedAt` / `isActive + category + publishedAt` | 安全情報の一覧クエリがエラー |

> インデックス総数: 42件 / 16コレクション。上記以外は既存反映済みの想定（本番のインデックス状態は Firebase Console で要確認）。

---

## 3. デプロイ手順（人間が実施）

> ⚠️ AIは `firebase login`（オーナー認証）ができないため、ここから先は人間タスク。

```bash
# 0. 前提: firebase login 済み・プロジェクトオーナー権限
firebase login

# 1. 最新の rules / indexes を取得
git pull

# 2. ドライラン（差分とコンパイル確認）
firebase deploy --only firestore:rules --dry-run

# 3. ルールテストをローカルで再確認（任意・推奨）
cd test/rules && npm test   # → 35 passed

# 4. 本番反映
firebase deploy --only firestore:rules,firestore:indexes

# 5. 反映確認
#    Firebase Console → Firestore → ルール → バージョン履歴で反映時刻を確認
#    インデックスは「構築中 → 有効」になるまで数分かかる場合あり
```

### チェックリスト

- [ ] `firebase login` 済み（オーナー権限）
- [ ] `git pull` で最新の `firestore.rules` / `firestore.indexes.json` 取得
- [ ] `firebase deploy --only firestore:rules --dry-run` でコンパイル確認
- [ ] `cd test/rules && npm test` が緑（35 passed）
- [ ] `firebase deploy --only firestore:rules,firestore:indexes` 実行
- [ ] Firebase Console でルールのバージョン履歴・反映時刻を確認
- [ ] インデックスが全件「有効」になったことを確認（構築完了まで待つ）
- [ ] 主要動作確認: コメント投稿 / 工場月次レポート / 安全情報表示

---

## 4. 既知の注意点

- **`firestore.indexes.json` はJSONC形式**（`//` コメントを含む）。Firebase CLI は `cjson` で許容するが、
  標準の `JSON.parse` やエディタ／CIのJSON Lintは構文エラー扱いにする。CIにJSON Lintを追加する際は
  コメントを許容する設定にすること（または将来コメントを除去する）。
- **インデックス構築には時間がかかる**: デプロイ直後はクエリがまだエラーになることがある。Console で
  「有効」を確認してから動作確認すること。
- **ロールバック**: ルールは Firebase Console のバージョン履歴から前バージョンへ戻せる。インデックスの
  削除は手動。万一に備え、デプロイ前の `firestore.rules` を控えておく。

---

*このドキュメントは Phase 1（ローンチブロッカー検証）の成果物。検証は AI が自動実行し、本番反映のみ人間タスクとして残す。*
