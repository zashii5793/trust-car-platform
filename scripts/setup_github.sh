#!/bin/bash
# Trust Car Platform - GitHub CLI セットアップスクリプト
# 初回のみ実行。gh CLI インストール + ラベル作成を自動化する。
#
# 使い方: ./scripts/setup_github.sh

set -e

echo "=== Trust Car Platform GitHub セットアップ ==="
echo ""

# gh CLI のインストール確認
if ! command -v gh &> /dev/null; then
  echo "gh CLI をインストールします..."
  brew install gh
  echo "✅ gh CLI インストール完了"
else
  echo "✅ gh CLI は既にインストール済み ($(gh --version | head -1))"
fi

echo ""

# 認証確認
if ! gh auth status &> /dev/null; then
  echo "GitHub認証を設定します..."
  echo "ブラウザが開くので、GitHubにログインしてください。"
  gh auth login --hostname github.com --git-protocol https --web
  echo "✅ GitHub認証 完了"
else
  echo "✅ GitHub認証 済み"
  gh auth status 2>&1 | grep "Logged in"
fi

echo ""
echo "--- ラベルを作成します ---"

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"

  gh label create "$name" \
    --color "$color" \
    --description "$description" \
    --force 2>/dev/null \
    && echo "  ✅ $name" \
    || echo "  ℹ️  $name (スキップ)"
}

# Claudeタスク用ラベル
create_label "claude-task"       "0075ca" "Claude Codeへの実装指示"
create_label "priority: high"    "d73a4a" "優先度高（即対応）"
create_label "priority: medium"  "e4e669" "優先度中（今週中）"
create_label "priority: low"     "0e8a16" "優先度低（時間があれば）"
create_label "status: in-progress" "fbca04" "Claude が作業中"

echo ""
echo "========================================"
echo "✅ セットアップ完了！"
echo "========================================"
echo ""
echo "【スマホからの指示方法】"
echo "  1. GitHub アプリ または Safari で以下を開く："
echo "     https://github.com/zashii5793/trust-car-platform/issues/new/choose"
echo "  2. 'Claudeタスク' テンプレートを選択"
echo "  3. やること・受け入れ条件を入力して Submit"
echo ""
echo "【Macでの確認方法（Claude Code起動時）】"
echo "  gh issue list --label 'claude-task' --state open"
echo ""
