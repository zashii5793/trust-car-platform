# 夜間エージェント 朝次レポート — 2026-06-25

## 完了タスク（3件）

### 1. Weekly PM Report CI バグ修正 ✅
**コミット**: `130284a`  
**問題**: `pm_report.yml` が 2026-06-22 以降 3日間 `$GITHUB_OUTPUT に無効フォーマット '0'` エラーで失敗。  
**根本原因**: `grep -c` はマッチ 0 件でも `"0"` を stdout 出力し exit 1 → `|| echo "0"` で二重出力 → `$GITHUB_OUTPUT` に `"key=0\n0"` の 2 行が書かれ、2 行目 `"0"` が無効フォーマットでワークフロー停止。  
**修正**: 全 `grep -c ... || echo "0"` を `grep -c ...) || VARNAME=0` パターンに統一（3 箇所）。  
さらに非 GNU 環境での `grep -oP`（Perl 正規表現）を `grep -Eo` + `tr` に差し替え（移植性向上）。  

### 2. ShopService Haversine を dart:math 版に置換 ✅
**コミット**: `67534d9`  
**問題**: `ShopService._calculateDistance` が手書き Taylor 級数近似（sin/cos/sqrt/atan2 各 ~10 行、計 67 行）で精度・保守性が低い。  
**修正**: `dart:math` の `sin/cos/sqrt/atan2/pi` を使う標準 Haversine に置換（15 行に短縮）。  
`flutter analyze lib/`: No issues / 全テスト通過。

### 3. getUserPosts ページネーション + 可視性フィルタ統合テスト ✅
**コミット**: `74f402b`  
**問題**: `PostService.getUserPosts` は `DocumentSnapshot? startAfter` によるカーソルページネーションを実装済みだが、テストが 0 件だった。  
**追加テスト（7件）**:
- `limit=3` で最初の 3 件（新しい順）を返す
- `startAfter` で 2 ページ目を取得できる
- 最終ページの次は空リストを返す
- 非フォロワーフィルタ × ページ 1（public のみ 2 件）
- 非フォロワーフィルタ × ページ 2（public 残り 1 件）
- フォロワーフィルタ × ページ 1（public+followers 3 件）
- フォロワーフィルタ × ページ 2（public+followers 残り 2 件）

**副次バグ修正**: `fake_cloud_firestore 4.1.1` の `startAfterDocument` はリミット済み結果セットに対して動作するため、`post_service.dart` のクエリチェーン順を `orderBy → startAfterDocument → limit` に変更（実 Firestore では意味的に等価）。

---

## テスト・品質状況

| 指標 | 結果 |
|------|------|
| `flutter test --exclude-tags emulator` | +3000 件超 全パス ✅ |
| `flutter analyze lib/` | No issues ✅ |
| 今夜追加テスト | +7 件 |

---

## ブランチ情報

- **ブランチ**: `claude/night-20260625`
- **コミット数**: 3件（130284a → 67534d9 → 74f402b）
- **ベース**: `main` (030ac77 以降)

---

## 人間向けアクションアイテム

1. **PR レビュー**: PR を確認してマージしてください（draft で作成済み）。
2. **Weekly PM Report の再実行確認**: 次回月曜（2026-06-29）の自動実行で CI が通ることを確認するか、`workflow_dispatch` で手動実行してください。
3. 特段のブロッカーなし。`docs/HUMAN_TASKS.md` の未チェック項目は変わらず（Firebase deploy 系）。

---

*生成: 夜間自律エージェント / 2026-06-25*
