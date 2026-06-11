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

## 7. Firebase Plan アップグレード計画（Spark → Blaze）

現在: **Spark Plan（無料）**

### このアプリの特性（実測ベース）

| 特性 | 数値 | 根拠 |
|------|------|------|
| ユーザー1人あたりの1日の読み取り数 | 約 50〜75 回 | 画面遷移 × get() 108箇所、リスト表示×snapshots() 10箇所 |
| ユーザー1人あたりの1日の書き込み数 | 約 8〜15 回 | 整備記録・投稿・いいね・問い合わせ |
| 1ユーザーあたりのStorage使用量 | 約 2〜5 MB | 写真 × 5枚 × 100〜500KB（圧縮後） |
| リアルタイム接続数 | 3〜4 / 人 | ホーム・SNSフィード・問い合わせ・通知 |

---

### Spark Plan の無料枠と「危険ライン」

| リソース | Spark 上限 | 警告ライン（70%） | 危険ライン（90%） |
|---------|-----------|-----------------|-----------------|
| Firestore 読み取り | 50,000 / 日 | 35,000 | 45,000 |
| Firestore 書き込み | 20,000 / 日 | 14,000 | 18,000 |
| Firestore 削除 | 20,000 / 日 | 14,000 | 18,000 |
| Cloud Storage | 1 GB 総量 | 700 MB | 900 MB |
| Storage 転送量 | 10 GB / 日 | 7 GB | 9 GB |
| Firebase Auth MAU | 無制限（email/pass） | — | — |

---

### ユーザー規模と Spark 枯渇の目安

> 計算式: `Spark上限 ÷ 1ユーザーの1日の使用量 = 上限DAU`
> DAU/MAU比率 = **15%**（SNSアプリ標準値）で換算

#### Firestore 読み取り（悲観シナリオ: 75 reads/DAU/日）

```
50,000 reads/日 ÷ 75 reads/DAU = 666 DAU が上限
666 DAU ÷ 0.15 (DAU/MAU) = 約 4,400 MAU で枠超え
```

#### Firestore 読み取り（楽観シナリオ: 30 reads/DAU/日）

```
50,000 ÷ 30 = 1,666 DAU が上限
1,666 ÷ 0.15 = 約 11,000 MAU で枠超え
```

#### Cloud Storage（写真投稿ユーザーが50%の場合）

```
1 GB ÷ 3 MB（平均）÷ 0.5（投稿率）= 約 667 ユーザーで容量枯渇
```

**→ 結論: Storage は早期にボトルネックになる。登録ユーザー 300〜500 人を目安に Blaze へ移行を検討。**

---

### Blaze Plan の推定コスト

| MAU | DAU（15%） | Firestore読み取り/月 | Firestore書き込み/月 | Storage | **月額合計（概算）** |
|-----|-----------|-------------------|-------------------|---------|----------------|
| 500 | 75 | 168K | 34K | 1.5 GB | **$0.30** |
| 1,000 | 150 | 338K | 68K | 3 GB | **$0.57** |
| 5,000 | 750 | 1.69M | 338K | 15 GB | **$2.80** |
| 10,000 | 1,500 | 3.38M | 675K | 30 GB | **$5.50** |
| 50,000 | 7,500 | 16.9M | 3.38M | 150 GB | **$26** |

> Blaze 料金（2026年時点）: Firestore 読み取り $0.06/100K、書き込み $0.18/100K、Storage $0.026/GB/月。無料枠（Spark相当）を差し引いた後の額。

**→ 5万MAUでも月$26。規模に対してコストは非常に低い。**

---

### 移行タイミングの判断フロー

```
週次モニタリング（Firebase Console → 使用状況）
          ↓
  Storage > 700 MB  ──→  即座に移行を決定（Storage は追加不可）
          ↓
  読み取り > 35,000/日  ──→  2週間以内に移行
          ↓
  書き込み > 14,000/日  ──→  2週間以内に移行
          ↓
  すべて正常  ──→  翌週も継続監視
```

---

### Blaze 移行手順（30分で完了）

#### Step 1: 予算アラートの設定（移行前に必須）

```
Google Cloud Console → 予算とアラート → 予算を作成
  プロジェクト: trust-car-platform
  予算額: $10/月（安全マージン）
  アラート: 50% / 90% / 100% で通知メール
```
> **重要**: Blaze は従量課金のため、バグや DDoS で異常課金のリスクがある。
> 予算アラートなしで移行しないこと。

#### Step 2: Blaze Plan に移行

```
Firebase Console → プロジェクトの設定 → 使用量と請求
  → 「Blaze プランにアップグレード」
  → クレジットカード登録
  → 確認
```

#### Step 3: Cloud Functions を有効化（Blaze 移行後に使えるようになる）

現在未使用だが、以下の機能実装時に必要になる：

| 機能 | Cloud Functions の役割 |
|------|----------------------|
| 退会後30日削除 | `scheduled` Function（毎日実行） |
| BtoB 成果報酬計算 | `onWrite` トリガー |
| プッシュ通知の一括送信 | FCM Admin SDK 呼び出し |
| 課金処理（Phase 7） | Webhook 受信（Stripe等） |

#### Step 4: Firestore セキュリティルールで DDoS 対策

```javascript
// 1ユーザーが1秒に1回しか書き込めないレート制限（例）
// ※ Firestore rules では直接的な rate limit は不可だが
//    ドキュメントサイズ上限で間接的に制限
allow create: if request.resource.data.keys().size() <= 20
           && request.resource.size() < 1024 * 100; // 100KB上限
```

---

### コスト最適化（ローンチ前に実施）

#### 読み取り削減（最重要）

```dart
// ❌ 悪い例: 画面を開くたびに全件取得
await firestore.collection('posts').get();

// ✅ 良い例: ページネーション（実装済み）
await firestore.collection('posts')
  .orderBy('createdAt', descending: true)
  .limit(20)
  .get();
```

#### Storage コスト削減（実装済み）

```dart
// lib/services/image_processing_service.dart に実装済み
// - 最大解像度: 1080px
// - JPEG品質: 80%
// - 推定圧縮後サイズ: 100〜300KB/枚
```
> 現在の圧縮設定で OK。変更不要。

#### リアルタイム購読の最適化（画面離脱時にキャンセル）

```dart
// ✅ Providerが dispose 時に listener をキャンセルしていることを確認
@override
void dispose() {
  _subscription?.cancel(); // 必須
  super.dispose();
}
```
> 各 Provider の dispose() を確認すること。漏れがあると Firestore 接続が増え続ける。

---

### 移行後の監視強化

Blaze 移行後は `firebase_performance` パッケージ（導入済み）を活用：

```dart
// lib/services/ の重いクエリに計測を追加（移行後のタスク）
final trace = FirebasePerformance.instance.newTrace('posts_feed_load');
await trace.start();
// ... Firestore クエリ実行 ...
await trace.stop();
```

Firebase Console → Performance → トレース で可視化できる。

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
