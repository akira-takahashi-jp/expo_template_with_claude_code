#!/usr/bin/env bash
#
# Expo phone-only テンプレートの初回セットアップを自動化するスクリプト。
#
# やること:
#   1. gh の認証と対象リポジトリを確認
#   2. GitHub ユーザー名を検出（NOTIFY_USER）
#   3. トラッキング用 Issue を作成（既存番号を --issue で渡せばスキップ）
#   4. .github/workflows/expo-tunnel.yml の
#        STATUS_ISSUE_NUMBER / NOTIFY_USER / push.branches を書き換え
#   5. 指定があれば app.json / package.json の name・slug を変更
#
# 使い方:
#   configure.sh [--branch <dev-branch>] [--name <app-name>] [--slug <app-slug>] \
#                [--issue <既存Issue番号>] [--issue-title <タイトル>]
#
# 例:
#   configure.sh --branch develop --name "My App" --slug my-app
#
set -euo pipefail

BRANCH=""
APP_NAME=""
APP_SLUG=""
ISSUE_NUMBER=""
ISSUE_TITLE="Expo tunnel status"

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)      BRANCH="$2"; shift 2 ;;
    --name)        APP_NAME="$2"; shift 2 ;;
    --slug)        APP_SLUG="$2"; shift 2 ;;
    --issue)       ISSUE_NUMBER="$2"; shift 2 ;;
    --issue-title) ISSUE_TITLE="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/expo-tunnel.yml"
APP_JSON="$REPO_ROOT/app.json"
PKG_JSON="$REPO_ROOT/package.json"

# --- 1. 前提チェック ------------------------------------------------------
command -v gh >/dev/null 2>&1 || { echo "❌ gh CLI が見つかりません。https://cli.github.com/ を参照。" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "❌ GitHub 未ログインです。先に:  gh auth login" >&2; exit 1; }
[ -f "$WORKFLOW" ] || { echo "❌ $WORKFLOW が見つかりません。テンプレートのルートで実行してください。" >&2; exit 1; }

REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

# --- 2. ユーザー名検出 ----------------------------------------------------
NOTIFY_USER="$(gh api user --jq .login)"
echo "▶ リポジトリ : $REPO"
echo "▶ NOTIFY_USER: $NOTIFY_USER"

# --- 3. トラッキング用 Issue ----------------------------------------------
if [ -z "$ISSUE_NUMBER" ]; then
  ISSUE_URL="$(gh issue create --repo "$REPO" --title "$ISSUE_TITLE" \
    --body $'Expo トンネルの状態通知用の Issue です。\n\nExpo Tunnel ワークフローが実行されるたびに、この Issue に `exp://` URL とスキャン用の QR コードがコメントされます。クローズしないでください。')"
  ISSUE_NUMBER="$(basename "$ISSUE_URL")"
  echo "▶ Issue 作成 : #$ISSUE_NUMBER ($ISSUE_URL)"
else
  echo "▶ Issue 既存 : #$ISSUE_NUMBER を使用"
fi

# --- 4. workflow を書き換え -----------------------------------------------
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

# --- 5. アプリ名（任意） --------------------------------------------------
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
echo "✅ セットアップ完了。次に push すると Expo Tunnel が起動し、#$ISSUE_NUMBER に通知が届きます。"
