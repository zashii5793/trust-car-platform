# trust-car-platform

## ペルソナ・シードデータ（エミュレータ）

`docs/PERSONA_SCENARIO_GUIDE.md` で定義したペルソナ A〜I を、Firebase Emulator に
「動く」データとして投入するスクリプトです（車両・フリート20台・整備履歴・工場・問い合わせ）。
アプリでログインして各ペルソナの画面を体験できます。

```bash
cd scripts
npm install                       # 初回のみ（firebase-admin / firebase-tools）

npm run seed-personas:dry-run     # 書き込まず登録予定を確認
npm run seed-personas:emulator    # エミュレータを起動→投入→終了（firestore + auth）
```

- 投入先: `users` / `vehicles` / `maintenance_records` / `shops` / `fleet_members` / `inquiries`
  （固定ID + `merge` で冪等。再実行しても重複しません）
- ログイン: `persona.a@example.com` 〜 `persona.i@example.com` / パスワード `password123`
  （例: 法人フリート20台は `persona.b@example.com`）
- トレンド・安全情報は既存の `seed_community_trends.js` / `seed_safety_tips.js` に委ねています。

> ⚠️ `--emulator` を付けずに実行すると Application Default Credentials で **本番** に
> 書き込みます。本番投入は人手承認のうえ、`demo_*` を含むサンプルの扱いを整理してから行ってください。
