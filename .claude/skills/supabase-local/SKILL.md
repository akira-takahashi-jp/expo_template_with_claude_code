---
name: supabase-local
description: Set up and use a local Supabase stack (supabase start via the CLI + Docker) on the user's PC, as a local-development alternative to the hosted Management-API flow. Prepares supabase/config.toml and .env.local.example, and guides the user through running the local stack, applying migrations, and generating types locally. Use when the user wants to run Supabase locally, develop against a local DB, or asks for `supabase start` / local Supabase.
---

# Supabase をローカルで起動して開発する（PC 向け）

ユーザーの PC 上で Supabase をローカル起動（`supabase start`＝CLI + Docker）し、
Expo アプリをそのローカルスタックに向けて開発するための手順。ホスト型
（`/setup-supabase` の Management API 経由）に対する、PC 向けのローカル開発ループ。

## 大前提：ローカルスタックと CLI は「ユーザーの PC」で動かす

- Claude Code のセッションは**リモート実行環境**で動いており、そこには Docker が
  無く、さらに `supabase` CLI（Bun 製）はこの環境のプロキシと TLS 非互換で動かない
  （テンプレートがホスト型で Management API + curl を使っている理由）。
- **一方、ユーザーの PC 上では `supabase` CLI が正規かつ唯一の手段**。ローカルの
  Postgres/Auth/Storage スタックを立てる Management API は存在しないため、
  `supabase start` は必ずユーザーが手元で実行する。

したがってこのスキルの役割は `/start-local` と同じ 2 本立て：

1. **Claude 側で設定ファイルを用意する** —— `supabase/config.toml` と
   `.env.local.example` を作成・コミットし、ローカル起動できる状態を整える。
2. **ユーザーの PC で実行するコマンドを案内する** —— CLI / Docker の導入、
   `supabase start`、マイグレーション適用、型生成はユーザーが手元で行う。

ホスト型（`/setup-supabase` / `/migrate-supabase`）とローカルは**併用できる**。
マイグレーション SQL（`supabase/migrations/*.sql`）は両者で共通に使える。

## 実行手順

### 1. 前提を確認する

- `supabase/migrations/` があるか（無くても可。まだテーブルが無いだけ）。
- ホスト型の `.env`（`EXPO_PUBLIC_SUPABASE_URL` 等）が既にあるかを見る。あっても
  問題ない —— ローカルは後述の `.env.local` で**上書き**する（`.env.local` は `.env`
  より優先され、かつ gitignore 済み）。
- クライアント配線（`lib/supabase.ts`）がまだ無ければ、先に `/setup-supabase` を
  実行してもらう（もしくは `scaffold.sh` 相当でクライアントだけ用意する）。ローカル
  でもアプリ側のクライアントコードは共通で、env の値だけが変わる。

### 2. `supabase/config.toml` を作成する

CLI の `supabase start` はリポジトリ直下の `supabase/config.toml` を読む。Claude の
環境では CLI を回せないので、最小構成の config.toml を直接書き出す。`project_id` は
`package.json` の `name`（無ければ `expo-app`）にする：

```sh
mkdir -p supabase
```

`supabase/config.toml`（`PROJECT_ID` を実際の名前に置換して `Write`）:

```toml
# ローカル開発用の最小構成。`supabase start` が読み込む。
# CLI のバージョンによって受け付けるキーが異なる場合は、手元で `supabase init`
# を一度実行すると、その CLI 用の完全な config.toml が再生成される。
project_id = "PROJECT_ID"

[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000

[db]
port = 54322
shadow_port = 54320
major_version = 15

[studio]
enabled = true
port = 54323

[auth]
enabled = true
site_url = "http://127.0.0.1:3000"

[realtime]
enabled = true

[storage]
enabled = true
```

### 3. `.env.local.example` を作成する

ローカルスタックへ向けるための上書き env のテンプレートを作る（`.env.local` 本体は
接続情報がユーザー環境依存なので、ユーザーが手元でコピーして作る）。`Write` で
`.env.local.example` を作成：

