# 作業ログ 2026-08-05 — faq-platform 残タスク棚卸し

> 承認前のため Drive `02_プロジェクト管理/faq-platform/_log/` には未配置。承認後に移送する。

## 依頼

- 案件: faq-platform（FAQプラットフォーム — 製品化とタカヤ導入）
- 宛先: 開発（app-developer）
- 内容: 残タスク（本番Embedding・監査ログ・課金基盤）の棚卸し

## 実施

| 時系列 | 作業 | 結果 |
|---|---|---|
| 1 | Drive フォルダ構造の確認 | 指定URL `1XC-No...` は `02_プロジェクト管理` 本体。配下は `trust-car-platform` / `FAQ_Platform_v2` の2フォルダ。**`faq-platform` フォルダは未作成**（成果物の宛先。承認後に作成が要る） |
| 2 | `zashii5793/faq_platform` を clone | `5d65815`（shallow / 読み取り専用） |
| 3 | `ROADMAP.md` `CHANGELOG.md` 読解 | Phase 1〜3 の構成と完了基準を把握 |
| 4 | 本番Embedding の実装状況を実測 | `app/rag.py` に2バックエンド実装済み。`app/config.py:47` のデフォルトが `"tfidf"` |
| 5 | 監査ログの実装状況を実測 | `app/audit.py`（73行）+ `/api/admin/export`。IP・tenant・読み取り系ログが欠落 |
| 6 | 課金基盤の実装状況を実測 | `grep -rniE "billing\|stripe\|subscription\|plan\|quota" app/` → **0件**。設計書のみ |
| 7 | ベンチマーク結果の読解 | `docs/benchmark_search_results.txt`：top1正解 71%、NO_ANSWER誤発動 6件 |
| 8 | 棚卸し文書を作成 | `projects/faq-platform/REMAINING_TASKS_INVENTORY.md` |

## 主な発見

1. **ROADMAP の現状記述が古い。** Task 1.1 は「HashEmbedding（ランダムに近い精度）」と書かれているが、実際には TF-IDF と sentence-transformers 系の2バックエンドが実装済みで、環境変数で切替可能。
2. **監査ログは「未着手」ではなく約8割完成。** CSV/JSONエクスポートまで動いている。欠けているのは IP記録・tenant項目・読み取り系エンドポイントのログ・専用テスト。
3. **課金基盤だけが真に未着手。** しかも設計書の価格が `〇〇`/`△△`/`□□` のプレースホルダで、**経営判断が開発の手前でブロックしている**。
4. **ROADMAP は Phase 3（課金）を「2社目契約のタイミング」と定義し、Phase 1 を飛ばすことを禁止事項に挙げている。** 1社目導入中の課金着手は方針との矛盾になるため、進めるなら方針変更としての合意が要る。

## 未解決 / 要確認

| # | 事項 | 影響 |
|---|---|---|
| A | **「タカヤ」がリポジトリ上のどのテナントに対応するか不明。** リポジトリは `tenants/a_company` /「デモ会社」/「導入企業（教育業界）」の匿名表記 | 作業割り当ての前提。**最優先で確認が要る** |
| B | 導入先サーバーの環境（OS/メモリ/ディスク/オフラインか） | Embedding切替の可否を決める |
| C | マルチテナント化 or 独立インスタンス配布 | 監査ログの tenant 項目の要否を決める |

## 調査の限界

- **GitHub Issue / PR を参照できていない。** `zashii5793/faq_platform` はセッションに読み取り専用で接続されており、Issues API はスコープ外（"repository not configured for this session"）。既存Issueとの重複は未確認。
- **テスト未実行。** Python環境を立てていない。CHANGELOG 記載の「375 passed, 2 xfailed」は文書上の値。
- 工数目安は実測ではなくコード規模からの見積り。
- Drive `05_AI活用` の「AI支援開発_実践ガイド_用語解説付き」は参照を試みたが、本ログ作成時点で読み取りが完了していない。方法論の材料であり、本棚卸しの事実認定には影響しない。

## 成果物

- `projects/faq-platform/REMAINING_TASKS_INVENTORY.md`（**下書き・未承認**）

## 次の判断待ち

承認後に Drive `02_プロジェクト管理/faq-platform/` へ配置。フォルダは未作成のため、作成から必要。
