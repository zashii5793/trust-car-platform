#!/usr/bin/env bash
#
# 本番（Firebase trust-car-platform）が「動いているか」「main から取り残されていないか」を外から確かめる。
#
# なぜ要るか:
#   2026-09-30 に、ウェブ版が 2026-08-24 から5週間古いまま公開されていたこと、
#   Cloud Functions がほぼ無く退会後の削除が動いていなかったことが分かった。
#   どちらも店主に言われるまで誰も気づかなかった（docs/MAINTENANCE_OPS_REVIEW_2026-09-30.md 項目9）。
#
# 見るもの（認証なし・読むだけ）:
#   1. ウェブ版・規約・プライバシーポリシーが 200 で返るか
#   2. 公開中の版（/build_info.json の commit）が、main より古いまま STALE_DAYS 日を過ぎていないか
#   3. 外から呼べる Functions が本番にあるか（あれば 401/405 などを返す。無ければ 404）
#   4. 中の健康診断（opsHealth）が ok で、最後の診断が2時間以内か
#      （定期ジョブ・申し込みや車検案内の滞留・ウェブのエラーの急増・バックアップ）
#
# 使い方:
#   ./scripts/prod_watch.sh            # 問題があれば終了コード 1
#   STALE_DAYS=7 ./scripts/prod_watch.sh
#
# 結果は標準出力に Markdown で出す（GitHub Actions がそのまま Issue の本文にする）。
#
set -uo pipefail

SITE="${SITE:-https://trust-car-platform.web.app}"
FUNCTIONS_BASE="${FUNCTIONS_BASE:-https://asia-northeast1-trust-car-platform.cloudfunctions.net}"
STALE_DAYS="${STALE_DAYS:-3}"
# 健康診断（opsHealthCheck は1時間ごと）の最終確認がこれより古ければ NG（分）
HEALTH_MAX_AGE_MIN="${HEALTH_MAX_AGE_MIN:-120}"
# 外から呼べる（HTTP で受ける）Functions。スケジュール実行のものは外からは見えない
HTTP_FUNCTIONS="${HTTP_FUNCTIONS:-askCarAi onRevenueCatWebhook}"
# ウェブ版の中身に効く場所。ここ以外（docs/ など）の変更では「古い」と言わない
APP_PATHS=(lib web pubspec.yaml pubspec.lock assets)

problems=0
report=""
line() { report+="$1"$'\n'; }
fail() { problems=$((problems + 1)); line "- [NG] $1"; }
ok() { line "- [OK] $1"; }

status_of() { curl -s -o /dev/null -m 30 -w '%{http_code}' "$1"; }

line "## 本番の見張り（$(date -u +%Y-%m-%dT%H:%MZ)）"
line ""

# --- 1. 開けるか ------------------------------------------------------------
line "### ウェブ版"
for path in "/" "/terms.html" "/privacy.html" "/tokushoho.html"; do
  code="$(status_of "${SITE}${path}")"
  if [ "$code" = "200" ]; then
    ok "\`${path}\` → ${code}"
  else
    fail "\`${path}\` → ${code}（200 ではない）"
  fi
done

