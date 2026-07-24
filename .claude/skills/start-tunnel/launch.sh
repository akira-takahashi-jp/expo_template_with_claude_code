#!/usr/bin/env bash
#
# Expo Tunnel ワークフローを起動し、トラッキング Issue に exp:// URL が
# コメントされるのを待って表示する。
#
# 使い方:
#   launch.sh [--ref <branch>] [--timeout <秒>]
#
# --ref     : トンネルで配信するブランチ（省略時は yml の push.branches → 現在のブランチ → develop）
# --timeout : URL 待機の上限秒数（既定 420）
#
set -euo pipefail

REF=""
TIMEOUT=420
POLL=15

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)     REF="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/expo-tunnel.yml"
WORKFLOW="expo-tunnel.yml"

# --- 前提チェック ---------------------------------------------------------
command -v gh >/dev/null 2>&1 || { echo "❌ gh CLI が見つかりません。" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "❌ GitHub 未ログイン: gh auth login" >&2; exit 1; }
[ -f "$WORKFLOW_FILE" ] || { echo "❌ $WORKFLOW_FILE が見つかりません。" >&2; exit 1; }

# トラッキング Issue 番号を yml から取得
ISSUE_NUMBER="$(grep -E '^  STATUS_ISSUE_NUMBER:' "$WORKFLOW_FILE" | sed -E 's/^  STATUS_ISSUE_NUMBER:[[:space:]]*//')"
case "$ISSUE_NUMBER" in
  ''|*REPLACE_*)
    echo "❌ STATUS_ISSUE_NUMBER が未設定（プレースホルダのまま）です。先に /init-project を実行してください。" >&2
    exit 1 ;;
esac

# 配信ブランチを決定
if [ -z "$REF" ]; then
  REF="$(sed -nE '/^    branches:/,/^[^[:space:]]/ s/^      - (.+)$/\1/p' "$WORKFLOW_FILE" | head -1)"
  [ -n "$REF" ] || REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo develop)"
fi

REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
echo "▶ repo=$REPO  issue=#$ISSUE_NUMBER  ref=$REF"

# 起動前のコメント数を記録（新規コメントの検出用）
BEFORE="$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments --jq '.comments | length')"

echo "▶ Expo Tunnel ワークフローを起動..."
gh workflow run "$WORKFLOW" --repo "$REPO" --ref "$REF"

echo "▶ トンネル準備を待機（最大 ${TIMEOUT}s、runner起動+npm ci込みで通常3〜5分）..."
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  sleep "$POLL"; elapsed=$((elapsed + POLL))
  # BEFORE 以降の新規コメントから exp:// を探す
  URL="$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json comments \
          --jq ".comments[${BEFORE}:] | .[].body" 2>/dev/null \
          | grep -oE 'exp://[^ \`]+' | head -1 || true)"
  if [ -n "$URL" ]; then
    echo ""
    echo "✅ トンネル準備完了:"
    echo "   $URL"
    echo ""
    echo "   Expo Go でスキャンする QR:"
    echo "   https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=$(node -e "console.log(encodeURIComponent(process.argv[1]))" "$URL" 2>/dev/null || printf '%s' "$URL")"
    exit 0
  fi
  echo "  ...待機中 (${elapsed}s)"
done

echo "⚠️ ${TIMEOUT}s 以内に exp:// URL を検出できませんでした。Actions のログを確認してください:" >&2
gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 1 --json url --jq '.[0].url' 2>/dev/null || true
exit 1
