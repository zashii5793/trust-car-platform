# スキーマ進化・データマイグレーション戦略（設計案 / 合意待ち）

**ステータス**: 🟡 提案（Agree レベル / 実装前に合意が必要）
**対象**: バージョンアップ時に Firestore のドキュメント構造を安全に進化させる仕組み
**背景**: 現状、全 32 モデルに `schemaVersion` が無く、フィールドの追加・改名・型変更を伴う
アップデートで「旧バージョンのアプリが書いた古いドキュメント」を新アプリが読むと、
パース失敗やデフォルト値での上書きによるデータ破損が起こりうる。

> この文書は「設計の合意」を取るためのもの。承認後に最小スカフォールドから段階実装する。

---

## 1. 解決したい問題

Firestore はスキーマレスなので、アプリのモデルを変えても古いドキュメントはそのまま残る。
典型的な事故:

1. **フィールド改名**: `name` → `title` に変えると、旧ドキュメントの `name` は読めず空になる。
2. **型変更**: `cost`（int）→ `cost`（{amount, currency}）にすると `fromFirestore` がクラッシュ。
3. **必須化**: 後から必須にしたフィールドが旧ドキュメントに無く、業務ロジックが破綻。
4. **意図しない上書き**: 新アプリが「無い前提」で書き戻すと、旧フィールドが消える。

現状の `fromFirestore` は `data['x'] ?? デフォルト` で**寛容にフォールバック**しているため
即クラッシュはしにくいが、これは「壊れていないように見えて静かにデータが欠落する」状態で、
むしろ検知が遅れるリスクがある。

---

## 2. 提案する方式：Lazy Migration on Read + `schemaVersion`

### 2-1. 基本方針
- 全永続化モデルに **`int schemaVersion`**（デフォルト `1`）フィールドを持たせる。
- **読み込み時（`fromFirestore`）に**、ドキュメントの `schemaVersion` が現行未満なら
  メモリ上で順次アップグレードしてからモデル化する（= Lazy Migration）。
- **書き込み時**は常に現行 `schemaVersion` で書く（次回以降の読み込みは移行不要になる）。
- 一括で揃えたい場合のみ、後追いで **backfill スクリプト**（既存 `scripts/seed_*.js` と同系統）
  を流して全ドキュメントを最新版に書き直す。

### 2-2. なぜ Lazy か（代替案との比較）

| 方式 | 概要 | 長所 | 短所 | 採否 |
|------|------|------|------|------|
| **Lazy on read（提案）** | 読むときに変換 | 一括ジョブ不要・段階的・ダウンタイムなし | 変換コードを当面保持 | ✅ 採用 |
| Eager（Cloud Function トリガ） | 書込/デプロイ時に全件変換 | 常に最新形 | 大量ドキュメントで時間・コスト大、失敗時のリカバリ複雑、Functions 運用必須 | ❌ 現規模では過剰 |
| Versioned collections | `posts_v2` のように別コレクション | 完全分離 | クエリ/ルール/インデックスを二重管理、移行が重い | ❌ 不採用 |

現在の規模（Spark〜初期 Blaze、数百〜数千ユーザー想定。§MAINTENANCE_RUNBOOK §7）では
Lazy が最もコスト・複雑性・安全性のバランスが良い。

---

## 3. 具体的な実装イメージ（スカフォールド）

> 実コードは合意後に書く。ここは設計の確認用。

### 3-1. マイグレーション・レジストリ
モデルごとに「version N → N+1 の変換関数」を登録する純粋関数の連鎖。

```dart
// lib/core/migration/document_migrator.dart（新規予定）
typedef MigrationStep = Map<String, dynamic> Function(Map<String, dynamic> data);

class DocumentMigrator {
  /// version をキーに「その版から次の版へ」の変換を並べる
  final Map<int, MigrationStep> _steps;
  final int currentVersion;

  const DocumentMigrator(this._steps, {required this.currentVersion});

  /// 旧 data を currentVersion まで順に引き上げる（純粋・冪等）
  Map<String, dynamic> migrate(Map<String, dynamic> data) {
    var v = (data['schemaVersion'] as int?) ?? 1;
    var out = data;
    while (v < currentVersion) {
      final step = _steps[v];
      if (step == null) break; // 連続性が無ければ停止（要テストで担保）
      out = step(out);
      v++;
    }
    out['schemaVersion'] = currentVersion;
    return out;
  }
}
```

### 3-2. モデル側の利用（例：Vehicle）

```dart
class Vehicle {
  static const schemaVersion = 1; // 変更のたびに +1

  static final _migrator = DocumentMigrator({
    // 1 → 2 の例: licensePlate を構造化
    // 1: (d) => {...d, 'plate': {'raw': d['licensePlate']}}..remove('licensePlate'),
  }, currentVersion: schemaVersion);

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;
    final data = _migrator.migrate(raw); // ← ここで Lazy 変換
    return Vehicle.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() => {
        ...,
        'schemaVersion': schemaVersion, // ← 書込は常に現行
      };
}
```

ポイント:
- `fromMap` は「常に最新スキーマ」だけを知っていればよい（過去形は変換関数に隔離）。
- 変換関数は**純粋・冪等**にし、ユニットテストで `v1→現行` を表データで検証する。

---

## 4. 段階的ロールアウト計画（合意後）

1. **Step 0（土台）**: `DocumentMigrator` + テストを追加。挙動を変えない（currentVersion=1）。
2. **Step 1（高頻度モデル先行）**: 変更が多い `Vehicle` / `MaintenanceRecord` / `Post` に
   `schemaVersion` と `fromFirestore` の経路を導入（変換は空＝現状維持）。
3. **Step 2（実マイグレーション初適用）**: 次にスキーマ変更が必要になった時、
   そのモデルに `1→2` の変換関数を1つ追加してパターンを確立。
4. **Step 3（横展開）**: 残りモデルへ順次適用。新規モデルは最初から `schemaVersion` を持つ規約に。
5. **任意**: 古い版が十分に減ったら backfill スクリプトで一括書き直し、変換関数を撤去。

各 Step は独立した小さい PR にする。

---

## 5. テスト方針（TDD）
- `document_migrator_test.dart`: 連鎖変換・冪等性・未知バージョン・欠損 `schemaVersion`（=1扱い）。
- 各モデルの `fromFirestore`: 「旧版 data を渡すと最新形のモデルになる」表駆動テスト。
- 既存テストの **回帰**: `schemaVersion` 追加で `toMap`/`fromMap` の往復テストが壊れないこと。

---

## 6. リスク・コスト
- `fromFirestore` を `implements`/モックしているテストスタブ（多数）への影響に注意
  （Phase 2 で判明した課題と同種。インターフェース非変更で導入できる設計にする）。
- 変換関数の保持コスト（小）。古い版が消えたら撤去できる。
- backfill 実行時の書き込みコスト（任意・後追いのため制御可能）。

---

## 7. 合意したい論点（要・人間判断）

1. **この Lazy 方式で進めてよいか**（Eager / versioned collections は不採用でよいか）。
2. **`schemaVersion` フィールド名**でよいか（`_sv` など短縮や予約名の希望はあるか）。
3. **先行3モデル**（Vehicle / MaintenanceRecord / Post）の選定でよいか。
4. **ローンチ前に Step 0–1 まで入れるか**、ローンチ後に回すか
   （推奨: スキーマ変更が無い限り挙動を変えない Step 0–1 はローンチ前に入れても低リスク。
   ただし優先度はブロッカー解消＜本項目なので、ローンチ後でも可）。

> 上記に合意（または修正指示）をもらえれば、Step 0 のスカフォールドから実装に着手する。