# --- 2. main から取り残されていないか -----------------------------------------
line ""
line "### 公開中の版"
info="$(curl -s -m 30 "${SITE}/build_info.json" || true)"
# 目印が無いとき、Hosting の書き換えで index.html が返る。JSON かどうかで見分ける
deployed="$(printf '%s' "$info" | sed -n 's/.*"commit":"\([0-9a-f]\{7,40\}\)[^"]*".*/\1/p')"
if [ -z "$deployed" ]; then
  fail "版の目印（\`/build_info.json\`）が無い。\`./scripts/deploy_web.sh\` で公開し直すと付く"
elif ! git cat-file -e "${deployed}^{commit}" 2>/dev/null; then
  fail "公開中の版 \`${deployed}\` がリポジトリに見つからない（履歴を取り込めていないか、手元のビルドから公開された）"
else
  ok "公開中の版: \`${deployed}\`"
  # 公開後に main へ入った、アプリの中身に効くコミット
  pending="$(git log --format='%h %cs %s' "${deployed}..origin/main" -- "${APP_PATHS[@]}" 2>/dev/null)"
  if [ -z "$pending" ]; then
    ok "main との差はない（アプリの中身に効く変更は全部公開済み）"
  else
    count="$(printf '%s\n' "$pending" | wc -l | tr -d ' ')"
    oldest="$(git log --reverse --format='%ct' "${deployed}..origin/main" -- "${APP_PATHS[@]}" | head -1)"
    age_days=$(( ($(date +%s) - oldest) / 86400 ))
    if [ "$age_days" -ge "$STALE_DAYS" ]; then
      fail "main に、公開されていない変更が ${count} 件（いちばん古いものは ${age_days} 日前）。\`./scripts/deploy_web.sh\` で公開する"
      line ""
      line "<details><summary>公開されていないコミット</summary>"
      line ""
      line '```'
      line "$(printf '%s\n' "$pending" | head -30)"
      line '```'
      line "</details>"
    else
      ok "公開されていない変更が ${count} 件（${age_days} 日前から。${STALE_DAYS} 日を過ぎたら知らせる）"
    fi
  fi
fi

# --- 3. Functions があるか ---------------------------------------------------
line ""
line "### Cloud Functions（外から呼べるもの）"
for fn in $HTTP_FUNCTIONS; do
  code="$(status_of "${FUNCTIONS_BASE}/${fn}")"
  case "$code" in
    404) fail "\`${fn}\` → 404（本番に無い）" ;;
    000) fail "\`${fn}\` → 応答なし" ;;
    5??) fail "\`${fn}\` → ${code}（中で落ちている）" ;;
    *) ok "\`${fn}\` → ${code}（ある）" ;;
  esac
done
line ""
line "スケジュール実行の Functions（\`purgeDeletedAccounts\` など）の中身は、下の健康診断（ハートビート）で見る。"

# --- 4. 健康診断（opsHealth） ------------------------------------------------
# opsHealthCheck が1時間ごとに書く結果を、opsHealth が外向けに返す（name と status だけ）。
# 各項目の意味と、NG のときに見るものは docs/MAINTENANCE_RUNBOOK.md の 0-8。
line ""
line "### 健康診断（\`opsHealth\`）"
health="$(curl -s -m 30 -w $'\n%{http_code}' "${FUNCTIONS_BASE}/opsHealth")"
health_code="$(printf '%s' "$health" | tail -n 1)"
health_body="$(printf '%s' "$health" | sed '$d')"
case "$health_code" in
  200)
    overall="$(printf '%s' "$health_body" | sed -n 's/.*"overall":"\([a-z]*\)".*/\1/p')"
    checked_ms="$(printf '%s' "$health_body" | sed -n 's/.*"checkedAtMs":\([0-9]*\).*/\1/p')"
    checked_at="$(printf '%s' "$health_body" | sed -n 's/.*"checkedAt":"\([^"]*\)".*/\1/p')"
    if [ -z "$overall" ] || [ -z "$checked_ms" ]; then
      fail "\`opsHealth\` の応答が読めない"
    else
      age_min=$(( ($(date +%s) - checked_ms / 1000) / 60 ))
      if [ "$age_min" -gt "$HEALTH_MAX_AGE_MIN" ]; then
        fail "最後の診断が ${age_min} 分前（${checked_at}）。\`opsHealthCheck\` が止まっている"
      fi
      if [ "$overall" = "ok" ]; then
        ok "全体: ok（${checked_at}・${age_min} 分前）"
      else
        fail "全体: ${overall}（${checked_at}・${age_min} 分前）"
      fi
      # 各項目。NG は上の「全体」で数えているので、ここでは数えずに並べるだけ
      while IFS= read -r item; do
        [ -z "$item" ] && continue
        name="$(printf '%s' "$item" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')"
        st="$(printf '%s' "$item" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
        case "$st" in
          ok) line "- [OK] \`${name}\`" ;;
          ng) line "- [NG] \`${name}\`" ;;
          *) line "- [不明] \`${name}\`（判定できなかった。NG には数えない）" ;;
        esac
      done <<< "$(printf '%s' "$health_body" | grep -o '{"name":"[^"]*","status":"[^"]*"}')"
    fi
    ;;
  404) fail "\`opsHealth\` → 404（未デプロイ）" ;;
  503) fail "\`opsHealth\` → 503（まだ一度も診断していない。\`opsHealthCheck\` を確かめる）" ;;
  000) fail "\`opsHealth\` → 応答なし" ;;
  *) fail "\`opsHealth\` → ${health_code}" ;;
esac

printf '%s' "$report"
[ "$problems" -eq 0 ]
