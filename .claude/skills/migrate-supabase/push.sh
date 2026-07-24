#!/usr/bin/env bash
#
# supabase/migrations/*.sql の未適用分をリモート DB に適用し、TypeScript の型を
# 再生成する。Management API（curl）経由なので Bun 製 CLI は使わない
# （CLI は Claude Code on the web のプロキシと TLS 非互換で失敗するため）。
#
# 適用済みバージョンは supabase_migrations.schema_migrations テーブルで管理する
# （Supabase CLI と同じ場所）。
#
# 必要な環境変数:
#   SUPABASE_ACCESS_TOKEN  … パーソナルアクセストークン（sbp_...）
#
# プロジェクト ref は .env の EXPO_PUBLIC_SUPABASE_URL から自動導出する。
#
# 使い方:
#   push.sh [--dry-run]
#
set -euo pipefail

DRY_RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

[ -n "${SUPABASE_ACCESS_TOKEN:-}" ] || { echo "❌ SUPABASE_ACCESS_TOKEN が未設定です。" >&2; exit 1; }
[ -f .env ] || { echo "❌ .env が見つかりません。先に /setup-supabase を実行してください。" >&2; exit 1; }

# --- ref を .env から導出 ---------------------------------------------------
URL="$(grep -E '^EXPO_PUBLIC_SUPABASE_URL=' .env | head -1 | cut -d= -f2- | tr -d "\"'")"
REF="$(printf '%s' "$URL" | sed -E 's#https?://([^.]+)\.supabase\.co/?#\1#')"
[ -n "$REF" ] || { echo "❌ .env の EXPO_PUBLIC_SUPABASE_URL から project ref を取得できません。" >&2; exit 1; }
echo "▶ project ref=$REF"

MIG_DIR="supabase/migrations"
[ -d "$MIG_DIR" ] || { echo "❌ $MIG_DIR がありません。マイグレーションを作成してから実行してください。" >&2; exit 1; }

API="https://api.supabase.com"
CA_ARGS=()
for c in "${SUPABASE_CA_BUNDLE:-}" /root/.ccr/ca-bundle.crt; do
  [ -n "$c" ] && [ -f "$c" ] && { CA_ARGS=(--cacert "$c"); break; }
done

# SQL を1本流す。成功なら 200、失敗なら API のエラーメッセージを表示して非0終了。
run_sql() {
  local sql="$1"
  local payload http body tmp
  payload="$(python3 -c "import json,sys; print(json.dumps({'query': sys.stdin.read()}))" <<<"$sql")"
  tmp="$(mktemp)"
  http="$(curl -sS "${CA_ARGS[@]}" -o "$tmp" -w '%{http_code}' \
        -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST "$API/v1/projects/$REF/database/query" -d "$payload")"
  if [ "$http" -lt 200 ] || [ "$http" -ge 300 ]; then
    echo "❌ SQL 実行失敗 (HTTP $http):" >&2
    cat "$tmp" >&2; echo >&2
    rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"; return 0
}

# --- 適用済みバージョンを取得（テーブルが無ければ作る） --------------------
ensure_tracking() {
  run_sql "create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  name text,
  inserted_at timestamptz not null default now()
);"
}

applied_versions() {
  local payload tmp
  payload='{"query":"select version from supabase_migrations.schema_migrations order by version;","read_only":true}'
  tmp="$(mktemp)"
  curl -sS "${CA_ARGS[@]}" -o "$tmp" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -H "Content-Type: application/json" \
    -X POST "$API/v1/projects/$REF/database/query" -d "$payload" >/dev/null 2>&1 || true
  python3 -c "import sys,json
try:
    d=json.load(open('$tmp'))
    rows=d if isinstance(d,list) else d.get('result',d.get('rows',[]))
    print('\n'.join(r['version'] for r in rows if isinstance(r,dict) and r.get('version')))
except Exception:
    pass" 2>/dev/null
  rm -f "$tmp"
}

# --- 未適用マイグレーションを列挙 ------------------------------------------
shopt -s nullglob
FILES=("$MIG_DIR"/*.sql)
shopt -u nullglob
[ ${#FILES[@]} -gt 0 ] || { echo "▶ 適用対象の .sql がありません。"; }

if [ -n "$DRY_RUN" ]; then
  echo "▶ [dry-run] 以下のファイルが対象です（適用はしません）:"
  for f in "${FILES[@]}"; do echo "   - $(basename "$f")"; done
  exit 0
fi

ensure_tracking || { echo "❌ 追跡テーブルの初期化に失敗。" >&2; exit 1; }
APPLIED="$(applied_versions)"

pending=0
for f in "${FILES[@]}"; do
  base="$(basename "$f")"
  version="$(printf '%s' "$base" | sed -E 's/^([0-9]+)_.*/\1/')"
  if printf '%s\n' "$APPLIED" | grep -qx "$version"; then
    echo "▶ skip（適用済み）: $base"
    continue
  fi
  echo "▶ 適用: $base"
  run_sql "$(cat "$f")" || { echo "❌ $base の適用に失敗。中断します。" >&2; exit 1; }
  name="$(printf '%s' "$base" | sed -E 's/^[0-9]+_//; s/\.sql$//')"
  run_sql "insert into supabase_migrations.schema_migrations(version,name) values ('$version','$name') on conflict (version) do nothing;" \
    || echo "⚠️ $base は適用できましたが記録に失敗しました。" >&2
  pending=$((pending+1))
done
echo "▶ 適用件数: $pending"

# --- 型生成 ----------------------------------------------------------------
echo "▶ TypeScript 型を再生成: lib/database.types.ts"
mkdir -p lib
TYPES_TMP="$(mktemp)"
curl -sS "${CA_ARGS[@]}" -o "$TYPES_TMP" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  "$API/v1/projects/$REF/types/typescript?included_schemas=public"
python3 -c "import sys,json;print(json.load(open('$TYPES_TMP'))['types'],end='')" > lib/database.types.ts \
  || { echo "❌ 型生成の応答をパースできませんでした:" >&2; cat "$TYPES_TMP" >&2; rm -f "$TYPES_TMP"; exit 1; }
rm -f "$TYPES_TMP"

# --- 型チェック ------------------------------------------------------------
echo "▶ tsc で型チェック..."
npx tsc --noEmit

echo ""
echo "✅ 適用 + 型生成が完了しました。lib/database.types.ts の差分を確認してください。"
