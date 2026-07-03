# Morning Briefing — 2026-07-03

**Branch**: `claude/night-20260703`  
**PR**: [#71 feat: SocialNotification に showcaseId 追加 + SNS 通知画面のディープリンク対応](https://github.com/zashii5793/trust-car-platform/pull/71)

---

## 完了した作業

### Issue #37 部分対応: 通知フィード→ショーケースのディープリンクUI

#### 根本バグの修正
`PopularAccessoriesService._notify()` は Firestore `social_notifications` コレクションに `showcaseId` を正しく書き込んでいたが、`SocialNotification.fromFirestore()` がそのフィールドを読み取らず、ショーケースへの参照が通知受信時に消失していた。

#### 変更ファイル (10ファイル)

| ファイル | 内容 |
|---------|------|
| `lib/models/follow.dart` | `SocialNotification` に `showcaseId` フィールド追加、`message` ゲッターでショーケース向けテキスト分岐 |
| `lib/services/follow_service.dart` | `createNotification()` に `showcaseId` パラメータ追加 |
| `lib/services/popular_accessories_service.dart` | `getShowcaseById(String id)` メソッド追加 |
| `lib/providers/social_notification_provider.dart` | **新規** SNS通知プロバイダー（読み込み・既読・全既読） |
| `lib/screens/sns/social_notification_screen.dart` | **新規** SNS通知一覧画面（ショーケースへのディープリンク付き） |
| `lib/screens/home_screen.dart` | SNS タブの AppBar に通知ベルアイコン追加 |
| `lib/main.dart` | `SocialNotificationProvider` を `MultiProvider` に登録 |
| `test/services/follow_service_test.dart` | `showcaseId` 関連テスト 10件追加 (TDD RED→GREEN) |
| `test/screens/home_screen_test.dart` | テスト用プロバイダーに `SocialNotificationProvider` 追加 |
| `test/integration/user_journey_widget_test.dart` | 同上 |

#### テスト結果（ローカル）
- `flutter analyze lib/` → **No issues found**
- `flutter test --exclude-tags emulator` → **全件 GREEN (Exit 0)**

---

## PR #71 CI 状況

- **初回 CI**: `dart format` で 5ファイルが未フォーマット → 失敗
- **修正コミット** `b05f65f` でフォーマット適用・プッシュ済み
- CI 再実行中（結果待ち）

---

## 残作業 (Issue #37 未対応分)

Issue #37 は「showcaseId は保存済み。SocialNotification モデル＋通知一覧画面の遷移対応が必要」という内容だったが、今回で **モデル修正** と **通知一覧画面＋ナビゲーション** まで完成。

残っている可能性がある作業:
- `PostDetailScreen` へのディープリンク（`postId` 通知）— 現在は `showcaseId` のみ対応
- E2E / エミュレーターテストでの実機確認
- Issue #37 のクローズ（PR #71 マージ後）

---

## 前夜の PR 状況

| PR | タイトル | CI | 状態 |
|----|---------|-----|------|
| #70 | (昨夜の作業) | GREEN (8/8) | Ready for Review |
| #71 | 今夜の作業 | 再実行中 | Draft |

---

## 推奨次アクション

1. **PR #71 の CI グリーンを確認** → Ready for Review に昇格
2. **Issue #37 の残項目確認** → `postId` 通知のディープリンク対応が必要か判断
3. **PR #70 のレビュー・マージ** → CI GREEN 済みのためレビュー可能
