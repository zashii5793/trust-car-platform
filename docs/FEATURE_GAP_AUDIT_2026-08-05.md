# 機能ギャップ全画面走査（2026-08-05）

**目的**: 指摘を1件ずつ追う後追いをやめ、「作られているのに繋がっていない箇所」を機械的に洗い出す。
**方法**: モデルのフィールド定義と `lib/screens` / `lib/widgets` での参照を突き合わせ、UIに出ていない項目を検出。

---

## 結論

**モデルには存在するのに画面に一切出ていない項目が37件ある。**

「機能が無い」と見えていたものの多くは、**データ構造は作られていて画面が繋がっていないだけ**だった。

| モデル | 定義項目 | UIに出ていない | 割合 |
|--------|---------|---------------|------|
| `Vehicle` | 68 | **0** | 0% |
| `MaintenanceRecord` | 44 | **21** | 48% |
| `DriveLog` | 42 | **16** | 38% |

---

## 1. MaintenanceRecord — 21項目がUIに無い

```
parts, partsCost, laborHours, unitPrice, quantity, taxAmount, discountAmount,
miscCost, manufacturer, workerName, staffName, staffId,
nextReplacementDate, nextReplacementMileage, tireTreadDepth, inspectionResult,
certificateUpdated, safetyStandardsCertificate,
verifiedAt, verifiedByShopId, _verificationSourceOverride
```

**これは請求書OCRが読み取る項目とほぼ一致する。** 実際の請求書には
「部品名 / 数量 / 単価 / 金額 / 税額」が並んでおり、`InvoiceOcrService` はそれを
抽出する実装を持っている。**受け皿のモデルもある。だが表示する画面が無い。**

つまり請求書を読み込んでも、明細は保存されるだけで**誰も見られない**。

`nextReplacementDate` / `nextReplacementMileage` が使われていないことも重い。
「次回いつ交換すべきか」は整備記録の中心的な価値なのに、入力も表示もされていない。

## 2. DriveLog — 16項目がUIに無い

```
startLocation, endLocation, location, timestamp, heading, accuracy,
altitude, elevationGain, elevationLoss, maxSpeed, stopCount,
totalStopDuration, fuelConsumed, photoUrls, endTime, driveLogId
```

**「どこに行ったか」「道中の経路」「写真」を保存する構造は既にある。**
`startLocation` / `endLocation` / `location`（経路の点列）/ `photoUrls` が揃っている。

`firestore.indexes.json` にも「公開ドライブフィード: isPublic + status + createdAt」の
インデックス定義があり、**他ユーザーとの共有まで設計されている**。

にもかかわらず、画面側はこれらを一切読んでいない。ドライブログが
「機能が全然ない」と見えるのは、**設計と実装が途中で切れているため**。

## 3. Vehicle — 未使用ゼロ、ただし項目自体が無い

68項目すべてがUIに出ている。裏を返すと、
**オプション・装備（ナビ / ドライブレコーダー / ETC / バックカメラ等）は
モデルに1つも存在しない**。他の2つと違い、これは「繋がっていない」のではなく
「作られていない」。

---

## 4. 配色

### 低コントラスト（`Colors.white70` / `white54`）

青系グラデーション上で灰色に見え、可読性を落とす。

| ファイル | 箇所 |
|----------|------|
| `home_screen.dart` | 5 |
| `drive/drive_recording_screen.dart` | 3 |
| `fleet/fleet_dashboard_screen.dart` | 1（本日修正済み） |
| `parts/part_recommendation_screen.dart` | 1 |
| `document_scanner_screen.dart` | 1 |

### TabBar の色未指定

`AppBar` は `backgroundColor: AppColors.primary`（青）/ `foregroundColor: Colors.white`。
`TabBar` に色を指定しないと Material 3 の既定（暗色）が使われ、**青地に黒文字**になる。

| ファイル | 状態 |
|----------|------|
| `safety/safety_tip_screen.dart` | ❌ → 本日修正 |
| `accessories/accessory_showcase_screen.dart` | ❌ → 本日修正 |
| `marketplace/marketplace_screen.dart` | ✅ 問題なし（`colorScheme.surface` 上なので暗色が正しい） |

---

## 5. データ供給が手動スクリプトのみ

投入手段が手動実行しかなく、実行しなければ画面が空になる。

| コレクション | 投入手段 | 現状 |
|-------------|---------|------|
| `shops`（整備工場） | `scripts/seed_shops.js` | 未実行 → 1件も出ない |
| `safety_tips`（安全運転） | `scripts/seed_safety_tips.js` | 未実行 → 内容が空 |
| `vehicle_masters`（車両カタログ） | `scripts/import_vehicle_master.dart` | 10メーカー / 88車種 / グレードは `parent_id` 未設定で実質0 |
| `community_trends` | `scripts/seed_community_trends.js` | 未実行 |

---

## 優先順位の提案

**「繋げる」ほうが「作る」より安い。** 37項目は既に構造があるので、画面を足すだけで動く。

1. **整備記録の明細表示** — 請求書OCRの成果が初めてユーザーに届く。21項目のうち明細系を出す
2. **ドライブログの地図・写真** — 16項目のうち経路と写真。Google Maps APIキー取得が前提
3. **オプション・装備の新設** — 唯一「作る」必要がある。`Vehicle` にモデル追加から
4. **配色の一括修正** — `white70` 10箇所を機械的に置換
5. **シードの実行** — 人手作業。これが済まないと1〜3を作っても画面は空のまま

---

## この走査で分かったこと

指摘を受けてから調べる形では、**「無い」のか「繋がっていない」のかが毎回判別できない**。
今回の走査で、ドライブログも整備記録も**後者**だと数字で確定した。

同種の走査を定期的に回せば、実装と設計の乖離を継続的に検出できる。
