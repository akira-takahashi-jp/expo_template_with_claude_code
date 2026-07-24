#!/usr/bin/env bash
#
# Expo phone-only テンプレートの初回セットアップのうち、
# 「ファイル書き換え」だけを行うスクリプト。
#
# GitHub 操作（ユーザー名検出・トラッキング Issue 作成）は Claude が GitHub MCP
# ツールで先に済ませ、その結果（--notify-user / --issue）をこのスクリプトに渡す。
# → この環境（Claude Code on the web）には gh CLI が無いため、gh には依存しない。
#
# やること:
#   1. .github/workflows/expo-tunnel.yml の
#        STATUS_ISSUE_NUMBER / NOTIFY_USER / push.branches を書き換え
#   2. 指定があれば app.json / package.json の name・slug を変更
#
# 使い方:
#   configure.sh --issue <Issue番号> --notify-user <GitHubユーザー名> \
#                [--branch <dev-branch>] [--name <app-name>] [--slug <app-slug>]
#
# 例:
#   configure.sh --issue 1 --notify-user octocat --branch develop --name "My App" --slug my-app
#
set -euo pipefail

BRANCH=""
APP_NAME=""
APP_SLUG=""
ISSUE_NUMBER=""
NOTIFY_USER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)      BRANCH="$2"; shift 2 ;;
    --name)        APP_NAME="$2"; shift 2 ;;
    --slug)        APP_SLUG="$2"; shift 2 ;;
    --issue)       ISSUE_NUMBER="$2"; shift 2 ;;
    --notify-user) NOTIFY_USER="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/expo-tunnel.yml"
APP_JSON="$REPO_ROOT/app.json"
PKG_JSON="$REPO_ROOT/package.json"

# --- 前提チェック ---------------------------------------------------------
[ -n "$ISSUE_NUMBER" ]  || { echo "❌ --issue が必要です（Claude が MCP で作成した Issue 番号）。" >&2; exit 1; }
[ -n "$NOTIFY_USER" ]   || { echo "❌ --notify-user が必要です（Claude が get_me で取得したユーザー名）。" >&2; exit 1; }
[ -f "$WORKFLOW" ]      || { echo "❌ $WORKFLOW が見つかりません。テンプレートのルートで実行してください。" >&2; exit 1; }

echo "▶ NOTIFY_USER: $NOTIFY_USER"
echo "▶ Issue      : #$ISSUE_NUMBER"

# --- 1. workflow を書き換え -----------------------------------------------
sed -i.bak -E \
  -e "s/^(  STATUS_ISSUE_NUMBER: ).*/\1${ISSUE_NUMBER}/" \
  -e "s/^(  NOTIFY_USER: ).*/\1${NOTIFY_USER}/" \
  "$WORKFLOW"

if [ -n "$BRANCH" ]; then
  # push.branches の "      - develop" 行を差し替え（テンプレート初期値）
  sed -i.bak -E "s/^      - develop$/      - ${BRANCH}/" "$WORKFLOW"
  echo "▶ dev branch : $BRANCH"
fi
rm -f "$WORKFLOW.bak"
echo "▶ workflow 更新: STATUS_ISSUE_NUMBER=$ISSUE_NUMBER / NOTIFY_USER=$NOTIFY_USER"

# --- 2. アプリ名（任意） --------------------------------------------------
if [ -n "$APP_SLUG" ]; then
  sed -i.bak -E "s/(\"slug\": \").*(\")/\1${APP_SLUG}\2/" "$APP_JSON"
  # package.json は最初の "name"（トップレベル）だけを書き換える
  sed -i.bak -E "1,/\"name\":/ s/(\"name\": \").*(\")/\1${APP_SLUG}\2/" "$PKG_JSON"
  rm -f "$APP_JSON.bak" "$PKG_JSON.bak"
  echo "▶ slug 設定  : $APP_SLUG (app.json / package.json)"
fi
if [ -n "$APP_NAME" ]; then
  sed -i.bak -E "s/(\"name\": \").*(\")/\1${APP_NAME}\2/" "$APP_JSON"
  rm -f "$APP_JSON.bak"
  echo "▶ 表示名設定 : $APP_NAME (app.json)"
fi

echo ""
echo "✅ ファイル更新完了。次に push すると Expo Tunnel が起動し、#$ISSUE_NUMBER に通知が届きます。"
