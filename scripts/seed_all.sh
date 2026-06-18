#!/usr/bin/env bash
#
# ローカル開発用: Firebase エミュレータに全テストデータを投入する。
#
# 前提:
#   別ターミナルで以下が起動済みであること（データは揮発性。再起動したら本スクリプトを再実行）:
#     firebase emulators:start --only auth,firestore,storage
#
# 使い方（プロジェクトルートから）:
#   bash scripts/seed_all.sh
#
# 完了後、Emulator UI (http://localhost:4000) の Authentication タブに
# ペルソナが表示されればログイン可能。
#   ログイン例: family.sato@trustcar.demo / TrustCar!2026
#
set -euo pipefail
cd "$(dirname "$0")"

# firebase-admin を確実に用意
if [ ! -d node_modules/firebase-admin ]; then
  echo "[seed_all] firebase-admin をインストールします..."
  npm install
fi

# firebase-admin はこれらの環境変数を自動検出してエミュレータへ接続する。
# 各スクリプトの --emulator フラグと二重で確実に向ける。
export FIRESTORE_EMULATOR_HOST="localhost:8080"
export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
export FIREBASE_STORAGE_EMULATOR_HOST="localhost:9199"

echo "[seed_all] ペルソナ（Auth ユーザー＋車両＋整備履歴）を投入..."
node seed_personas.js --emulator --clean

for s in \
  seed_shops.js \
  seed_shop_extras.js \
  seed_parts_master.js \
  seed_community_trends.js \
  seed_safety_tips.js \
  seed_vehicle_model_images.js
do
  echo "[seed_all] $s ..."
  node "$s" --emulator
done

echo ""
echo "[seed_all] 完了 ✅"
echo "[seed_all] 確認: http://localhost:4000 → Authentication にペルソナが見えればOK"
echo "[seed_all] ログイン例: family.sato@trustcar.demo / TrustCar!2026"
