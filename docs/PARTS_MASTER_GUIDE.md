# パーツマスタ準備ガイド

「パーツのマスタはどう準備するのか？」への回答ドキュメント。
企画書「信頼を設計する」のコンセプトに沿った、パーツデータの設計・準備・運用方法をまとめる。

---

## 1. 前提：このアプリのパーツのコンセプト

企画書の中核機能②（AIレコメンド）より:

> AIが提携EC（Amazon等）の膨大なパーツから、ユーザーの車と目的に最適なものを
> **論理的に絞り込み**、「なぜこのカスタムが向いているのか」の**理由・メリット・
> デメリット・注意点（車検/安全/コスト）と共に**提示する。

つまりパーツは **B2C / アフィリエイト型のマスタ**である。

- ✅ あるべき姿：運営（または提携EC）が用意した**マスタ**を、AIが適合・目的で絞り込み、理由付きで提示
- ❌ コンセプト外：ユーザー同士の C2C 出品（「マイ出品」タブは本対応で導線から除外済み）

---

## 2. データモデル：`part_listings` コレクション

パーツマスタは Firestore の **`part_listings`** コレクションに格納する
（モデル: `lib/models/part_listing.dart`）。主要フィールド:

| フィールド | 型 | 説明 |
|-----------|----|------|
| `shopId` | string | 提携EC/販売元の ID（`shops` の id） |
| `name` / `nameEn` | string | 商品名 |
| `description` | string | 説明 |
| `category` | string | `PartCategory`（wheel/tire/brake/interior/safety…） |
| `imageUrls` | string[] | 商品画像 |
| `priceFrom` / `priceTo` | int | 価格帯 |
| `compatibleVehicles` | VehicleSpec[] | **適合車種**（後述） |
| `defaultCompatibility` | string | `perfect`/`compatible`/`conditional`/`incompatible` |
| `prosAndCons` | PartProCon[] | **メリット/デメリット**（`{text, isPro}`） |
| `brand` / `partNumber` | string | メーカー・品番 |
| `tags` | string[] | 「ファミリー」「初心者おすすめ」等の目的タグ |
| `rating` / `reviewCount` | num/int | 評価 |
| `isActive` / `isFeatured` | bool | 公開・優先表示 |

### 適合車種 `compatibleVehicles`（VehicleSpec）

```
{ makerId, modelId, yearFrom, yearTo, gradePattern, bodyType }
```

**重要**：`PartRecommendationService` は登録車両の表示名から ID を生成して照合する。

- `makerId` … `トヨタ→toyota`, `ホンダ→honda`, `スバル→subaru` …（`_getMakerId`）
- `modelId` … `makerId + "_" + model.toLowerCase()`（空白`_`・ハイフン`_`）
  - 例：トヨタ RAV4 → `toyota_rav4` ／ スバル WRX S4 → `subaru_wrx_s4`

→ マスタ作成時はこの規則に合わせて `modelId` を入れる。`modelId` を空にすれば
メーカー単位の広い適合（汎用パーツ）になる。

---

## 3. マスタの準備方法（3パターン）

### パターンA：シードスクリプトで投入（推奨・現状の標準）

```bash
cd scripts
npm install firebase-admin

# 1) Emulator で確認
firebase emulators:start --only firestore
node scripts/seed_parts_master.js --emulator --dry-run   # 中身を確認
node scripts/seed_parts_master.js --emulator             # 投入

# 2) 本番（要確認・本番反映）
export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
node scripts/seed_parts_master.js
```

`scripts/seed_parts_master.js` の `parts` 配列に商品を追記すれば増やせる。
ペルソナ車両（RAV4 / WRX / N-BOX / ハイエース）に適合するデモが既に入っている。

### パターンB：CSV → インポート（車種マスタと同方式・将来拡張）

車種マスタ（`data/vehicle_masters.csv` → `scripts/import_vehicle_master.dart`）と
同じ運用にしたい場合、`data/parts_master.csv` を作り、インポータを用意する。
列例：

```
name, category, brand, partNumber, priceFrom, priceTo, makerId, modelId, yearFrom, yearTo, tags, imageUrl
```

メリット：非エンジニアが表計算で編集できる。CI で投入を自動化しやすい。
（インポータは未実装。必要になったら `import_vehicle_master.dart` を雛形に作成）

### パターンC：提携EC API 連携（本格運用フェーズ）

Phase 3（エコシステム完成）では、提携EC（Amazon PA-API 等）から商品・価格・
在庫を定期取得し、`part_listings` を自動更新する Cloud Functions を用意する。
`affiliateUrl`（送客リンク）を付与し、購入成果でアフィリエイト報酬を得る
（企画書 B2B 収益モデル）。

---

## 4. メリット/デメリットの生成方針

`prosAndCons` は「判断材料を整える」ための最重要データ。

1. **手動キュレーション（当面の推奨）**：運営が車検適合・安全・コスト・取付難易度の
   観点で 2〜4 件ずつ記述。信頼性が最も高い。
2. **LLM 補助生成**：商品仕様から下書きを LLM で生成 → 人がレビュー。
   `recommendation_service` / `askCarAi` のプロンプト方針（推奨度・メリデメ・注意点を
   構造化）と整合させる。
3. 安全・法令（保安基準/車検）に関わる注意は **必ず** `con` として明記する。

---

## 5. セキュリティルール

`part_listings` は読み取り公開・書き込みは運営/提携ショップのみ。
新規コレクションを足す場合は `firestore.rules` を必ず同時更新すること
（CLAUDE.md セキュリティ方針）。現行ルールの `part_listings` 定義を確認のうえ、
`affiliateUrl` 等のフィールド追加時もルール側の検証を見直す。

---

## 6. TODO（フォローアップ）

- [ ] `PartListing` モデルに `affiliateUrl`（提携EC送客リンク）フィールドを追加し、
      パーツ詳細に「ECで見る/購入する」CTA を実装（シードには既にデータを格納済み）。
- [ ] `data/parts_master.csv` + インポータ（パターンB）の整備。
- [ ] 提携EC API 連携（パターンC）の PoC。
- [ ] `prosAndCons` の LLM 下書き生成パイプライン。
- [ ] デモ用 `shopId: partner_ec_demo` を実在の提携先へ差し替え。
