# TrustCar 保守・運用ランブック

> 最終更新: 2026-03-25

---

## 1. インシデント重大度と対応 SLA

| 重大度 | 定義 | 対応開始 | 解決目標 |
|--------|------|---------|---------|
| **P0 — 致命的** | 全ユーザーへのサービス不能、データ消失リスク | 即時（24h対応） | 4時間以内 |
| **P1 — 重大** | 主要機能（認証・車両登録）の障害、セキュリティ脆弱性 | 2時間以内 | 24時間以内 |
| **P2 — 中程度** | 一部機能の不具合、パフォーマンス劣化 | 翌営業日 | 72時間以内 |
| **P3 — 軽微** | UI崩れ、文言ミス、軽微な挙動の差異 | 次リリースサイクル | 2週間以内 |

---

## 2. Crashlytics によるリアルタイム監視

### 監視ダッシュボード

```
Firebase Console → プロジェクト「trust-car-platform」
  ├── Crashlytics → クラッシュフリーユーザー率（目標: ≥ 99.5%）
  ├── Analytics → アクティブユーザー数 / リテンション
  └── Firestore → 読み取り/書き込みオペレーション数
```

### アラートしきい値（Firebase Alerts で設定）

| 指標 | 警告ライン | 緊急ライン |
|------|-----------|-----------|
| クラッシュフリー率 | < 99.5% | < 99.0% |
| Firestoreエラー率 | > 1% | > 5% |
| Auth失敗率 | > 5% | > 15% |

### Crashlytics の実装状況

```dart
// lib/main.dart — リリースビルドのみ有効
await crashlytics.initialize(enabled: !kDebugMode);
FlutterError.onError = crashlytics.flutterErrorHandler;
PlatformDispatcher.instance.onError = (error, stack) {
  crashlytics.recordError(error, stack, fatal: true);
  return true;
};
```

---

## 3. ホットフィックス手順（P0/P1 対応）

### ステップ 1: 障害確認

```bash
# Crashlytics でスタックトレースを確認
# Firebase Console → Crashlytics → 最新イシュー

# git log で直近の変更を確認
git log main --oneline -10
```

### ステップ 2: ホットフィックスブランチ作成

```bash
git checkout main
git pull origin main
git checkout -b hotfix/P0-<短い説明>-$(date +%Y%m%d)
# 例: hotfix/P0-auth-crash-20260325
```

### ステップ 3: 修正 → テスト

```bash
# 修正後、関連テストのみ実行（CI待ち時間短縮）
flutter test test/services/auth_service_test.dart
flutter test test/providers/auth_provider_test.dart

# 静的解析
flutter analyze
```

### ステップ 4: PR → マージ → リリース

```bash
# PR 作成（main へ直接）
gh pr create \
  --title "hotfix: <短い説明>" \
  --body "## 緊急修正\n- 問題: <Crashlytics URL>\n- 修正内容: <説明>\n- テスト確認: ✅" \
  --base main \
  --label "hotfix,P0"

# マージ後、バージョンタグを打つ
git tag v1.0.1-hotfix
git push origin v1.0.1-hotfix
```

### ステップ 5: ストア緊急リリース

**Android (Google Play)**
```
Google Play Console → アプリ → リリース → 本番
→ 「緊急公開」オプションを使用（通常審査24hが数時間に短縮）
```

**iOS (App Store)**
```
App Store Connect → アプリ → バージョン → 「Expedited Review」申請
→ "Developer/User Safety" 理由でリクエスト（通常数時間で対応）
```

---

## 4. 定期保守タスク

### 週次

- [ ] Crashlyticsダッシュボード確認（クラッシュフリー率 ≥ 99.5%）
- [ ] Firebase Firestore 使用量確認（Spark Plan 上限に注意）
- [ ] P2/P3 バグリストのトリアージ

### 月次

- [ ] Flutter SDK + 依存パッケージのアップデート確認
  ```bash
  flutter pub outdated
  flutter pub upgrade --dry-run
  ```
- [ ] Firestore セキュリティルールの見直し
- [ ] 不活性ユーザーへのデータ保持ポリシー確認（退会後30日ルール）

