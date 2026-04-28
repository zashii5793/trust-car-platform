# Phase 7 収益化計画 — BtoB課金・RevenueCat連携

> **策定日**: 2026-04-28  
> **対象フェーズ**: ローンチ後 3〜6ヶ月（β公開後のユーザー獲得を確認してから着手）  
> **前提**: Phase 1〜6 完了済み。ユーザー数 300〜1,000人程度でFirebase Blaze移行完了後

---

## 1. 収益モデル概要

| モデル | 対象 | 金額感 | 優先度 |
|---|---|---|---|
| **BtoB月額プラン** | 工場・業者（店舗オーナー） | ¥3,980〜¥14,800/月 | P0 |
| **BtoB成果報酬** | 問い合わせ経由の契約 | 売上の 3〜5% | P1 |
| **プレミアムプラン** | 個人ユーザー | ¥480〜¥980/月 | P2 |
| **広告掲載** | 工場・部品メーカー | ¥5,000〜¥50,000/月 | P3 |

---

## 2. BtoB月額プラン設計

### 2-1. プランtier

```
┌─────────────────────────────────────────────────────────┐
│  FREE（現在の ShopPlan.free）                            │
│  ・店舗プロフィール掲載（閲覧のみ）                        │
│  ・問い合わせ受信: 月5件まで                              │
│  ・写真: 3枚まで                                         │
└─────────────────────────────────────────────────────────┘
        ↓ アップグレード
┌─────────────────────────────────────────────────────────┐
│  STANDARD  ¥3,980/月                                    │
│  ・問い合わせ受信: 無制限                                  │
│  ・写真: 20枚まで                                        │
│  ・サービスメニュー掲載（価格・工賃）                       │
│  ・「広告」バッジ非表示（有機的表示）                       │
└─────────────────────────────────────────────────────────┘
        ↓ アップグレード
┌─────────────────────────────────────────────────────────┐
│  PREMIUM  ¥9,800/月                                     │
│  ・STANDARD の全機能                                     │
│  ・検索結果での優先表示（isFeatured = true）               │
│  ・予約カレンダー機能（Phase 8）                          │
│  ・月次レポート（問い合わせ数・閲覧数）                     │
│  ・カスタム特集記事（SNSフィードへの掲載）                  │
└─────────────────────────────────────────────────────────┘
        ↓ アップグレード
┌─────────────────────────────────────────────────────────┐
│  ENTERPRISE  ¥14,800/月                                 │
│  ・PREMIUM の全機能                                      │
│  ・複数店舗管理（最大5店舗）                               │
│  ・API連携（在庫・予約システム）                           │
│  ・専任サポート担当                                       │
└─────────────────────────────────────────────────────────┘
```

### 2-2. プラン制限の実装箇所

| 制限 | 実装ファイル | 制御ロジック |
|---|---|---|
| 問い合わせ受信上限 | `inquiry_service.dart` | `unreadCountShop` + プランチェック |
| 写真枚数上限 | `shop_service.dart` | `images.length <= plan.maxPhotos` |
| 優先表示 | `firestore.indexes.json` | `isFeatured` フィールド活用（既存）|
| 複数店舗 | `shop_service.dart` | オーナーUID紐付けショップ数チェック |

---

## 3. RevenueCat 連携設計

### 3-1. 採用理由

- iOS App Store / Google Play の課金APIを統一インターフェースで管理
- Webhook でFirestoreのサブスクリプション状態を自動同期
- オープンソース・無料プランあり（月収 $2,500まで）

### 3-2. 必要パッケージ

```yaml
# pubspec.yaml に追加
dependencies:
  purchases_flutter: ^8.0.0  # RevenueCat Flutter SDK
```

### 3-3. RevenueCat プロダクトID設計

```
App Store Connect / Google Play Console で作成するプロダクトID:

BtoB プラン（サブスクリプション）:
  trustcar_btob_standard_monthly   ¥3,980/月
  trustcar_btob_standard_yearly    ¥39,800/年（2ヶ月分お得）
  trustcar_btob_premium_monthly    ¥9,800/月
  trustcar_btob_premium_yearly     ¥98,000/年
  trustcar_btob_enterprise_monthly ¥14,800/月

プレミアムプラン（ユーザー向け）:
  trustcar_premium_monthly         ¥480/月
  trustcar_premium_yearly          ¥4,800/年（2ヶ月分お得）
```

### 3-4. Firestoreスキーマ（追加フィールド）

