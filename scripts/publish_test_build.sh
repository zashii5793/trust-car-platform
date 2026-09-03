#!/usr/bin/env bash
#
# テスト配布ひと揃いを Firebase Hosting に出す。
#
#   Web 版        https://trust-car-platform.web.app
#   受け取り口    https://trust-car-platform.web.app/download.html
#   APK           https://trust-car-platform.web.app/TrustCar-<sha>.apk
#
# なぜ deploy_web.sh と別かというと、この2点が違うため。
#
#   1. **クリーンなコミットからビルドする。** deploy_web.sh は手元の作業ツリーを
#      そのまま使う。2026-08-24 に、別セッションが編集中だった未コミットの
#      コードがそのまま本番へ出た。テスト配布は「レビュー済みのコミットが出て
#      いる」ことが前提なので、ここでは ref を切り出してビルドする。
#   2. **APK を同梱する。** Actions の Test APK が作った成果物を取ってきて
#      一緒に配る。APK はリポジトリに置かない（100MB 超をコミットしないため）。
#
# なぜ GitHub Releases ではなく Hosting かというと、リポジトリの公開設定に
# 左右されないため。private にした瞬間、Releases のリンクはテスターから
# 見えなくなる。
#
# 使い方:
#   ./scripts/publish_test_build.sh              # origin/main を出す
#   ./scripts/publish_test_build.sh <ref>        # 任意のコミットを出す
#   SKIP_APK=1 ./scripts/publish_test_build.sh   # Web だけ出し直す
#
set -euo pipefail

REF="${1:-origin/main}"
PROJECT=trust-car-platform
REPO=zashii5793/trust-car-platform
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
cleanup() {
  cd "$REPO_ROOT"
  git worktree remove --force "$WORK/src" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

command -v firebase >/dev/null || { echo "firebase CLI がありません"; exit 1; }
command -v gh >/dev/null || { echo "gh CLI がありません"; exit 1; }

echo "=== 1/5 ${REF} を切り出す ==="
cd "$REPO_ROOT"
git fetch origin --quiet
git worktree add --detach "$WORK/src" "$REF" >/dev/null
cd "$WORK/src"
SHA="$(git rev-parse --short HEAD)"
echo "  $SHA  $(git log -1 --format=%s)"

echo
echo "=== 2/5 Web をビルド ==="
if [ -n "${GOOGLE_MAPS_API_KEY_WEB:-}" ]; then
  # 切り出した側を書き換えるので、リポジトリ本体は汚れない。
  sed -i '' "s|__GOOGLE_MAPS_API_KEY__|$GOOGLE_MAPS_API_KEY_WEB|g" web/index.html
  echo "  Google Maps のキーを埋め込みました"
else
  echo "  GOOGLE_MAPS_API_KEY_WEB は未設定。地図は距離順リストにフォールバックします。"
fi
flutter pub get >/dev/null
flutter build web --release --dart-define=APP_BUILD_ID="$SHA"

APK_NAME=""
APK_SIZE=""
if [ "${SKIP_APK:-}" = "1" ]; then
  echo
  echo "=== 3/5 APK は SKIP_APK=1 のため省略 ==="
else
  echo
  echo "=== 3/5 Test APK の成果物を取ってくる ==="
  RUN_ID="$(gh run list --repo "$REPO" --workflow=test_apk.yml \
    --status success --limit 1 --json databaseId -q '.[0].databaseId')"
  if [ -z "$RUN_ID" ]; then
    echo "  成功した Test APK の実行がありません。"
    echo "  Actions → Test APK → Run workflow を先に回してください。"
    exit 1
  fi
  echo "  run #$RUN_ID"
  mkdir -p "$WORK/apk"
  gh run download "$RUN_ID" --repo "$REPO" -n trustcar-test-apk --dir "$WORK/apk"
  SRC_APK="$(find "$WORK/apk" -name '*.apk' -maxdepth 2 | head -1)"
  [ -n "$SRC_APK" ] || { echo "  APK が見つかりません"; exit 1; }

  APK_NAME="TrustCar-$SHA.apk"
  cp "$SRC_APK" "build/web/$APK_NAME"
  APK_SIZE="$(du -h "build/web/$APK_NAME" | cut -f1 | tr -d ' ')"
  echo "  $APK_NAME  ($APK_SIZE)"
fi

echo
echo "=== 4/5 受け取りページを組み立てる ==="
if [ -n "$APK_NAME" ]; then
  sed -i '' "s|__APK_FILENAME__|/$APK_NAME|g; s|__APK_SIZE__|$APK_SIZE|g; s|__APK_BUILD__|$SHA|g" \
    build/web/download.html
else
  # APK 抜きで出すときは Android の欄ごと隠す。リンク切れを配るより良い。
  sed -i '' 's|<section class="card" id="android-card">|<section class="card" id="android-card" hidden>|' \
    build/web/download.html
fi
if grep -q "__APK_" build/web/download.html; then
  echo "  プレースホルダが残っています"; exit 1
fi

echo
echo "=== 5/5 公開 ==="
firebase deploy --only hosting --project "$PROJECT"

echo
echo "Web 版      https://trust-car-platform.web.app"
echo "受け取り口  https://trust-car-platform.web.app/download.html   ← テストユーザーにはこれを渡す"
[ -n "$APK_NAME" ] && echo "APK         https://trust-car-platform.web.app/$APK_NAME"
echo "ビルド      $SHA"
