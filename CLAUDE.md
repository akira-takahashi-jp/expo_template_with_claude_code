# Expo + Claude Code：スマホだけで開発するテンプレート

このリポジトリは、PC・Xcode・Android Studio を使わず、自分のマシンで
`npx expo start` を動かすこともなく、**スマホと Claude Code だけ**で
Expo / React Native アプリを開発するためのテンプレートです。

## 仕組み

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

**自動化あり:** `/setup-template` スキル（`.claude/skills/setup-template/`）を
使うと、以下を自動で実行できる —— `gh` でトラッキング用 Issue を作成し、
ログイン中のアカウントから `NOTIFY_USER` を検出し、`expo-tunnel.yml` の
`STATUS_ISSUE_NUMBER` / `NOTIFY_USER` / `push.branches` を書き換え、必要なら
`app.json` / `package.json` のアプリ名も変更する。ユーザーが初回セットアップを
求めたら、まずこのスキルを使うこと。以下は同じ内容を手動で行う場合の手順：

- 新リポジトリにトラッキング用の Issue を 1 つ作成し（タイトルは任意）、
  その番号を控える。
- `.github/workflows/expo-tunnel.yml` を編集する：
  - `env.STATUS_ISSUE_NUMBER` → その Issue の番号
  - `env.NOTIFY_USER` → 自分の GitHub ユーザー名
  - `push.branches` のリスト → `develop` 以外を使うなら自分の開発ブランチ名
- secret もパーソナルアクセストークンも不要。`gh` は GitHub ホストランナーにプリインストール済みで、
  ワークフロー自身の `permissions: issues: write` だけでトラッキング用 Issue に
  コメントできる。

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
`/sdk-check` スキルで自動化されている）：

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

## Supabase 対応（バックエンドが必要なとき）

バックエンド（DB / Auth / Storage）が必要になったら Supabase を使う。
テンプレートの基本ファイルには何も先回りして追加していない —— オプトインの
2スキルで完結する：

- **`/supabase-setup`**（一度きり）—— Supabase プロジェクトを CLI で作成し、
  `supabase link` した上で `@supabase/supabase-js` クライアントを配線する。
- **`/supabase-migrate`**（繰り返し使う）—— マイグレーション SQL を書いて
  リモート DB に `db push` し、`lib/database.types.ts` を再生成する。

立ち上げ手順（全て CLI、詳細は `/supabase-setup` スキル参照）：

```
スマホのブラウザでパーソナルアクセストークン発行 → セッションに SUPABASE_ACCESS_TOKEN をセット（これだけ手動）
supabase projects create <name> --org-id <id> --db-password <pw>
supabase init でローカルに supabase/ と config.toml 生成
supabase link --project-ref <ref>
マイグレーション書く → supabase db push
supabase gen types typescript で型生成 → Expo 側に取り込み
```

パーソナルアクセストークン（`SUPABASE_ACCESS_TOKEN`）の取得手順は README の「Supabase を使う場合」
を参照。**トークンをチャットに直接貼り付けさせないこと** —— 会話ログに残って
しまうため、この Claude Code 環境の環境変数として設定してもらう。

生成される主なファイル（すべて `/supabase-setup` / `/supabase-migrate` 実行時
にのみ作られる）：

- `supabase/`（`config.toml` とマイグレーション SQL）
- `.env`（`.gitignore` 対象、URL とキーのみ。コミットしない）
- `.env.example`（コミット対象。プレースホルダのみ）
- `lib/supabase.ts`（クライアント）／ `lib/database.types.ts`（生成された型）

**`EXPO_PUBLIC_` 接頭辞が付いた環境変数だけが Expo のバンドルに埋め込まれる**。
このため `.env` に置くのは `anon` / `publishable` キーのみとし、
`service_role` キーなど秘密情報は絶対に `EXPO_PUBLIC_` 変数にしないこと
（クライアント側から丸見えになる）。

## 動作確認

このテンプレートは **PC を前提にしない**（スマホ + Claude Code のみ）。
`npx expo start --web` のようなローカルのブラウザプレビューは、その画面を
スマホから見る手段が無いため使わない。UI とロジックの確認は、`/tunnel` で
トンネルを起動し、スマホの Expo Go 実機で行う。

型エラーなどコードレベルの検証は `npx tsc --noEmit` で行える（Claude Code の
実行環境で走り、結果はテキストで返るのでスマホからでも確認できる）。

## 利用できるスキル

- **`/setup-template`** — このテンプレートから新規プロジェクトを初期化する
  （トラッキング Issue 作成・`NOTIFY_USER` 自動設定・workflow 書き換え・
  アプリ名変更）。初回セットアップを求められたらまずこれ。
- **`/tunnel`** — Expo トンネルを起動し、`exp://` URL / QR を取得する。
  「アプリを実機で動かしたい」「トンネルを立てて」等で使う。
- **`/sdk-check`** — 今ストアで稼働中の Expo Go に合う SDK バージョンを確認して
  固定する。新規プロジェクト開始前や「incompatible」エラー時に使う。
- **`/supabase-setup`** — Supabase プロジェクトを CLI で作成・リンクし、
  クライアントを配線する（一度きり）。「Supabase を使いたい」「バックエンドが
  欲しい」等で使う。
- **`/supabase-migrate`** — マイグレーション SQL を書いてリモート DB に push し、
  型を再生成する（繰り返し使う）。「テーブルを追加して」「マイグレーション
  実行して」等で使う。
