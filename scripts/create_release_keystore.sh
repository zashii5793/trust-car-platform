#!/usr/bin/env bash
#
# Android のリリース署名鍵を作り、GitHub Secrets に登録するところまでやる。
#
# 署名なしでもテスト配布はできる（.github/workflows/test_apk.yml は鍵が無ければ
# profile ビルドにフォールバックする）。このスクリプトが要るのは次の2つの場合:
#   - Google Play の内部テストを使いたい（Play は debug 鍵の成果物を受け付けない）
#   - 配布する APK を毎回同じ鍵で署名して、上書き更新できるようにしたい
#
# 重要: ここで作るキーストアを紛失すると、同じ鍵での更新が二度とできなくなる。
# Play App Signing に登録すればアップロード鍵の再発行で救えるので、Play を使う
# 場合は初回アップロード時に必ず有効化すること。
#
# 使い方:
#   ./scripts/create_release_keystore.sh
#
set -euo pipefail

KEYSTORE_PATH="${KEYSTORE_PATH:-$HOME/trustcar-release.keystore}"
KEY_ALIAS="${KEY_ALIAS:-trust-car-platform}"
REPO="${REPO:-zashii5793/trust-car-platform}"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "既にキーストアがあります: $KEYSTORE_PATH"
  echo "作り直すと、この鍵で署名済みの APK を上書き更新できなくなります。"
  echo "本当に作り直す場合は、先に手で退避してから再実行してください。"
  exit 1
fi

command -v keytool >/dev/null || { echo "keytool が見つかりません（JDK を入れてください）"; exit 1; }

echo "=== 1/4 パスワードの入力 ==="
echo "8文字以上。パスワードマネージャに保管できる状態にしてから進めてください。"
read -r -s -p "キーストアのパスワード: " STORE_PASSWORD; echo
read -r -s -p "もう一度: " STORE_PASSWORD_CONFIRM; echo
if [ "$STORE_PASSWORD" != "$STORE_PASSWORD_CONFIRM" ]; then
  echo "一致しません。中止します。"; exit 1
fi
if [ ${#STORE_PASSWORD} -lt 8 ]; then
  echo "8文字以上にしてください。中止します。"; exit 1
fi

echo
echo "=== 2/4 キーストアの生成 ==="
# -dname を渡して対話プロンプトを省く。証明書の中身は Play の表示には出ない。
keytool -genkeypair -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STORE_PASSWORD" -keypass "$STORE_PASSWORD" \
  -dname "CN=TrustCar, OU=Development, O=ZAXEL, L=Okayama, S=Okayama, C=JP"

chmod 600 "$KEYSTORE_PATH"
echo "作成しました: $KEYSTORE_PATH"

echo
echo "=== 3/4 android/key.properties の作成 ==="
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cat > "$REPO_ROOT/android/key.properties" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$STORE_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$KEYSTORE_PATH
EOF
chmod 600 "$REPO_ROOT/android/key.properties"
echo "作成しました: android/key.properties（.gitignore 対象。コミットしないこと）"

echo
echo "=== 4/4 GitHub Secrets への登録 ==="
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  base64 < "$KEYSTORE_PATH" | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$REPO"
  printf '%s' "$STORE_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
  printf '%s' "$STORE_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD --repo "$REPO"
  printf '%s' "$KEY_ALIAS"      | gh secret set ANDROID_KEY_ALIAS --repo "$REPO"
  echo "登録しました。以後 Test APK ワークフローは release ビルド（署名付き）になります。"
else
  echo "gh CLI が使えないため手動で登録してください:"
  echo "  ANDROID_KEYSTORE_BASE64   = $(printf '%s' "base64 < $KEYSTORE_PATH")  の出力"
  echo "  ANDROID_KEYSTORE_PASSWORD = 入力したパスワード"
  echo "  ANDROID_KEY_PASSWORD      = 同上"
  echo "  ANDROID_KEY_ALIAS         = $KEY_ALIAS"
fi

echo
echo "=== SHA-1（Google ログインを使う場合は Firebase に登録） ==="
keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS" -storepass "$STORE_PASSWORD" \
  | grep -E "SHA1|SHA256" || true
echo
echo "Firebase Console → プロジェクト設定 → jp.trustcar.app → フィンガープリントを追加"
echo "デバッグ鍵の SHA-1 も要る場合:"
echo "  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1"
