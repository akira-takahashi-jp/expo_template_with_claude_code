#!/usr/bin/env bash
#
# 既存のマイグレーションをリンク済みのリモート DB に push し、TypeScript の型を
# 再生成する。マイグレーションファイル自体の作成・編集（SQL の中身）はこの
# スクリプトの前に `supabase migration new <name>` + Claude による編集で行う。
#
# 使い方:
#   push.sh [--dry-run]
#
set -euo pipefail

DRY_RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN="--dry-run"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

[ -n "${SUPABASE_ACCESS_TOKEN:-}" ] || { echo "❌ SUPABASE_ACCESS_TOKEN が未設定です。" >&2; exit 1; }
[ -f supabase/config.toml ] || { echo "❌ supabase/ が未初期化です。先に /supabase-setup を実行してください。" >&2; exit 1; }

echo "▶ リモート DB へマイグレーションを push..."
if [ -n "$DRY_RUN" ]; then
  npx -y supabase db push --linked --yes --dry-run
  echo "▶ --dry-run のため型生成はスキップしました。"
  exit 0
fi

npx -y supabase db push --linked --yes

echo "▶ 型を再生成: lib/database.types.ts"
mkdir -p lib
npx -y supabase gen types typescript --linked --schema public > lib/database.types.ts

echo "▶ tsc で型チェック..."
npx tsc --noEmit

echo ""
echo "✅ push + 型生成が完了しました。lib/database.types.ts の差分を確認してください。"
