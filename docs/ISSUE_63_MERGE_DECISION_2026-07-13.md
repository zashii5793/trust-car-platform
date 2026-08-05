# Issue #63（AIメンテ提案強化）マージ方針メモ — #67 vs #78

**作成日**: 2026-07-13
**目的**: 同一Issue #63 を close 対象とする2本のPR（#67 / #78）が別アプローチで競合しているため、どちらを採るかを判断するための材料と推奨を示す。
**位置づけ**: `docs/OPEN_PR_TRIAGE_2026-07-13.md` の「判断が必要な論点1」の詳細。

---

## 2本の違い

| 観点 | **PR #67**（`claude/night-20260628`） | **PR #78**（`claude/night-20260711`） |
|------|------|------|
| 実装方針 | **新規追加**: `MaintenanceSuggestion` モデル＋`SuggestionUrgency` enum＋`MaintenanceScheduleService.generateSuggestionsForVehicle()` | **既存拡張**: `RecommendationService` に `MaintenanceScheduleService` をオプション注入し、燃料タイプ別フィルタ＋`reason`に「次回目安: Xkm（あとYkm）」を付加 |
| UI | ホームに**専用カード** `_ScheduleSuggestionCard`（緊急度カラーストライプ・要対応/推奨/確認バッジ・残kmチップ） | 既存の通知ベース提案カードを**再利用**し、理由テキストを強化 |
| 緊急度ロジック | 残り≤500km=high / ≤2000km=medium / それ以外=low | 同種（燃料タイプ別インターバルで判定） |
| 後方互換 | 新経路の追加（既存 NotificationProvider 経路と並存） | `const RecommendationService()` のまま動く（フェイルセーフ） |
| テスト | 21件 | 13件 |
| **base** | `6aff94d`（**古い → 要rebase**） | `f9574d2`（**最新main → 即マージ可**） |
| **同梱物** | **Issue #62 タイムライン マイルストーン**（＝#68と重複・競合） | **Issue #41 Phase2 需要蓄積**（`ShopDemandService`＋ルール）＋整備記録**査定価値バナー** |

---

## 論点の整理

1. **UIの厚み**: Issue #63 は「UI改善（理由表示・複数候補）」を求めている。#67 の専用カード（緊急度バッジ・残km）は#78の理由テキスト強化より**プロダクト訴求が強い**。
2. **マージ容易性**: #78 は最新mainベースで**そのままマージ可能**。#67 は古いベースで rebase 必要、かつ**#62部分が #68 と衝突**する（#68 が #62 の正PR）。
3. **アーキテクチャ整合**: #78 は既存 `RecommendationService` に寄せるため**提案系統が1本化**され一貫性が高い。#67 は提案経路が2系統に増える。
4. **付随価値**: #78 は #41 Phase2（需要蓄積）と査定バナーを**独立・追加的に**同梱。#67 の #62 同梱は**重複**でマイナス。

---

## 推奨（Option A）

**#78 を採用して Issue #63 を close、#67 は #63 目的としては superseded 扱いでクローズ。** 加えて:

- [ ] **#78 をマージ**（最新mainベース・#41 Phase2 と査定バナーも同時に入る）→ Issue #63 close
- [ ] **Issue #62 は #68 経由**でマージ（#67 の #62 部分は使わない）
- [ ] **#67 はクローズ**。ただし `_ScheduleSuggestionCard`（緊急度バッジ付きの専用カード）は #78 の理由テキストより UX が良いため、**欲しければ小さな follow-up PR** として `_ScheduleSuggestionCard` のUIだけを #78 の上に移植する（任意）

### なぜ #67 一本化にしないか
- #67 は rebase が必要な上、#62 を巻き込んでおり #68 と衝突する。#41 Phase2（#78同梱）は別途抽出が必要になり、総手数が増える。

### 代替（Option B・非推奨）
#67 を rebase して #62+#63 を一括で入れ、#68 と #78 の#63部分をクローズ。UI は最もリッチになるが、rebase＋#41抽出のコストが高い。UIのリッチさを最優先する場合のみ。

---

## 決定事項（記入用）

- [ ] 採用: ☐ #78（Option A・推奨） / ☐ #67（Option B）
- [ ] `_ScheduleSuggestionCard` の follow-up 移植: ☐ する / ☐ しない
- [ ] クローズするPR: __________

---

_出典: PR #67 / #78 の diff・description、`CLAUDE_SESSION_NOTES.md`（2026-07-11）。_
