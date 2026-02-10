# 車検・点検情報システム - ギャップ分析

## 概要

提供された仕様書と現在のモデル実装を比較し、不足している項目を整理。

---

## ① 顧客（オーナー）情報

### 仕様要件
| 項目 | 説明 |
|------|------|
| 氏名（フリガナ含む） | 基本情報 |
| 住所 | 連絡先 |
| 電話番号 | 連絡先 |
| メールアドレス | 連絡先 |
| 生年月日 | 本人確認 |
| 法人/個人区分 | 顧客種別 |
| 法人名・代表者名 | 法人の場合 |
| 担当者名（法人の場合） | 法人の場合 |
| 希望連絡方法 | 通知設定 |
| 顧客メモ | 備考 |

### 現在の実装（AppUser）
| 項目 | ステータス |
|------|-----------|
| email | ✅ 実装済み |
| displayName | ✅ 実装済み |
| photoUrl | ✅ 実装済み |
| notificationSettings | ✅ 実装済み |

### 🔴 不足項目
- `furigana` - フリガナ
- `phoneNumber` - 電話番号
- `address` - 住所（郵便番号・都道府県・市区町村・番地）
- `birthDate` - 生年月日
- `customerType` - 法人/個人区分（enum）
- `companyName` - 法人名
- `representativeName` - 代表者名
- `contactPersonName` - 担当者名
- `preferredContactMethod` - 希望連絡方法（enum）
- `customerMemo` - 顧客メモ

---

## ② 車両情報

### 仕様要件
| 項目 | 説明 |
|------|------|
| ナンバープレート | 識別 |
| 車台番号（VIN） | 識別 |
| 型式 | 識別 |
| メーカー/車種 | 基本情報 |
| 年式 | 基本情報 |
| グレード | 基本情報 |
| 初年度登録 | 法定 |
| 車検満了日 | ★最重要 |
| 自賠責保険期限 | 保険 |
| 任意保険情報 | 保険 |
| 走行距離 | 状態 |
| ボディカラー | 詳細 |
| 排気量 | 詳細 |
| 燃料種別 | 詳細 |
| 駆動方式 | 詳細 |
| ミッション種別 | 詳細 |
| 車両重量 | 詳細 |
| 乗車定員 | 詳細 |
| 購入日/納車日 | 履歴 |

### 現在の実装（Vehicle）
| 項目 | ステータス |
|------|-----------|
| maker, model, year, grade | ✅ 実装済み |
| mileage | ✅ 実装済み |
| licensePlate | ✅ 実装済み |
| vinNumber | ✅ 実装済み |
| modelCode | ✅ 実装済み |
| inspectionExpiryDate | ✅ 実装済み |
| insuranceExpiryDate（自賠責） | ✅ 実装済み |
| color | ✅ 実装済み |
| engineDisplacement | ✅ 実装済み |
| fuelType | ✅ 実装済み |
| purchaseDate | ✅ 実装済み |

### 🔴 不足項目
- `firstRegistrationDate` - 初年度登録日
- `voluntaryInsurance` - 任意保険情報（別モデルまたは埋め込み）
  - `insuranceCompany` - 保険会社名
  - `policyNumber` - 証券番号
  - `expiryDate` - 満了日
  - `coverageType` - 補償内容
- `driveType` - 駆動方式（enum: FF/FR/4WD/MR/RR）
- `transmissionType` - ミッション種別（enum: AT/MT/CVT）
- `vehicleWeight` - 車両重量(kg)
- `seatingCapacity` - 乗車定員

---

## ③ 車検・点検履歴

### 仕様要件
| 項目 | 説明 |
|------|------|
| 実施日 | 基本情報 |
| 点検種別 | 種別 |
| 実施店舗 | 店舗情報 |
| 次回予定日 | リマインダー用 |
| 担当スタッフ | 管理用 |
| 合否結果 | 車検のみ |
| 車検証更新記録 | 車検のみ |
| 保安基準適合証 | 車検のみ |

### 現在の実装（MaintenanceRecord）
| 項目 | ステータス |
|------|-----------|
| date（実施日） | ✅ 実装済み |
| type（点検種別） | ✅ 実装済み |
| shopName（実施店舗） | ✅ 実装済み |
| nextReplacementDate | ✅ 実装済み |