### リリース毎

- [ ] `flutter test --coverage` でカバレッジ確認（目標: 80%以上）
- [ ] `flutter analyze` クリーン確認
- [ ] Firestore indexes 最新化: `firebase deploy --only firestore:indexes`
- [ ] セキュリティルール適用: `firebase deploy --only firestore:rules`

---

## 5. データバックアップ・リストア

### Firestore バックアップ（月次推奨）

```bash
# Google Cloud コンソール → Firestore → エクスポート
# または gcloud CLI:
gcloud firestore export gs://trust-car-platform-backup/$(date +%Y%m%d) \
  --project=trust-car-platform
```

### リストア手順（緊急時）

```bash
# 特定コレクションのみリストア
gcloud firestore import gs://trust-car-platform-backup/20260301 \
  --collection-ids=vehicles,maintenance_records \
  --project=trust-car-platform
```

### データ保持ポリシー（プライバシーポリシー準拠）

| データ種別 | 保持期間 | 削除方法 |
|-----------|---------|---------|
| 退会ユーザーデータ | 退会後30日 | Firebase Functions scheduled job |
| バックアップデータ | 最大90日 | GCS ライフサイクルポリシー |
| Crashlyticsログ | 90日（Firebase自動） | 自動 |
| Analyticsデータ | 14ヶ月（Firebase自動） | 自動 |

---

## 6. パフォーマンス監視

### Firestoreクエリ監視

```dart
// 遅いクエリの検出（開発中）
// Firebase Console → Firestore → 使用状況 → 遅いクエリ
```

### フォールバック目標値

| 指標 | 目標値 |
|------|--------|
| 冷起動時間 | < 3秒 |
| 画面遷移 | < 500ms |
| Firestore読み込み | < 1秒 |
| 画像読み込み（Firebase Storage） | < 2秒 |

---

## 7. Firebase Plan アップグレード判断基準

現在: **Spark Plan（無料）**

### Blaze Plan（従量課金）に移行するタイミング

| 指標 | Spark 上限 | 移行検討ライン |
|------|-----------|--------------|
| Firestore 読み取り | 50K/日 | 35K/日超 |
| Firestore 書き込み | 20K/日 | 14K/日超 |
| Cloud Storage | 1GB | 700MB超 |
| Auth アクティブユーザー | 10K/月 | 7K/月超 |

---

## 8. セキュリティインシデント対応

### 不正アクセス検知時

1. **即座に**該当アカウントを無効化
   ```
   Firebase Console → Authentication → ユーザー → 無効化
   ```
2. Firestoreのセキュリティルールを確認・強化
3. 影響範囲のユーザーへ通知（プライバシーポリシー第10条に基づく）
4. インシデントレポート作成（`docs/incidents/YYYYMMDD.md`）

### セキュリティルール緊急パッチ

```bash
# ルール修正後即座にデプロイ（ビルド不要）
firebase deploy --only firestore:rules
# 反映: 数秒以内
```

---

## 9. よくある障害と対処法

### `google-services.json` / `GoogleService-Info.plist` が古い

**症状**: Androidでクラッシュ、`FirebaseApp name [DEFAULT] already exists` エラー
**対処**: Firebase Console から最新ファイルをダウンロードして再配置

### Firestoreインデックス未作成

**症状**: `The query requires an index. You can create it here: https://...`
**対処**:
```bash
# エラーに含まれるURLにアクセスしてインデックス作成、またはCLIで追加
firebase deploy --only firestore:indexes
```

### Push通知が届かない

**症状**: FCMトークン取得失敗
**対処**:
1. `google-services.json` の `firebase_messaging_sender_id` を確認
2. Firebase Console → Cloud Messaging → サービスアカウント確認

---

## 10. 連絡先・エスカレーション

| 役割 | 対応範囲 |
|------|---------|
| 開発者（あなた） | P0/P1 修正、ストア申請 |
| Firebase サポート | Firebase基盤障害 → console.firebase.google.com/support |
| Google Play サポート | ストア審査問題 → support.google.com/googleplay/android-developer |
| App Store サポート | 審査問題 → developer.apple.com/contact |