```javascript
// shops/{shopId} に追加
{
  "subscriptionStatus": "active" | "expired" | "cancelled" | "trialing",
  "planId": "free" | "standard" | "premium" | "enterprise",
  "subscriptionExpiresAt": Timestamp,
  "revenueCatUserId": String,    // RevenueCat の customerID
  "trialStartedAt": Timestamp,   // 30日無料トライアル
}

// users/{userId} に追加（ユーザープレミアム用）
{
  "premiumStatus": "active" | "expired" | "free",
  "premiumExpiresAt": Timestamp,
  "revenueCatUserId": String,
}
```

### 3-5. 実装フロー

```
[店舗オーナーがプランアップグレードをタップ]
        ↓
RevenueCat.purchase(packageId)
        ↓ (App Store / Google Play 課金処理)
        ↓ 成功
RevenueCat Webhook → Firebase Cloud Functions
        ↓
Cloud Functions: shops/{shopId}.subscriptionStatus = 'active'
                 shops/{shopId}.planId = 'premium'
                 shops/{shopId}.subscriptionExpiresAt = 次の更新日
        ↓
ShopProvider / UI が planId を読んで機能制限を制御
```

---

## 4. プレミアムプラン（ユーザー向け）設計

### 4-1. 特典内容

| 機能 | 無料 | プレミアム |
|---|---|---|
| 車両登録台数 | 3台 | 無制限 |
| ドライブログ保存期間 | 90日 | 無制限 |
| 整備記録エクスポート（PDF） | 月3回 | 無制限 |
| SNS投稿 | 月30件 | 無制限 |
| 広告表示 | あり | なし |
| AIパーツおすすめ精度 | 標準 | 高精度（Phase 8） |

### 4-2. 制限実装方針

各制限はFirestoreの `users/{uid}.premiumStatus` フィールドで制御。
サービス層でチェック → `Result.failure(AppError.subscription('プレミアム機能です'))` を返す。

---

## 5. 実装スケジュール（目安）

| Week | 作業内容 |
|---|---|
| Week 1 | RevenueCat アカウント作成・プロダクトID設定（App Store / Play Console）|
| Week 2 | `purchases_flutter` 統合・RevenueCat初期化（`injection.dart`）|
| Week 3 | BtoBプラン購入フロー UI（`shop_owner_screen.dart` にプランアップグレード画面追加）|
| Week 4 | Cloud Functions: RevenueCat Webhook → Firestoreサブスクリプション同期 |
| Week 5 | 機能制限ロジック実装（問い合わせ上限・写真枚数・優先表示）|
| Week 6 | プレミアムプラン購入フロー UI |
| Week 7 | E2Eテスト・Sandbox課金テスト |
| Week 8 | 審査申請・ローンチ |

---

## 6. Cloud Functions 要件

```
Firebase Blaze プランが必須（Phase 7 着手前に移行すること）

実装が必要な Functions:
  onRevenueCatWebhook     - RevenueCat → Firestoreサブスクリプション同期
  onSubscriptionExpired   - 期限切れ時のダウングレード処理
  onInquiryCreated        - 問い合わせ数上限チェック（無料プラン）
  scheduledReportGenerate - 月次レポート生成（PREMIUM/ENTERPRISE向け）
```

---

## 7. 収益予測（保守的）

| ユーザー規模 | 想定BtoB契約数 | 月次MRR |
|---|---|---|
| ユーザー1,000人 | 工場10社 × STANDARD | ¥39,800/月 |
| ユーザー5,000人 | 工場30社 × STANDARD + 5社 PREMIUM | ¥168,400/月 |
| ユーザー10,000人 | 工場50社 × STANDARD + 20社 PREMIUM + 5社 ENTERPRISE | ¥465,000/月 |

> Firebase Blaze は月¥5,000〜¥30,000程度のコスト想定（規模による）

---

## 8. 次のアクション（着手前チェックリスト）

- [ ] App Store Connect でサブスクリプションプロダクトを登録
- [ ] Google Play Console でサブスクリプションプロダクトを登録
- [ ] RevenueCat アカウント作成・アプリ登録
- [ ] Firebase Blaze Plan への移行完了
- [ ] Cloud Functions の有効化確認
- [ ] `purchases_flutter` を pubspec.yaml に追加
- [ ] `ShopSubscriptionService` を `lib/services/` に新規作成
- [ ] `ShopSubscriptionService` を `injection.dart` に登録
- [ ] RevenueCat Webhook URL を Firebase に設定

---

## 9. 参考リンク

- RevenueCat Flutter SDK: https://docs.revenuecat.com/docs/flutter
- RevenueCat Webhook: https://docs.revenuecat.com/docs/webhooks
- App Store サブスクリプション審査ガイドライン: https://developer.apple.com/app-store/review/guidelines/#subscriptions
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
