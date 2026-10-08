#!/usr/bin/env bash
#
# seed_usability_test.sh — 使用感テスト（docs/USABILITY_TEST_PROMPT.md）の準備を1本で
#
# Usage:
#   firebase emulators:start --only auth,firestore,storage   # 別ターミナル（起動したまま）
#   ./scripts/seed_usability_test.sh
#
#   ポート 8080 が別のアプリに塞がれている端末では、エミュレータを別のポートで
#   起動し、同じ値を渡す（アプリ側も同じポートにする必要がある点に注意）:
#     FIRESTORE_EMULATOR_HOST=127.0.0.1:8085 ./scripts/seed_usability_test.sh
#
# 作るもの:
#   ユーザー側  ペルソナ A〜J と、その1年分（A は seed_year_of_use、C/D/E/F は
#               seed_personas_year が補う。整備の厚みは seed_rich_history）
#   店側        タカヤモーターの店主・スタッフ4人・顧客台帳1年分
#               （個人4,000・法人100・車 約6,000台・整備履歴 約1.5万件）
#   つなぎ      A/C/J と台帳の顧客のつながり・店から送った整備明細
#
# 順番に意味がある:
#   seed_shops       タカヤモーターの店（shops/shop_takaya_motor_okayama）
#   seed_personas    ペルソナの Auth・uid・車両。後続はこの uid と vehicleId を使う
#   seed_shop_owner  店主の Auth と、A/C/J の札（shop_customers）。shops の後
#   ユーザー側1年分  personas の車両の走行距離を正として逆算する
#   台帳1年分        A/C/J の札と車両を読んで、台帳の顧客とつなぐ。最後
#
# 書き込むのはエミュレータだけ（各シードに --emulator を付け、接続先が
# エミュレータであることを最初に確かめる）。データはメモリ上なので、
# エミュレータを止めると消える。翌日はこのスクリプトを流し直す。
#
# 流し直しても件数は増えない（各シードは決まった ID で書き、前回の分を消す）。
#
set -euo pipefail

cd "$(dirname "$0")/.."

export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
export FIREBASE_STORAGE_EMULATOR_HOST="${FIREBASE_STORAGE_EMULATOR_HOST:-127.0.0.1:9199}"

# 本番に向かないことを先に確かめる。ローカル以外の宛先なら止める。
for v in FIRESTORE_EMULATOR_HOST FIREBASE_AUTH_EMULATOR_HOST FIREBASE_STORAGE_EMULATOR_HOST; do
  val="${!v}"
  host="${val%:*}"
  case "$host" in
    localhost|127.0.0.1) ;;
    *) echo "[ERROR] $v=$val はローカルではありません。止めます。"; exit 1 ;;
  esac
done

# 8080 で答えているのが Firestore エミュレータかを確かめる。
# 別のアプリ（例: StudyCraft.app が 8080 を使う）が答えていると、
# 「起動はしているのに書けない」になる。エミュレータは本文 "Ok" を返す。
body="$(curl -s -m 3 "http://${FIRESTORE_EMULATOR_HOST}/" || true)"
if [ "$body" != "Ok" ]; then
  echo "[ERROR] ${FIRESTORE_EMULATOR_HOST} で Firestore エミュレータが応答しません。"
  if [ -n "$body" ]; then
    echo "        別のアプリがこのポートを使っています（応答の先頭: $(printf '%s' "$body" | head -c 60 | tr '\n' ' ')）"
    echo "        lsof -iTCP:${FIRESTORE_EMULATOR_HOST##*:} -sTCP:LISTEN で確かめてください。"
  else
    echo "        先に次を実行してください:"
    echo "          firebase emulators:start --only auth,firestore,storage"
  fi
  exit 1
fi
if ! curl -s -m 3 -o /dev/null "http://${FIREBASE_AUTH_EMULATOR_HOST}/"; then
  echo "[ERROR] ${FIREBASE_AUTH_EMULATOR_HOST} で Auth エミュレータが応答しません。"
  exit 1
fi

if [ ! -d scripts/node_modules/firebase ]; then
  echo "▶ scripts の依存を入れる（npm ci）"
  (cd scripts && npm ci --silent)
fi

SEEDS=(
  seed_shops                   # 工場マスタ（タカヤモーターを含む）
  seed_personas                # ペルソナ A〜J（Auth ユーザー含む）
  seed_shop_owner              # 店主（shop.owner@example.com）と A/C/J の札
  seed_full_experience         # 投稿・コメント・出品・問い合わせ
  seed_safety_tips
  seed_community_trends
  seed_community_conversations
  seed_rich_history            # 整備記録の厚み（A/C/D/E/G/H）
  seed_drive_logs_persona_a
  seed_parts
  seed_fleet_year              # 法人100台＋1年分（ユーザー側の大量件数）
  seed_media                   # Storage に画像を置く
  seed_year_of_use             # A の1年分＋店舗チャット
  seed_personas_year           # C/D/E/F の1年分（給油・売却車の記録・自賠責）
  seed_shop_ledger_year        # タカヤモーターの台帳1年分 — 必ず最後
)

LOG_DIR="$(mktemp -d)"
START=$SECONDS
printf '書き込み先: firestore=%s auth=%s storage=%s\n' \
  "$FIRESTORE_EMULATOR_HOST" "$FIREBASE_AUTH_EMULATOR_HOST" "$FIREBASE_STORAGE_EMULATOR_HOST"

run_step() {
  local name="$1"; shift
  local t0=$SECONDS
  printf '\n\033[1m▶ %s\033[0m\n' "$name"
  if ! "$@" > "$LOG_DIR/$name.log" 2>&1; then
    tail -30 "$LOG_DIR/$name.log"
    printf '\n[ERROR] %s が失敗しました（ログ: %s）\n' "$name" "$LOG_DIR/$name.log"
    exit 1
  fi
  tail -3 "$LOG_DIR/$name.log"
  printf '  （%d秒）\n' "$((SECONDS - t0))"
}

for s in "${SEEDS[@]}"; do
  run_step "$s" node "scripts/${s}.js" --emulator
done

# 確認（ルール越しに、アプリと同じクエリで読めるか）
run_step verify_personas node scripts/verify_personas.js
run_step verify_shop_ledger node scripts/verify_shop_ledger.js

ELAPSED=$((SECONDS - START))
printf '\n\033[1m準備ができました（%d分%02d秒）\033[0m\n' "$((ELAPSED / 60))" "$((ELAPSED % 60))"
cat <<'EOF'

ログイン（パスワードはすべて password123）
  ユーザー側  persona.a〜j@example.com（使用感テストで使うのは a / c / d / e / f）
  店側        shop.owner@example.com（タカヤモーター店主）
              staff1〜4.takaya@example.com（スタッフ。操作の記録は店主しか見られない）

アプリの起動
  flutter run -d chrome --dart-define=USE_EMULATOR=true
EOF
