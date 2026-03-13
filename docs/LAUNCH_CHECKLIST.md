# Trust Car Platform - ローンチチェックリスト

> **作成日**: 2026-03-13
> **目標**: 2026年4月中旬 公開
> **担当区分**: 🤖 Claude対応可 / 👤 人間作業必須

---

## フェーズ1: インフラ設定（Week 1: 3/13〜3/19）

### Firebase Console作業（👤 人間作業）

- [ ] Firebase Console → プロジェクト「trust-car-platform」を開く
- [ ] **Androidアプリ** の Bundle ID を `jp.trustcar.app` に変更
  - 「プロジェクト設定」→「アプリ」→ Androidアプリ → パッケージ名を変更
  - または古いアプリを削除して `jp.trustcar.app` で再登録
- [ ] **iOSアプリ** の Bundle ID を `jp.trustcar.app` に変更
- [ ] `google-services.json` を再ダウンロード → `android/app/google-services.json` に配置
- [ ] `GoogleService-Info.plist` を再ダウンロード → `ios/Runner/GoogleService-Info.plist` に配置
- [ ] Firebase Authentication → ログイン方法を確認（Email / Google）
- [ ] Firebase Console → API キーの制限設定（Androidパッケージ名・iOSバンドルIDで制限）

### Firestoreデプロイ（🤖 Claude / 👤 要Firebase CLI）

```bash
# インデックスをデプロイ（firestore.indexes.jsonが約30件定義済み）
firebase deploy --only firestore:indexes

# ルールをデプロイ（セキュリティ修正後）
firebase deploy --only firestore:rules
```

- [ ] `firebase deploy --only firestore:indexes` 実行
- [ ] `firebase deploy --only firestore:rules` 実行（rules修正後）

---

## フェーズ2: コード修正（Week 1: 3/13〜3/19）

### P0バグ修正（🤖 Claude対応可）

- [ ] **BUG-1**: `part_detail_screen.dart` のローカル状態を削除して Provider に一本化
  - ファイル: `lib/screens/marketplace/part_detail_screen.dart`
  - ローカル `_isLoading`, `_errorMessage`, `_detail` → `Consumer<PartRecommendationProvider>` に置換

- [ ] **BUG-2**: `toggleLike` レースコンディション修正
  - ファイル: `lib/providers/post_provider.dart`
  - `_pendingLikes = Set<String>()` でdebounce管理を追加

### Firestore Security Rules修正（🤖 Claude対応可）

- [ ] **S-2**: `drive_waypoints` オーナーチェック追加
  ```javascript
  // firestore.rules
  match /drive_waypoints/{waypointId} {
    allow read, write: if isAuthenticated() && resource.data.userId == request.auth.uid;
  }
  ```

- [ ] **S-1**: `shops` create に管理者ロールチェック
  ```javascript
  match /shops/{shopId} {
    allow create: if isAdmin();  // または申請フロー経由のみ
  }
  ```

- [ ] **S-3**: `inquiries/messages` に当事者チェック
  ```javascript
  match /inquiries/{inquiryId}/messages/{messageId} {
    allow read: if isAuthenticated() &&
      (get(/databases/$(database)/documents/inquiries/$(inquiryId)).data.userId == request.auth.uid
      || get(/databases/$(database)/documents/inquiries/$(inquiryId)).data.shopId == request.auth.uid);
  }
  ```

### プライバシーポリシー（🤖 Claude対応可 + 👤 法的確認必須）

- [ ] プライバシーポリシー画面を作成
  - ファイル: `lib/screens/settings/privacy_policy_screen.dart`
  - 収集データ: メールアドレス、車両情報、位置情報（GPS）、整備記録
  - 利用目的・第三者提供・開示請求先・連絡先を記載
  - プロフィール画面またはログイン画面からリンク
- [ ] 利用規約画面を作成（App Store審査でも確認される）

---

## フェーズ3: ビルド検証（Week 2: 3/20〜3/26）

### Android（🤖 一部Claude、👤 実機テスト）

- [ ] `flutter build apk --debug` → ビルド成功確認
- [ ] `flutter build apk --release` → リリースビルド確認
- [ ] 実機 / Androidエミュレータで動作確認
- [ ] ログイン → 車両登録 → 整備記録 の基本フロー確認
- [ ] Firebase Crashlytics が正常に起動するか確認
- [ ] **署名設定**: `android/app/build.gradle.kts` に keystore 設定追加

