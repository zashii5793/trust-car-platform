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
- 画像種別・サイズ制限（isImageFile / isValidImageSize）
- 旧形式 `vehicles/{fileName}` の後方互換（read のみ許可、write/delete は拒否）
- デフォルト拒否

## 注意

`node_modules/` はコミットしない（リポジトリ root の `.gitignore` 対象）。
