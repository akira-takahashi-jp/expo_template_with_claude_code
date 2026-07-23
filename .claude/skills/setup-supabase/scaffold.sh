#!/usr/bin/env bash
#
# Supabase クライアント一式を Expo 側に配線する（.env 生成・依存インストール・
# lib/supabase.ts 作成）。`supabase projects create` / `link` / `api-keys` の
# 実行と出力の読み取りは、このスクリプトを呼ぶ前に Claude が直接行う
# （CLI の出力形式に応じて柔軟にパースする必要があるため）。
#
# 使い方:
#   scaffold.sh --url <https://xxx.supabase.co> --anon-key <key>
#
set -euo pipefail

URL=""
ANON_KEY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --url)      URL="$2"; shift 2 ;;
    --anon-key) ANON_KEY="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ -n "$URL" ]      || { echo "❌ --url が必要です。" >&2; exit 1; }
[ -n "$ANON_KEY" ] || { echo "❌ --anon-key が必要です。" >&2; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# --- 1. .env / .env.example -------------------------------------------------
cat > .env <<EOF
EXPO_PUBLIC_SUPABASE_URL=${URL}
EXPO_PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}
EOF
echo "▶ .env を作成しました（.gitignore 対象、コミットしないこと）。"

if [ ! -f .env.example ]; then
  cat > .env.example <<'EOF'
EXPO_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-or-publishable-key
EOF
  echo "▶ .env.example を作成しました（コミット対象）。"
fi

if ! grep -qE '^\.env$' .gitignore 2>/dev/null; then
  printf '\n# Supabase\n.env\n' >> .gitignore
  echo "▶ .gitignore に .env を追加しました。"
fi

# --- 2. 依存インストール -----------------------------------------------------
# `expo install` は SDK 互換バージョンの解決に Expo のサーバーへアクセスするが、
# Claude Code on the web のプロキシ下では不安定（非 JSON 応答でクラッシュ）。
# 代わりに、SDK にピン留めされたネイティブモジュール版を node_modules/expo の
# bundledNativeModules.json（ローカル）から読み取り、npm で直接入れる。
if [ ! -d node_modules/expo ]; then
  echo "▶ node_modules が無いため npm install を実行..."
  npm install
fi

ASYNC_VER="$(python3 - <<'PY' 2>/dev/null || true
import json, glob
fs = glob.glob('node_modules/expo/bundledNativeModules.json')
if fs:
    print(json.load(open(fs[0])).get('@react-native-async-storage/async-storage', ''))
PY
)"

echo "▶ 依存パッケージをインストール中: @supabase/supabase-js @react-native-async-storage/async-storage${ASYNC_VER:+@$ASYNC_VER}"
if [ -n "$ASYNC_VER" ]; then
  npm install @supabase/supabase-js "@react-native-async-storage/async-storage@$ASYNC_VER"
else
  # ピン留め版が読めない場合のフォールバック（最終手段として expo install）
  npm install @supabase/supabase-js @react-native-async-storage/async-storage \
    || npx expo install @supabase/supabase-js @react-native-async-storage/async-storage
fi

# --- 3. lib/supabase.ts ------------------------------------------------------
mkdir -p lib
if [ ! -f lib/supabase.ts ]; then
  cat > lib/supabase.ts <<'EOF'
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY が未設定です。.env を確認してください。'
  );
}

// `/migrate-supabase` でマイグレーションを適用すると lib/database.types.ts が
// 生成される。生成後は `import type { Database } from './database.types'` を追加し、
// `createClient<Database>(...)` に差し替えると型付きクエリになる。
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
EOF
  echo "▶ lib/supabase.ts を作成しました。"
else
  echo "▶ lib/supabase.ts は既に存在するため変更しませんでした。"
fi

echo ""
echo "✅ Supabase クライアントの配線が完了しました。次は /migrate-supabase でテーブルを作成できます。"
