# Expo + Claude Code：スマホでも PC でも開発できるテンプレート

このリポジトリは、Expo / React Native アプリを **スマホと Claude Code だけ**で
開発できる（PC・Xcode・Android Studio 不要）ように作られたテンプレートです。
同時に、**手元の PC で普通にローカル開発する**こともできます —— 中身は標準的な
Expo プロジェクトなので、`npm install && npm start` でそのまま Metro が立ち上がり
ます。

- **スマホだけで開発する場合** … GitHub Actions 上で Expo トンネルを起動し、
  スマホの Expo Go で `exp://` URL / QR を開く（下記「仕組み」）。PC もローカル
  実行も不要。
- **PC で開発する場合** … 手元で `npm start`（`/start-local` スキル）を実行し、
  実機（同一 LAN の Expo Go）や iOS/Android シミュレータで開く。詳細は下記
  「PC でローカル開発する場合」を参照。

以下の「仕組み」はスマホだけで開発する場合の中心的な仕組みの説明です。

## 仕組み（スマホだけで開発する場合）

1. Claude Code（このセッション）がコードを編集し、コミットを push する。
2. `develop` への push（または Actions タブ／GitHub モバイルアプリからの
   **Expo Tunnel** ワークフロー手動実行）で
   `.github/workflows/expo-tunnel.yml` が起動する。
3. このワークフローが GitHub ホストランナー上で `npx expo start --tunnel`
   を実行し、トンネルが立ち上がるのを待ってから、トラッキング用 Issue に
   `exp://` URL とスキャン可能な QR コードをコメントする（自分宛メンション付き）。
   これは通常の GitHub 通知（ベル／メール）として届く。
4. スマホの Expo Go で QR コードを読み取る（または `exp://` リンクを直接開く）
   と、アプリがトンネル経由で読み込まれる。
5. トンネルは Actions UI からキャンセルするか、約 350 分経過するまで動き続ける。
   再度 push すると実行中のランは自動でキャンセルされる（固定の `concurrency`
   グループのため）。同時に 2 本以上のトンネルが立つことはない。

Codespaces／devcontainer のステップは無い。一度試したが取りやめた：Actions
ジョブ内で直接トンネルを動かせばパーソナルアクセストークンが不要で、
Codespaces の課金も発生せず、より単純に安定動作させられたため。

## このテンプレートから新しいリポジトリを作るときの初回セットアップ

**自動化あり:** `/init-project` スキル（`.claude/skills/init-project/`）を
使うと、以下を自動で実行できる —— GitHub MCP ツールでトラッキング用 Issue を
作成し、ログイン中のアカウント（`get_me`）から `NOTIFY_USER` を検出し、
`expo-tunnel.yml` の `STATUS_ISSUE_NUMBER` / `NOTIFY_USER` / `push.branches` を
書き換え、必要なら `app.json` / `package.json` のアプリ名も変更する。ユーザーが
初回セットアップを求めたら、まずこのスキルを使うこと。以下は同じ内容を手動で
行う場合の手順：

- 新リポジトリにトラッキング用の Issue を 1 つ作成し（タイトルは任意）、
  その番号を控える。
- `.github/workflows/expo-tunnel.yml` を編集する：
  - `env.STATUS_ISSUE_NUMBER` → その Issue の番号
  - `env.NOTIFY_USER` → 自分の GitHub ユーザー名
  - `push.branches` のリスト → `develop` 以外を使うなら自分の開発ブランチ名
- secret もパーソナルアクセストークンも不要。**Claude Code のセッション側には
  `gh` CLI は無い**ため、Issue 作成は GitHub MCP ツール（＝「Claude」GitHub App
  の権限）で行う。一方、トンネル起動後に Issue へ `exp://` URL を書き込むのは
  **GitHub Actions ランナー側**で、そこには `gh` がプリインストール済みなので
  ワークフロー自身の `permissions: issues: write` だけでコメントできる
  （セッションとランナーは別環境という点に注意）。

## 最重要：Expo SDK は「App Store の Expo Go が実際に対応する版」に固定する

**最新の Expo SDK は使わないこと。** 公開されている Expo Go アプリは最新
SDK リリースから遅れており、ときには数バージョン遅れることもある。これは
Expo Go のビルドごとに Apple／Google のアプリストア審査が必要で、それが
何か月も滞ることがあるため。新しすぎる SDK は、Expo Go を最新にしていても
実機でまさに次のエラーを出す：

> Project is incompatible with this version of Expo Go.
> The project you requested requires a newer version of Expo Go.

これは Expo Go アプリを更新することでは直らない（すでに上限に達しているため）。
*プロジェクト側*の SDK バージョンを、現在公開されている版に合わせることで直る。

**コードを書き始める前に**、適切な SDK バージョンを見極める（この手順は
`/check-sdk` スキルで自動化されている）：

