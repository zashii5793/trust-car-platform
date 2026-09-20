#!/usr/bin/env bash
#
# seed_all.sh — エミュレータに「1年使った状態」を一度に作る
#
# Usage:
#   firebase emulators:start --only auth,firestore,storage   # 別ターミナル
#   ./scripts/seed_all.sh
#
# なぜ要るか:
#   エミュレータのデータはメモリ上にあり、**止めると消える**。翌日また触るには
#   同じ順番でシードを流し直すことになるが、順番には意味がある（seed_personas が
#   作る uid / vehicleId を後続が参照する）。手で7回打つと必ず1つ飛ばす。
#
# 最後に verify_personas.js まで走らせるので、**流し終わった時点で
# 「ちゃんと見える状態か」まで分かる**。
#
set -euo pipefail

cd "$(dirname "$0")/.."

if ! curl -sf http://127.0.0.1:8080/ > /dev/null 2>&1; then
  echo "エミュレータが起動していません。先に次を実行してください:"
  echo "  firebase emulators:start --only auth,firestore,storage"
  exit 1
fi

# 順番に意味がある。personas が uid と vehicleId を作り、後続がそれを参照する。
SEEDS=(
  seed_personas            # ペルソナ A〜J（Auth ユーザー含む）— 必ず最初
  seed_shops               # 工場マスタ（タカヤモーターを含む）
  seed_shop_owner          # 店舗ペルソナ（shops/{uid} と uid を揃える）— shops の後
  seed_full_experience     # 投稿・コメント・出品・問い合わせ
  seed_safety_tips
  seed_community_trends
  seed_community_conversations
  seed_rich_history
  seed_drive_logs_persona_a
  seed_parts
  seed_fleet_year          # 法人100台＋1年分（大量件数の見え方）
  seed_media               # Storage に画像を置く
  seed_year_of_use         # 1年ぶんの利用データ＋店舗チャット — 最後
)

for s in "${SEEDS[@]}"; do
  printf '\n\033[1m▶ %s\033[0m\n' "$s"
  node "scripts/${s}.js" --emulator | tail -3
done

printf '\n\033[1m▶ 会話ログを docs/CHAT_LOG_SEED.md に書き出す\033[0m\n'
node scripts/export_chat_log.js

printf '\n\033[1m▶ ペルソナごとに、ルール越しに見えるかを確認する\033[0m\n'
node scripts/verify_personas.js