```sh
# .env.local.example の内容
# ------------------------------------------------------------------
# ローカルの Supabase（supabase start）に接続するための上書き設定。
# 使い方: このファイルを .env.local にコピーして値を埋める。
#   - .env.local は .gitignore 済み（.env*.local）。コミットされない。
#   - .env.local は .env より優先して読み込まれる（= ローカルへの切替スイッチ）。
#   - ホスト型に戻すときは .env.local をリネーム/削除するだけ。
#
# EXPO_PUBLIC_SUPABASE_URL の値は「アプリをどこで動かすか」で変わる:
#   iOS シミュレータ        … http://127.0.0.1:54321
#   Android エミュレータ    … http://10.0.2.2:54321
#   スマホ実機（同一 LAN）  … http://<PC の LAN IP>:54321（例 http://192.168.1.10:54321）
#
# EXPO_PUBLIC_SUPABASE_ANON_KEY は `supabase start`（または `supabase status`）が
# 出力する anon key をそのまま貼る。ローカル固定のキーで公開しても問題ない。
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=<supabase start が表示する anon key を貼る>
```

`.gitignore` に `.env*.local` が既にあることを確認する（テンプレート標準で入って
いる）。無ければ追加する。

### 4. これらをコミットする

`supabase/config.toml` と `.env.local.example` をコミット・push する
（`.env.local` 本体はコミットしない）。

### 5. ユーザーの PC 向け手順を案内する

以下をユーザーに自分の PC で実行してもらう。

**準備（初回のみ）:**
- Docker Desktop（または互換の Docker）を起動しておく。
- `supabase` CLI を入れる（例: macOS `brew install supabase/tap/supabase`、
  npm 経由なら `npx supabase ...`）。

**起動と接続情報の取得:**
```sh
supabase start          # 初回はイメージ取得で数分。API URL と anon key を出力する
```
- 出力された **API URL**（既定 `http://127.0.0.1:54321`）と **anon key** を控える。
- `.env.local.example` を `.env.local` にコピーし、手順3のガイドに従って URL
  （実機なら PC の LAN IP）と anon key を記入する。
- Metro を再起動（`npm start`）すると `.env.local` が読み込まれ、アプリはローカル
  Supabase を向く。

**マイグレーションの適用（`supabase/migrations/*.sql`）:**
```sh
supabase migration up            # 未適用分をローカル DB に適用
# あるいは全部作り直すなら:
supabase db reset                # ローカル DB を初期化して全マイグレーションを再適用
```

**型の生成（ローカルスキーマから）:**
```sh
supabase gen types typescript --local > lib/database.types.ts
```

**停止:**
```sh
supabase stop
```

### 6. 結果を報告する

- 作成した `supabase/config.toml` / `.env.local.example` のパス。
- ユーザー PC 側の手順（`supabase start` → `.env.local` 記入 → `npm start`）の要約。
- 実機で使う場合は URL を PC の LAN IP にする必要がある点。
- ホスト型に戻すには `.env.local` を外すだけ、という点。

## 注意

- **`.env.local` は必ず gitignore 対象**（接続情報・環境依存）。逆に
  `.env.local.example` と `config.toml` はコミットする。
- **マイグレーション SQL は共通**。新しいテーブル/カラムを足すときは
  `/migrate-supabase` で `supabase/migrations/<timestamp>_<name>.sql` を作れば、
  ローカル（`supabase migration up`）にもホスト型（`push.sh`）にも同じように適用
  できる。ファイル名は 14 桁タイムスタンプ + スネークケースで CLI 互換。
- **型ファイルは 1 つ**（`lib/database.types.ts`）。ローカルとホストでスキーマが
  一致していれば内容は同じ。切替時に型がズレたら、向いている環境で再生成する。
- **SDK 固定方針は変えない**（`CLAUDE.md` 参照）。ローカル DB を使うかどうかは
  Expo SDK とは無関係。
- config.toml を CLI が受け付けない場合は、手元で `supabase init`（config.toml が
  無い状態で実行）すると、その CLI バージョン用の完全版が生成される。既存の
  config.toml があるとスキップされるので、必要ならリネームしてから実行する。
