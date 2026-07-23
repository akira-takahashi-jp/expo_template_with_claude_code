---
name: supabase-setup
description: Bootstrap a Supabase backend for this Expo project — creates the Supabase project via CLI, links it locally, and wires up an @supabase/supabase-js client with env vars. Requires the user to have already set SUPABASE_ACCESS_TOKEN. Use when the user wants to add Supabase, needs a backend/database/auth, or asks to "set up Supabase".
---

# Supabase プロジェクトの初回セットアップ

このプロジェクトに Supabase バックエンド（Postgres DB / Auth / Storage）を
全て CLI だけで立ち上げる。PC 不要、スマホ + Claude Code のみで完結する。
このテンプレートの基本ファイル（`package.json` の依存など）には何も
先回りして追加していない。このスキルを実行したときだけ Supabase 関連の
依存・ファイルが増える。

## 実行手順

### 1. 前提を確認する

- カレントがこのリポジトリのルートか。
- `SUPABASE_ACCESS_TOKEN` が環境変数として設定済みか：
  ```sh
  [ -n "$SUPABASE_ACCESS_TOKEN" ] && echo set || echo missing
  ```
  `missing` の場合は中断し、ユーザーに README の「Supabase パーソナルアクセストークンの取得」手順
  （`supabase.com/dashboard/account/tokens` でトークン発行 → この Claude Code
  環境の環境変数として `SUPABASE_ACCESS_TOKEN` を設定）を案内する。
  **トークンの値をチャットに直接貼り付けさせないこと** —— 会話ログに残ってしまう。
  環境変数として設定してもらい、このセッションから `$SUPABASE_ACCESS_TOKEN` で
  参照できる状態にしてから再度呼び出してもらう。
- `npx -y supabase --version` が通るか（初回はダウンロードが走る）。

### 2. プロジェクトの設定値をユーザーに確認する

`AskUserQuestion` などで以下を確認する：

- **プロジェクト名**（デフォルト: `package.json` の `name`）。
- **リージョン**（デフォルト `ap-northeast-1` 東京。他の選択肢は
  `npx -y supabase projects create --help` の `--region` 一覧を参照）。
- **DB パスワード**：基本は自動生成を推奨する（下記手順4で生成）。ユーザーが
  指定したい場合はそれを使う。

組織（org）は `npx -y supabase orgs list` で一覧を取得する。1件しかなければ
自動選択し、複数あれば `AskUserQuestion` でユーザーに選ばせる。

### 3. DB パスワードを用意する

ユーザーが指定しなければ自動生成する（例）：
```sh
node -e "console.log(require('crypto').randomBytes(18).toString('base64').replace(/[^A-Za-z0-9]/g,'').slice(0,24))"
```
生成した値は最後の報告で必ずユーザーに提示する（`supabase link` 以降でしか
使わないが、後で直接 psql 接続したい場合に必要になるため）。**リポジトリには
書き込まない。**

### 4. Supabase プロジェクトを作成する

```sh
npx -y supabase projects create "<name>" --org-id <org-id> --db-password "<password>" --region <region>
```

出力からプロジェクト ref（`abcdefghijklmnopqrst` のような英数字ID）を読み取る。
プロジェクトのプロビジョニングは数十秒〜数分かかることがある。すぐ後の
`link` が失敗する場合は少し待って再実行する。

### 5. ローカルに初期化する

`supabase/config.toml` がまだ無い場合のみ実行する（既にあれば飛ばす）：
```sh
npx -y supabase init
```

### 6. プロジェクトをリンクする

```sh
npx -y supabase link --project-ref <ref> --password "<password>" --yes
```

### 7. API キーを取得する

```sh
npx -y supabase projects api-keys --project-ref <ref>
```
出力から公開用キー（`anon` または `publishable` という名前のもの。
`service_role` / `secret` は絶対に使わない — クライアントに埋め込まれるため）
を読み取る。URL は `https://<ref>.supabase.co`。

### 8. クライアントを配線する

このスキルと同じフォルダの `scaffold.sh` を、取得した値で実行する：
```sh
.claude/skills/supabase-setup/scaffold.sh --url "https://<ref>.supabase.co" --anon-key "<anon-or-publishable-key>"
```

スクリプトがやること：`.env`（gitignore 対象）と `.env.example`
（コミット対象）を作成 → `.gitignore` に `.env` を追加 →
`@supabase/supabase-js` と `@react-native-async-storage/async-storage` を
`expo install` → `lib/supabase.ts` を作成。

### 9. 型チェックする

```sh
npx tsc --noEmit
```

### 10. 結果を報告する

- プロジェクト ref とダッシュボード URL（`https://supabase.com/dashboard/project/<ref>`）。
- 生成した DB パスワード（再掲、控えておくよう伝える）。
- `.env` はローカルにのみ存在しコミットされないこと。
- 次はテーブル定義がしたければ `/supabase-migrate` を使うこと。

## 注意

- `EXPO_PUBLIC_` 接頭辞が付いた環境変数だけが Expo のバンドルに埋め込まれる。
  そのためこれらの値はクライアントから見えて当然のもの（`anon` キー）に限る。
  `service_role` キーやその他の秘密情報を `EXPO_PUBLIC_` 変数にしないこと。
- ネットワークポリシーで外向き通信が制限されている環境では、
  `api.supabase.com` / `*.supabase.co` への到達性が必要になる。
- このスキルは一度きりの初回セットアップ用。既にリンク済みなら再実行不要
  （`supabase/config.toml` と `.env` の有無で判断する）。
