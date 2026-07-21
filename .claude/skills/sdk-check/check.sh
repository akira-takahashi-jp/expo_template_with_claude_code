#!/usr/bin/env bash
#
# Expo SDK のバージョン確認を補助する。公式の blank-typescript テンプレートから
# 「既知の正しい依存関係」を取得し、現在の package.json と並べて表示する。
#
# 使い方:
#   check.sh [<sdk番号>]
#
# 例:
#   check.sh          # 公開中の sdk-NN タグ一覧と現在の依存を表示
#   check.sh 54       # SDK 54 の正しい依存関係と現在の依存を表示
#
set -euo pipefail

SDK="${1:-}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== 公開中の SDK タグ（sdk-NN → その SDK 用テンプレートのバージョン） ==="
npm view expo-template-blank-typescript dist-tags 2>/dev/null || echo "(取得失敗: ネットワークを確認)"

if [ -n "$SDK" ]; then
  echo ""
  echo "=== SDK ${SDK} の既知の正しい依存関係（公式テンプレート） ==="
  npm view "expo-template-blank-typescript@sdk-${SDK}" dependencies 2>/dev/null \
    || echo "(取得失敗: sdk-${SDK} タグが存在しない可能性)"
fi

echo ""
echo "=== 現在の package.json の依存 (${REPO_ROOT}/package.json) ==="
( cd "$REPO_ROOT" && npm pkg get dependencies 2>/dev/null ) || echo "(package.json 読み取り失敗)"
