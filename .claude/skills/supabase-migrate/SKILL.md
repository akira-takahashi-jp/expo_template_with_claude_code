---
name: supabase-migrate
description: Write a Supabase database migration (SQL), apply it to the remote project via the Management API, and regenerate TypeScript types for the Expo app. Use when the user wants to add/change a table, column, or RLS policy in Supabase, or asks to run a migration or regenerate Supabase types. Requires /supabase-setup to have been run first.
---

# Supabase マイグレーションの作成・適用・型生成

Supabase のスキーマ変更（テーブル追加・カラム変更・RLS ポリシーなど）を書いて
リモート DB に反映し、Expo 側の TypeScript 型を最新化する。`/supabase-setup`
実行後、繰り返し使う。

## 重要：CLI ではなく Management API（curl）を使う

`supabase` CLI（`db push` / `gen types`）は Bun 製で Claude Code on the web の
プロキシと TLS 非互換のため使えない。代わりに Management API を curl で叩く：
- SQL 適用 … `POST /v1/projects/<ref>/database/query`
- 型生成   … `GET  /v1/projects/<ref>/types/typescript`

適用済みバージョンは `supabase_migrations.schema_migrations` テーブルで管理する
（CLI と同じ場所）。project ref は `.env` の `EXPO_PUBLIC_SUPABASE_URL` から
自動導出される。

## 実行手順

### 1. 前提を確認する

- `.env` が存在するか（無ければ `/supabase-setup` を先に）。
- `SUPABASE_ACCESS_TOKEN` が設定されているか。

### 2. マイグレーションファイルを作成する

依頼内容から分かりやすいスネークケース名を決め、タイムスタンプ付きで空ファイルを
作る（CLI は使わず `date` で採番する）：
```sh
mkdir -p supabase/migrations
f="supabase/migrations/$(date -u +%Y%m%d%H%M%S)_<migration_name>.sql"
touch "$f"; echo "$f"
```

### 3. SQL を書く

作成したファイルを `Edit`/`Write` で編集し、依頼内容の SQL を書く。方針：
- 主キー・`created_at timestamptz default now()` などの基本カラムを入れる。
- `alter table ... enable row level security;` で RLS を有効化し、用途に応じた
  最小限のポリシーを併記する（RLS 有効化 + ポリシー無し = 全拒否になる点に注意し、
  意図をユーザーに確認する）。
- ファイルは追記のみ。過去のマイグレーションは書き換えない。

### 4. 適用して型を再生成する

`push.sh` を実行する（先に対象確認だけなら `--dry-run`）：
```sh
.claude/skills/supabase-migrate/push.sh
```
やること：`supabase_migrations.schema_migrations` を用意 → 未適用の `.sql` を
`database/query` で順に適用し、バージョンを記録 →
`types/typescript` で `lib/database.types.ts` を再生成 → `npx tsc --noEmit`。

### 5. クライアントの型を最新化する（初回のみ）

`lib/supabase.ts` がまだ `Database` 型を使っていなければ差し替える：
```ts
import type { Database } from './database.types';
// ...
export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, { ... });
```

### 6. 結果を報告する

- 作成したマイグレーションのパスと SQL の要約。
- 適用結果（成功件数・エラー内容）。
- `lib/database.types.ts` の再生成結果と `tsc` の結果。

## 注意

- `database/query` は送った SQL をそのまま実行する。破壊的な操作
  （`drop` / `truncate` など）は事前にユーザーへ確認する。
- 適用は「未適用ファイルのみ」。既に記録済みのバージョンはスキップされる。
  一度適用した内容を変えたい場合は、新しいマイグレーションを追加して打ち消す。
- ローカル Docker（`supabase start`）は使わない前提。常にリモートの
  リンク済みプロジェクトに対して直接適用する。