```kotlin
// android/app/build.gradle.kts に追加（keystoreファイルは別途用意）
signingConfigs {
    create("release") {
        storeFile = file("../keystore/release.keystore")
        storePassword = System.getenv("KEY_STORE_PASSWORD")
        keyAlias = System.getenv("KEY_ALIAS")
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### iOS（👤 Mac環境必須）

- [ ] `flutter build ios --no-codesign --debug` → ビルド成功確認
- [ ] Xcode で Bundle ID `jp.trustcar.app` が設定されているか確認
- [ ] Apple Developer Program 登録（年間$99）
- [ ] Provisioning Profile 設定
- [ ] `flutter build ios --release` → 実機テスト
- [ ] TestFlight アップロード

---

## フェーズ4: ストア申請準備（Week 3: 3/27〜4/2）

### スクリーンショット・素材（👤 人間作業）

- [ ] iPhone 6.7インチ スクリーンショット（最低3枚、最大10枚）
  - ログイン画面
  - 車両一覧（ホーム）
  - 整備記録タイムライン
  - マーケット（工場検索）
  - SNSフィード
- [ ] iPad スクリーンショット（App Store必須）
- [ ] Android: フォン + 7インチタブレット スクリーンショット
- [ ] アプリアイコン 1024×1024px（App Store用）

### App Store Connect（👤 人間作業）

- [ ] アカウント登録・アプリ登録
- [ ] バンドルID: `jp.trustcar.app`
- [ ] アプリ名: 「TrustCar - 車両管理とカーライフ」（案）
- [ ] カテゴリ: ライフスタイル / ユーティリティ
- [ ] 年齢制限: 4+
- [ ] プライバシーポリシーURL（ホスティング必要）
- [ ] App Store説明文（日本語・英語）
- [ ] キーワード設定

### Google Play Console（👤 人間作業）

- [ ] アカウント登録（$25 初回のみ）
- [ ] アプリ登録: `jp.trustcar.app`
- [ ] コンテンツレーティング: Everyone
- [ ] ターゲット層: 自動車ユーザー
- [ ] Play Store説明文・スクリーンショット

---

## フェーズ5: ストア審査申請（Week 4: 4/3〜4/9）

- [ ] App Store 審査申請（通常3〜7日）
- [ ] Google Play 審査申請（通常3〜5日）
- [ ] 審査フィードバック対応（リジェクト時）

**よくあるリジェクト理由の事前確認**:
- [ ] プライバシーポリシーが機能している（URL有効）
- [ ] 位置情報の使用理由がInfo.plistに記載されている
- [ ] テストアカウント情報を審査員用に用意
- [ ] クラッシュしない（実機テスト済み）
- [ ] 全ボタンが機能する（未実装UIを本番に入れない）

---

## 技術的負債（β公開後に対応）

### 中優先度

| 項目 | ファイル | 内容 |
|------|---------|------|
| DriveLog GPS記録 | `lib/screens/drive/` | 現在は保存のみ、リアルタイムGPS未実装 |
| コメント機能 | `lib/screens/sns/` | SNS投稿へのコメントUI未実装 |
| 通知のいいね連携 | `lib/services/notification_service.dart` | いいね/コメント時のPush通知未連携 |
| DriveLogScreenテスト | `test/screens/` | ウィジェットテスト未作成 |

### 低優先度

| 項目 | ファイル | 内容 |
|------|---------|------|
| 購入フロー | `lib/screens/marketplace/` | パーツ購入・決済UI未実装 |
| 管理者ダッシュボード | 未着手 | 店舗承認・スパム管理 |
| バージョンコード自動増 | `.github/workflows/ci.yml` | CI/CDの整備 |
| 統合テストCI実行 | `.github/workflows/ci.yml` | Firebase Emulator連携 |

---

## ビジネスモデル（参考）

```
マネタイズ計画（β後）:

Phase 1（無料）
  → ユーザー獲得優先
  → 車両管理・整備記録・SNS は無料

Phase 2（マーケット収益化）
  → 工場・修理店：月額掲載料（¥3,000〜¥10,000/月）
  → パーツ販売：成約手数料（3〜5%）
  → isFeatured（広告）：掲載ブースト料金

Phase 3（プレミアム機能）
  → ドライブログ高度分析（燃費AI予測）
  → 車検・整備リマインダー SMS通知
  → 複数台所有ユーザー向けプラン
```

---

## 緊急連絡・サポート体制（公開前に用意）

- [ ] お問い合わせメールアドレス決定（例: support@trustcar.jp）
- [ ] プライバシーポリシーのホスティング（GitHub Pages等でも可）
- [ ] アプリ内の「フィードバック送信」機能（メール連携）

---

> **このチェックリストは随時更新**
> 完了した項目は [x] に変更して git commit すること
