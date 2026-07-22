---
name: supabase-migrate
description: Write a Supabase database migration (SQL), push it to the linked remote project, and regenerate TypeScript types for the Expo app. Use when the user wants to add/change a table, column, or RLS policy in Supabase, or asks to run a migration or regenerate Supabase types. Requires /supabase-setup to have been run first.
---

# Supabase マイグレーションの作成・push・型生成

Supabase のスキーマ変更（テーブル追加・カラム変更・RLS ポリシーなど）を
書いて、リンク済みのリモート DB に反映し、Expo 側の TypeScript 型を
最新化する。`/supabase-setup` 実行後、繰り返し使うスキル。

## 実行手順

### 1. 前提を確認する

- `supabase/config.toml` が存在するか。無ければ `/supabase-setup` を先に
  実行するよう案内して中断する。
- `SUPABASE_ACCESS_TOKEN` が設定されているか（`/supabase-setup` と同様の確認）。

### 2. マイグレーションファイルを作成する

依頼内容から分かりやすいスネークケース名を決め、空ファイルを作る：
```sh
npx -y supabase migration new <migration_name>
```
`supabase/migrations/<timestamp>_<migration_name>.sql` が生成される。

### 3. SQL を書く

生成されたファイルを `Edit`/`Write` で編集し、依頼内容に沿った SQL を書く。
テーブルを追加する場合は基本方針として：
- 主キー・`created_at timestamptz default now()` などの基本カラムを入れる。
- Row Level Security を有効化し、用途に応じた最小限のポリシーを併記する
  （`alter table ... enable row level security;` を必ず入れる。ポリシー無しで
  RLS を有効化すると全アクセス拒否になる点に注意し、意図を確認する）。
- 既存マイグレーションとの整合性（同じテーブルへの重複定義など）を確認する。

### 4. push して型を再生成する

このスキルと同じフォルダの `push.sh` を実行する：
```sh
.claude/skills/supabase-migrate/push.sh
```
先に内容を確認したいだけなら `--dry-run` を付ける（適用はせず、適用予定の
SQL を表示するだけ）。

スクリプトがやること：`supabase db push --linked` でリモート DB に適用 →
`supabase gen types typescript --linked` で `lib/database.types.ts` を再生成
→ `npx tsc --noEmit` で型チェック。

### 5. クライアントの型を最新化する（初回のみ）

`lib/supabase.ts` がまだ `Database` 型を使っていなければ、次のように差し替える：
```ts
import type { Database } from './database.types';
// ...
export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, { ... });
```

### 6. 結果を報告する

- 作成したマイグレーションファイルのパスと SQL の要約。
- `db push` の結果（成功・エラー内容）。
- `lib/database.types.ts` の再生成結果と `tsc` の結果。

## 注意

- マイグレーションは追記のみ（過去のファイルを書き換えない）。スキーマ変更は
  常に新しい `supabase migration new` で追加する。
- `db push` がリモートの migration history と食い違う場合、CLI が
  差分を提示する。安易に `--include-all` で押し切らず、内容を確認してから
  ユーザーに確認する。
- ローカル Docker（`supabase start`）は使わない前提（PC 不要方針のため）。
  常にリモートのリンク済みプロジェクトに対して直接 `db push` する。
