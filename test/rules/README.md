# Storage セキュリティルール テスト

`storage.rules` の挙動を Storage Emulator 上で自動検証する。

## セットアップ

```bash
cd test/rules
npm install
```

## 実行

```bash
npm test
```

`firebase emulators:exec` が Storage Emulator を一時起動し、Jest を実行する。
Java（Firebase Emulator の動作要件）が必要。

## 検証内容

- `vehicles/{userId}/{fileName}` の所有者スコープ（write/delete は本人のみ、read は認証済み）
- 画像種別・サイズ制限（isImageFile / isValidFileSize）
- 旧3セグメントパス `vehicles/{userId}/{vehicleId}/{fileName}` の所有者スコープ
- 旧々形式 `vehicles/{fileName}`（userId未スコープ）はルール未定義＝デフォルト拒否
  （既存画像は `scripts/migrate_vehicle_images.js` での移行が前提）
- デフォルト拒否

## 注意

`node_modules/` はコミットしない（リポジトリ root の `.gitignore` 対象）。