### 🔴 不足項目
- `staffId` / `staffName` - 担当スタッフ
- `inspectionResult` - 合否結果（enum: 合格/不合格/条件付合格）
- `certificateUpdated` - 車検証更新済みフラグ
- `safetyStandardsCertificate` - 保安基準適合証番号

---

## ④ 整備・作業明細

### 仕様要件
| 項目 | 説明 |
|------|------|
| 作業項目名 | 基本情報 |
| 作業カテゴリ | 分類 |
| 作業内容詳細 | 詳細 |
| 使用部品リスト | 部品管理 |
| 部品番号 | 部品管理 |
| 部品単価 | 金額 |
| 部品数量 | 金額 |
| 工賃 | 金額 |
| 作業時間 | 管理 |
| 作業者名 | 管理 |

### 現在の実装（MaintenanceRecord）
| 項目 | ステータス |
|------|-----------|
| title（作業項目名） | ✅ 実装済み |
| type（作業カテゴリ） | ✅ 実装済み |
| description（作業内容詳細） | ✅ 実装済み |
| partNumber | ✅ 実装済み（単一部品のみ）|
| partManufacturer | ✅ 実装済み（単一部品のみ）|
| cost | ✅ 実装済み（合計のみ）|

### 🔴 不足項目
- `workItems` - 作業項目リスト（別モデル: WorkItem）
  - `name` - 作業項目名
  - `laborCost` - 工賃
  - `laborHours` - 作業時間
  - `workerName` - 作業者名
- `parts` - 使用部品リスト（別モデル: Part）
  - `partNumber` - 部品番号
  - `partName` - 部品名
  - `manufacturer` - メーカー
  - `unitPrice` - 単価
  - `quantity` - 数量
  - `subtotal` - 小計

---

## ⑤ 請求・金額情報

### 仕様要件
| 項目 | 説明 |
|------|------|
| 部品代合計 | 内訳 |
| 工賃合計 | 内訳 |
| 諸費用 | 内訳 |
| 小計 | 計算 |
| 消費税 | 計算 |
| 割引 | 計算 |
| 総額 | 計算 |
| 支払方法 | 支払 |
| 支払状況 | 支払 |
| 入金日 | 支払 |
| 請求書番号 | 管理 |
| 見積書番号 | 管理 |

### 現在の実装
| 項目 | ステータス |
|------|-----------|
| cost（総額のみ） | ✅ 実装済み |

### 🔴 不足項目（新モデル: Invoice）
- `invoiceNumber` - 請求書番号
- `estimateNumber` - 見積書番号
- `partsCost` - 部品代合計
- `laborCost` - 工賃合計
- `miscCost` - 諸費用（車検印紙代、重量税等）
- `subtotal` - 小計
- `taxAmount` - 消費税額
- `discountAmount` - 割引額
- `totalAmount` - 総額
- `paymentMethod` - 支払方法（enum: 現金/カード/振込/ローン）
- `paymentStatus` - 支払状況（enum: 未払/一部入金/入金済）
- `paymentDate` - 入金日

---

## ⑥ 次回案内・リマインド

### 仕様要件
| 項目 | 説明 |
|------|------|
| 次回車検予定日 | リマインダー |
| 次回点検予定日 | リマインダー |
| 次回オイル交換時期 | リマインダー |
| 消耗品交換時期 | リマインダー |
| リマインド送信履歴 | 履歴 |
| 通知設定 | 設定 |
| 顧客対応履歴 | CRM |

### 現在の実装
| 項目 | ステータス |
|------|-----------|
| inspectionExpiryDate（Vehicle） | ✅ 実装済み |
| nextReplacementDate（MaintenanceRecord） | ✅ 実装済み |
| NotificationSettings | ✅ 実装済み |
| AppNotification | ✅ 実装済み |

### 🔴 不足項目
- `ReminderHistory` - リマインド送信履歴（新モデル）
  - `sentAt` - 送信日時
  - `channel` - 送信方法（SMS/Email/アプリ通知）
  - `reminderType` - リマインド種別
  - `status` - 送信結果
