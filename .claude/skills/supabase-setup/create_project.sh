#!/usr/bin/env bash
#
# Supabase プロジェクトを Management API 経由（curl）で作成し、稼働待ちしてから
# 接続情報（URL / 公開キー）を出力する。
#
# なぜ CLI ではなく curl か:
#   `supabase` CLI は Bun 製バイナリで、Claude Code on the web のセキュリティ
#   プロキシ（TLS 再暗号化）と非互換のため TransportError で失敗する。
#   curl はプロキシの CA を信頼できるので Management API が確実に動く。
#
# 必要な環境変数:
#   SUPABASE_ACCESS_TOKEN  … パーソナルアクセストークン（sbp_...）
#
# 使い方:
#   create_project.sh --name <name> --org-id <org> --db-password <pw> [--region <region>]
#
# 出力（最後の行）:
#   .env 形式の3行（EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY / SUPABASE_PROJECT_REF）
#
set -euo pipefail

NAME=""
ORG=""
DB_PW=""
REGION="ap-northeast-1"

while [ $# -gt 0 ]; do
  case "$1" in
    --name)        NAME="$2"; shift 2 ;;
    --org-id)      ORG="$2"; shift 2 ;;
    --db-password) DB_PW="$2"; shift 2 ;;
    --region)      REGION="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ -n "${SUPABASE_ACCESS_TOKEN:-}" ] || { echo "❌ SUPABASE_ACCESS_TOKEN が未設定です。" >&2; exit 1; }
[ -n "$NAME" ]  || { echo "❌ --name が必要です。" >&2; exit 1; }
[ -n "$ORG" ]   || { echo "❌ --org-id が必要です。" >&2; exit 1; }
[ -n "$DB_PW" ] || { echo "❌ --db-password が必要です。" >&2; exit 1; }

API="https://api.supabase.com"

# --- curl ラッパー（プロキシの CA を明示的に信頼する） -----------------------
CA_ARGS=()
for c in "${SUPABASE_CA_BUNDLE:-}" /root/.ccr/ca-bundle.crt; do
  [ -n "$c" ] && [ -f "$c" ] && { CA_ARGS=(--cacert "$c"); break; }
done
scurl() { curl -sS "${CA_ARGS[@]}" -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" "$@"; }

# --- 1. プロジェクト作成 ---------------------------------------------------
echo "▶ プロジェクトを作成中: name=$NAME org=$ORG region=$REGION" >&2
BODY="$(python3 -c "import json,sys; print(json.dumps({'name':sys.argv[1],'organization_id':sys.argv[2],'organization_slug':sys.argv[2],'db_pass':sys.argv[3],'region':sys.argv[4]}))" "$NAME" "$ORG" "$DB_PW" "$REGION")"

RESP="$(scurl -X POST "$API/v1/projects" -H "Content-Type: application/json" -d "$BODY")"
REF="$(printf '%s' "$RESP" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('ref') or d.get('id') or '')" 2>/dev/null || true)"

if [ -z "$REF" ]; then
  echo "❌ プロジェクト作成に失敗しました。API 応答:" >&2
  printf '%s\n' "$RESP" >&2
  exit 1
fi
echo "▶ 作成成功: ref=$REF" >&2

# --- 2. 稼働待ち -----------------------------------------------------------
echo "▶ プロビジョニング待機（最大 300s）..." >&2
elapsed=0
while [ "$elapsed" -lt 300 ]; do
  STATUS="$(scurl "$API/v1/projects/$REF" | python3 -c "import sys,json;print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)"
  echo "  ...status=$STATUS (${elapsed}s)" >&2
  [ "$STATUS" = "ACTIVE_HEALTHY" ] && break
  sleep 15; elapsed=$((elapsed + 15))
done

# --- 3. API キー取得（公開キーのみ） ---------------------------------------
echo "▶ API キーを取得..." >&2
KEYS="$(scurl "$API/v1/projects/$REF/api-keys")"
ANON="$(printf '%s' "$KEYS" | python3 -c "
import sys,json
keys=json.load(sys.stdin)
# 公開してよいキーだけを選ぶ: type=publishable または name=anon。secret/service_role は除外。
pick=None
for k in keys:
    t=(k.get('type') or '').lower(); n=(k.get('name') or '').lower()
    if t=='publishable' or n=='anon':
        pick=k.get('api_key'); break
print(pick or '')
" 2>/dev/null || true)"

if [ -z "$ANON" ]; then
  echo "❌ 公開キー（anon / publishable）を取得できませんでした。API 応答:" >&2
  printf '%s\n' "$KEYS" >&2
  exit 1
fi

# --- 4. 結果出力（stdout に .env 形式） ------------------------------------
echo "EXPO_PUBLIC_SUPABASE_URL=https://${REF}.supabase.co"
echo "EXPO_PUBLIC_SUPABASE_ANON_KEY=${ANON}"
echo "SUPABASE_PROJECT_REF=${REF}"