1. Expo 公式の changelog で現在のアプリストア状況を確認する ——「Expo Go and
   the App Store」に当月・当年を添えて検索するか、
   https://expo.dev/changelog を見る。どの SDK が審査待ちで、どの SDK が
   各ストアで実際に稼働中かが書かれている。
2. その SDK の「既知の正しい依存関係一式」を公式テンプレートから取得する
   —— バージョン番号を手で推測しないこと：
   ```
   npm view expo-template-blank-typescript dist-tags
   # 手順1で分かった SDK に対応する sdk-NN タグを見つける
   npm view expo-template-blank-typescript@sdk-NN dependencies
   ```
   これで `package.json` に固定すべき `expo` / `react` / `react-native` /
   `expo-status-bar` の正確なバージョンが得られる。
3. バージョン変更後は `rm -rf node_modules package-lock.json && npm install`
   を実行し、続けて `npx tsc --noEmit` で何も壊れていないことを確認する。

このリポジトリは現在 **SDK 54** に固定している（2026-07 時点）。SDK 55 の
Expo Go ビルドが 2026 年 5 月頃から Apple App Store の審査で止まっているため。
新しいプロジェクトを始める前にこの状況を必ず再確認すること —— これを読む
頃には状況はおそらく変わっている。

**PC 開発でもこの固定方針は変えない。** スマホの Expo Go 実機で開くことを常に
選択肢として残すため、SDK は「今ストアに出ている Expo Go が対応する版」に合わせ
続ける。PC のシミュレータや development build なら理論上は最新 SDK も動くが、
スマホ運用と食い違うと混乱するので、両版とも同じ固定 SDK で揃える。

## PC でローカル開発する場合

手元の PC に開発環境がある人向け。中身は素の Expo プロジェクトなので特別な
設定は要らない。**スマホだけで開発するなら、この節は読み飛ばしてよい**
（トンネル運用だけで完結する）。

### 前提

- Node.js（LTS。CI ランナーは Node 22 を使用）と npm。
- 実機で開くなら、PC とスマホが**同一 LAN** にあり、スマホに Expo Go が入って
  いること。
- iOS シミュレータには Xcode（macOS のみ）、Android エミュレータには
  Android Studio が必要。持っていなければ実機（LAN）で十分。

### 手順

```
npm install
npm start        # Metro が起動し、QR コードとメニューが出る
```

- スマホ実機（同一 LAN）… 表示された QR を Expo Go で読む。
- iOS シミュレータ … ターミナルで `i`（または `npm run ios`）。
- Android エミュレータ … `a`（または `npm run android`）。
- LAN がうまくいかない時 … `npx expo start --tunnel`（`@expo/ngrok` は devDependency
  に入っている）。GitHub Actions のトンネルと同じ経路になる。

ローカル起動は `/start-local` スキルにまとめてある。

### Web プレビューについて

このテンプレートは **Web（`expo start --web`）を対象にしていない**。`react-dom` /
`react-native-web` 等の Web 依存を入れておらず、`app.json` も Web 向けに構成して
いない。UI 確認はスマホ実機か iOS/Android シミュレータで行う。

## Supabase 対応（バックエンドが必要なとき）

バックエンド（DB / Auth / Storage）が必要になったら Supabase を使う。
テンプレートの基本ファイルには何も先回りして追加していない —— オプトインの
2スキルで完結する：

- **`/setup-supabase`**（一度きり）—— Supabase プロジェクトを作成し、
  `@supabase/supabase-js` クライアントを配線する。
- **`/migrate-supabase`**（繰り返し使う）—— マイグレーション SQL を書いて
  リモート DB に適用し、`lib/database.types.ts` を再生成する。

### 重要：`supabase` CLI は使わず Management API（curl）を使う

`supabase` CLI は Bun 製バイナリで、Claude Code on the web のセキュリティ
プロキシ（全通信を TLS 再暗号化する）と**非互換**。実行するとプロキシの証明書を
信頼できず `TransportError` になる（公式ドキュメントでも「Bun は既知の非互換例」
と明記）。そのため両スキルは **CLI を使わず、`api.supabase.com` の Management API
を curl で叩く**。curl はプロキシの CA（`/root/.ccr/ca-bundle.crt`）を信頼できる
ので確実に動く。この方式はテンプレートで実際にプロジェクト作成〜マイグレーション
適用〜型生成〜`tsc` まで通ることを検証済み。

- プロジェクト作成 … `POST /v1/projects`（`create_project.sh`）
- 公開キー取得   … `GET  /v1/projects/<ref>/api-keys`
- SQL 適用       … `POST /v1/projects/<ref>/database/query`（`push.sh`）
- 型生成         … `GET  /v1/projects/<ref>/types/typescript`（`push.sh`）

依存インストールも `expo install` の SDK 互換解決がプロキシ下で不安定なため、
SDK にピン留めされたネイティブモジュール版を `node_modules/expo/bundledNativeModules.json`
から読み取り `npm install` で直接入れる（`scaffold.sh`）。

