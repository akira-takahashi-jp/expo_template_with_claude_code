---
name: setup-supabase
description: Bootstrap a Supabase backend for this Expo project — creates the Supabase project via the Management API (curl), fetches the publishable key, and wires up an @supabase/supabase-js client. Requires the user to have already set SUPABASE_ACCESS_TOKEN. Use when the user wants to add Supabase, needs a backend/database/auth, or asks to "set up Supabase".
---

# Supabase プロジェクトの初回セットアップ

このプロジェクトに Supabase バックエンド（Postgres DB / Auth / Storage）を
立ち上げる。PC 不要、スマホ + Claude Code のみで完結する。テンプレートの
基本ファイルには何も先回りして追加していない。このスキルを実行したときだけ
Supabase 関連の依存・ファイルが増える。

## 重要：CLI ではなく Management API（curl）を使う

`supabase` CLI は Bun 製バイナリで、Claude Code on the web のセキュリティ
プロキシ（全通信を TLS 再暗号化する）と**非互換**。実行すると証明書を信頼
できず `TransportError` で失敗する（公式ドキュメントでも「Bun は既知の非互換
例」と明記）。そのためこのスキルは **CLI を使わず、`api.supabase.com` の
Management API を curl で叩く**。curl はプロキシの CA を信頼できるので確実に動く。

## 実行手順

### 1. 前提を確認する

- カレントがこのリポジトリのルートか。
- `SUPABASE_ACCESS_TOKEN` が環境変数として設定済みか：
  ```sh
  [ -n "$SUPABASE_ACCESS_TOKEN" ] && echo set || echo missing
  ```
  `missing` の場合は中断し、ユーザーに README の
  「Supabase パーソナルアクセストークンの取得」手順（`supabase.com/dashboard/account/tokens`
  で発行 → この Claude Code 環境の環境変数として `SUPABASE_ACCESS_TOKEN` を設定）
  を案内する。**トークンの値をチャットに貼り付けさせないこと**（会話ログに残る）。
- `api.supabase.com` への到達性があるか（ネットワークポリシー）。後述の org 一覧
  取得が `host not permitted` で失敗する場合は、環境のネットワーク設定で
  `api.supabase.com` / `*.supabase.co` を許可する必要がある（README 参照）。

curl はこのスキル内で常にプロキシの CA を明示的に信頼させる：
`--cacert /root/.ccr/ca-bundle.crt`（存在すれば）を付けると確実。

### 2. 組織 ID を取得する

```sh
curl -sS --cacert /root/.ccr/ca-bundle.crt \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  https://api.supabase.com/v1/organizations
```
`[{"id":"...","slug":"...","name":"..."}]` が返る。1件なら自動採用、複数なら
`AskUserQuestion` でユーザーに選ばせる。この `id` を次で使う。

### 3. 設定値をユーザーに確認する

`AskUserQuestion` で：
- **プロジェクト名**（デフォルト: `package.json` の `name`）。
- **リージョン**（デフォルト `ap-northeast-1` 東京）。
- **DB パスワード**：基本は自動生成を推奨。指定があればそれを使う。

DB パスワードの自動生成例：
```sh
node -e "console.log(require('crypto').randomBytes(18).toString('base64').replace(/[^A-Za-z0-9]/g,'').slice(0,24))"
```
生成値は最後の報告で必ずユーザーに提示する（リポジトリには書き込まない）。

### 4. プロジェクトを作成し接続情報を得る

このスキルと同じフォルダの `create_project.sh` を実行する。Management API で
プロジェクトを作成 → 稼働待ち → 公開キー取得までを行い、`.env` 形式3行を
標準出力に返す：

```sh
.claude/skills/setup-supabase/create_project.sh \
  --name "<name>" --org-id "<org-id>" --db-password "<pw>" --region ap-northeast-1
```

出力例（最後の3行）：
```
EXPO_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=<publishable-key>
SUPABASE_PROJECT_REF=<ref>
```
この URL と ANON_KEY を次のステップで使う。

### 5. クライアントを配線する

`scaffold.sh` を、取得した値で実行する：
```sh
.claude/skills/setup-supabase/scaffold.sh --url "https://<ref>.supabase.co" --anon-key "<publishable-key>"
```
やること：`.env`（gitignore 対象）と `.env.example`（コミット対象）を作成 →
`.gitignore` に `.env` を追加 → `@supabase/supabase-js` と
`@react-native-async-storage/async-storage` を `expo install` →
`lib/supabase.ts` を作成。

### 6. 型チェックする

```sh
npx tsc --noEmit
```

### 7. 結果を報告する

- プロジェクト ref とダッシュボード URL（`https://supabase.com/dashboard/project/<ref>`）。
- 生成した DB パスワード（再掲、控えるよう伝える）。
- `.env` はローカルにのみ存在しコミットされないこと。
- 次はテーブル定義がしたければ `/migrate-supabase` を使うこと。

## 注意

- `EXPO_PUBLIC_` 接頭辞が付いた環境変数だけが Expo のバンドルに埋め込まれる。
  そのため `.env` に置く値は公開前提のもの（`anon` / `publishable` キー）に限る。
  `service_role` / `secret` キーを `EXPO_PUBLIC_` 変数にしないこと。
- `create_project.sh` は Management API のキー一覧から `type=publishable` または
  `name=anon` のキーだけを選ぶ（秘密キーは拾わない）。
- プロビジョニングに時間がかかり `link`/キー取得が早すぎると失敗することがある。
  スクリプトは `ACTIVE_HEALTHY` を最大 300s 待つ。タイムアウトしたら少し置いて
  再実行する（作成済みプロジェクトは Management API またはダッシュボードで確認）。
- このスキルは一度きり。既に `.env` と `lib/supabase.ts` があれば再実行不要。
