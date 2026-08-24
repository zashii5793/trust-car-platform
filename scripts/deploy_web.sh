#!/usr/bin/env bash
#
# Flutter Web をビルドして Firebase Hosting へ公開する。
#
# 公開先: https://trust-car-platform.web.app
#
# なぜ GitHub Pages ではなくこちらか:
#   Firebase Auth は許可したドメインからしかログインを受け付けない。
#   2026-08-23 時点の承認済みドメインは以下の3つだけで、github.io は入っていない。
#
#     localhost / trust-car-platform.firebaseapp.com / trust-car-platform.web.app
#
#   Hosting なら既に承認済みなので、Console での追加作業なしにログインできる。
#   GitHub Pages を使う場合は、先に承認済みドメインへ zashii5793.github.io を
#   足さないと auth/unauthorized-domain でログインできない。
#
# 注意: 実行すると誰でも見られる場所にアプリが出ます。URL は推測しにくいものの、
# 公開であることに変わりはありません。自己サインアップを開けたままにするか、
# 配布先を絞るかは事前に決めてください。
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MAPS_KEY="${GOOGLE_MAPS_API_KEY_WEB:-}"

echo "=== 1/3 ビルド前の確認 ==="
command -v firebase >/dev/null || { echo "firebase CLI が見つかりません"; exit 1; }
firebase projects:list >/dev/null || { echo "firebase login をしてください"; exit 1; }

# 地図キーは index.html のプレースホルダに埋める。リポジトリには置かない。
RESTORE_INDEX=0
if [ -n "$MAPS_KEY" ]; then
  cp web/index.html web/index.html.bak
  RESTORE_INDEX=1
  sed -i '' "s|__GOOGLE_MAPS_API_KEY__|$MAPS_KEY|g" web/index.html
  echo "Google Maps のキーを埋め込みました"
else
  echo "GOOGLE_MAPS_API_KEY_WEB が未設定です。地図は距離順リストにフォールバックします。"
fi
cleanup() {
  if [ "$RESTORE_INDEX" = "1" ]; then mv web/index.html.bak web/index.html; fi
}
trap cleanup EXIT

echo
echo "=== 2/3 ビルド ==="
# Hosting はルート直下に配るので --base-href は既定の / のままでよい
# （GitHub Pages のときだけ /trust-car-platform/ が要る）。
flutter build web --release

echo
echo "=== 3/3 公開 ==="
firebase deploy --only hosting --project trust-car-platform

echo
echo "公開しました: https://trust-car-platform.web.app"
echo "規約:         https://trust-car-platform.web.app/terms.html"
echo "プライバシー: https://trust-car-platform.web.app/privacy.html"