### ネットワーク要件

Management API と Supabase への通信が必要なので、環境のネットワークポリシーで
以下のホストを許可する（**Trusted + カスタム許可**で十分。フルアクセスにする
必要はない）：

- `api.supabase.com`（Management API）
- `*.supabase.co`（プロジェクト本体・DB・REST）
- `*.pooler.supabase.com`（connection pooler 経由になる場合）

未許可だと curl が `host not permitted`（プロキシの 403）で失敗する。フルアクセスは
外向き通信が無制限になり、`SUPABASE_ACCESS_TOKEN` 等の秘密が万一漏れた際の
持ち出し経路が広がるため、必要ホストだけの許可を推奨する。

### 立ち上げ手順（概要、詳細は各スキル参照）

```
スマホのブラウザでパーソナルアクセストークン発行 → セッションに SUPABASE_ACCESS_TOKEN をセット（これだけ手動）
組織ID取得（curl: GET /v1/organizations）
プロジェクト作成（create_project.sh → 作成・稼働待ち・公開キー取得）
クライアント配線（scaffold.sh → .env / 依存 / lib/supabase.ts）
マイグレーション書く（supabase/migrations/<timestamp>_<name>.sql）
適用 + 型生成（push.sh → database/query で適用、types/typescript で型生成）
```

パーソナルアクセストークン（`SUPABASE_ACCESS_TOKEN`）の取得手順は README の
「Supabase を使う場合」を参照。**トークンをチャットに直接貼り付けさせないこと**
—— 会話ログに残ってしまうため、この Claude Code 環境の環境変数として設定してもらう。

生成される主なファイル（すべて `/setup-supabase` / `/migrate-supabase` 実行時
にのみ作られる）：

- `supabase/migrations/`（マイグレーション SQL）
- `.env`（`.gitignore` 対象、URL とキーのみ。コミットしない）
- `.env.example`（コミット対象。プレースホルダのみ）
- `lib/supabase.ts`（クライアント）／ `lib/database.types.ts`（生成された型）

**`EXPO_PUBLIC_` 接頭辞が付いた環境変数だけが Expo のバンドルに埋め込まれる**。
このため `.env` に置くのは `anon` / `publishable` キーのみとし、
`service_role` キーなど秘密情報は絶対に `EXPO_PUBLIC_` 変数にしないこと
（クライアント側から丸見えになる）。

## 動作確認

UI とロジックの動作確認は、開発スタイルに応じて 2 通り：

- **スマホだけで開発する場合** … `/start-tunnel` でトンネルを起動し、スマホの
  Expo Go 実機で確認する。PC もローカル実行も不要。`npx expo start --web` の
  ようなブラウザプレビューは、その画面をスマホから見る手段が無いうえ Web 依存も
  入れていないため使わない。
- **PC で開発する場合** … `/start-local`（`npm start`）で Metro を起動し、
  スマホ実機（同一 LAN）か iOS/Android シミュレータで確認する。Web プレビューは
  対象外（「PC でローカル開発する場合」参照）。

どちらのスタイルでも、型エラーなどコードレベルの検証は `npx tsc --noEmit` で
行える（Claude Code の実行環境で走り、結果はテキストで返るのでスマホからでも
確認できる）。Claude Code のセッション自体はスマホからでも操作できるので、
PC 開発と併用しても問題ない。

## 利用できるスキル

- **`/init-project`** — このテンプレートから新規プロジェクトを初期化する
  （トラッキング Issue 作成・`NOTIFY_USER` 自動設定・workflow 書き換え・
  アプリ名変更）。初回セットアップを求められたらまずこれ。最後に任意で
  Supabase セットアップ（`/setup-supabase`）への誘導も行う。
- **`/start-tunnel`** — Expo トンネルを起動し、`exp://` URL / QR を取得する。
  「アプリを実機で動かしたい」「トンネルを立てて」等で使う（スマホだけで開発
  する場合の中心）。
- **`/start-local`** — PC の手元で `npm start`（Metro）を起動し、同一 LAN の
  スマホ実機や iOS/Android シミュレータで開く。「PC で開発したい」「ローカルで
  起動して」等で使う。
- **`/check-sdk`** — 今ストアで稼働中の Expo Go に合う SDK バージョンを確認して
  固定する。新規プロジェクト開始前や「incompatible」エラー時に使う。
- **`/setup-supabase`** — Supabase プロジェクトを Management API（curl）で作成し、
  クライアントを配線する（一度きり）。「Supabase を使いたい」「バックエンドが
  欲しい」等で使う。
- **`/migrate-supabase`** — マイグレーション SQL を書いてリモート DB に適用し、
  型を再生成する（繰り返し使う）。「テーブルを追加して」「マイグレーション
  実行して」等で使う。