- `CustomerInteraction` - 顧客対応履歴（新モデル）
  - `interactionDate` - 対応日時
  - `interactionType` - 対応種別（電話/来店/メール）
  - `staffName` - 担当者
  - `notes` - 対応内容

---

## ⑦ 書類・画像管理

### 仕様要件
| 項目 | 説明 |
|------|------|
| 車検証コピー | 書類 |
| 点検整備記録簿 | 書類 |
| 見積書PDF | 書類 |
| 請求書PDF | 書類 |
| 作業写真 | 画像 |
| 損傷写真 | 画像 |
| 同意書 | 書類 |

### 現在の実装
| 項目 | ステータス |
|------|-----------|
| imageUrls（MaintenanceRecord） | ✅ 実装済み（画像のみ）|

### 🔴 不足項目（新モデル: Document）
- `documentType` - 書類種別（enum）
- `title` - タイトル
- `fileUrl` - ファイルURL
- `mimeType` - ファイル形式
- `uploadedAt` - アップロード日時
- `uploadedBy` - アップロード者
- `relatedRecordId` - 関連記録ID（車検/点検記録と紐付け）

---

## ⑧ 権限・スタッフ管理

### 仕様要件
| 項目 | 説明 |
|------|------|
| スタッフID | 識別 |
| 担当者名 | 基本情報 |
| 役職 | 権限管理 |
| 担当車両リスト | 割り当て |
| 操作ログ | 監査 |

### 現在の実装
なし（個人向けアプリのため未実装）

### 🔴 不足項目（BtoBフェーズで実装予定）
- `Staff` モデル
- `Role` / `Permission` モデル
- `AuditLog` モデル

---

## 優先度別 実装推奨

### 🔴 高優先度（Phase 5で必須）
1. **Vehicle拡張**
   - `firstRegistrationDate`, `driveType`, `transmissionType`, `vehicleWeight`, `seatingCapacity`
   - `VoluntaryInsurance` 埋め込みまたは別モデル

2. **MaintenanceRecord拡張**
   - `staffName`, `inspectionResult`
   - `WorkItem` サブコレクション
   - `Part` サブコレクション

3. **Invoice 新モデル**
   - 請求・金額の詳細管理

### 🟡 中優先度（Phase 5-6）
4. **AppUser拡張**
   - 顧客詳細情報（電話番号、住所等）

5. **Document 新モデル**
   - 書類・画像の統合管理

6. **ReminderHistory 新モデル**
   - 送信履歴の追跡

### 🟢 低優先度（BtoBフェーズ）
7. **Staff / Role モデル**
8. **AuditLog モデル**
9. **CustomerInteraction モデル**

---

---

## ⑨ 新商品・サービスメニュー管理（追加要件）

### 要件
| 項目 | 説明 |
|------|------|
| 板金・塗装 | ボディリペア |
| ガラスコーティング | コーティングサービス |
| カーフィルム | ウィンドウフィルム施工 |
| カスタム・ドレスアップ | パーツ取付等 |
| その他商品・サービス | 柔軟に追加可能 |

### 現在の実装
MaintenanceTypeに一部存在（洗車・コーティング等）

### 🔴 不足項目
- `ServiceMenu` 新モデル
  - `id` - サービスID
  - `category` - カテゴリ（enum: 車検/点検/整備/板金塗装/コーティング/その他）
  - `name` - サービス名
  - `description` - 説明
  - `basePrice` - 基本料金
  - `estimatedHours` - 想定作業時間
  - `isActive` - 有効フラグ
- MaintenanceType enum拡張
  - `bodyRepair` - 板金・塗装
  - `glassCoating` - ガラスコーティング
  - `carFilm` - カーフィルム
  - `customization` - カスタム・ドレスアップ

---

## 次のアクション

1. ユーザー確認: この分析結果を確認し、実装優先度を決定
2. モデル設計: 高優先度項目のモデル詳細設計
3. 段階的実装: テストファースト開発で順次追加

---

## 更新履歴
- 2024-XX-XX: 初版作成
- 2024-XX-XX: ⑨新商品・サービスメニュー管理を追加（板金/塗装/コーティング等）
