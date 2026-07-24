---
name: init-project
description: Initialize this Expo phone-only template for a new project — creates the GitHub tracking issue, auto-detects and sets NOTIFY_USER, patches STATUS_ISSUE_NUMBER and the dev branch in the tunnel workflow, optionally renames the app, and optionally offers to set up a Supabase backend. Use right after creating a new repo from this template, or when the user asks to run the initial/one-time setup.
---

# テンプレート初回セットアップ

このテンプレート（Expo をスマホだけで開発する構成）を新しいプロジェクト用に
初期化する。`CLAUDE.md` の「初回セットアップ」を自動で実行する。

## 重要：`gh` CLI ではなく GitHub MCP ツールを使う

この環境（Claude Code on the web）のセッション側には **`gh` CLI が無い**
（`gh` が入っているのはトンネルを動かす GitHub Actions ランナー側で、別環境）。
そのため GitHub 操作（ユーザー名検出・Issue 作成）は **Claude が GitHub MCP
ツールで直接**行い、その結果を `configure.sh`（ファイル書き換え専用）に渡す。
追加のトークンやインストールは不要（MCP はセッション標準で使える）。

## 実行手順

### 1. 前提を確認する

- カレントがこのテンプレートのルートか（`.github/workflows/expo-tunnel.yml`
  が存在するか）。
- GitHub MCP ツールが使えるか（`get_me` が通るか）。通らない場合は GitHub
  連携がまだされていないので、その旨をユーザーに伝える。

### 2. 必要な値をユーザーに確認する

`AskUserQuestion` などで以下を確認する（分かるものはデフォルトを提示）：

- **開発ブランチ名**（デフォルト `develop`）。push でトンネルを起動したいブランチ。
- **アプリの slug**（`app.json` の `slug` と `package.json` の `name`。
  英小文字・ハイフンのみ。例 `my-app`）。
- **アプリの表示名**（`app.json` の `name`。省略時は slug と同じ）。
- 既存の Issue を使うか、新規作成するか（通常は新規作成）。

`NOTIFY_USER` はログイン中の GitHub アカウントから自動検出するので聞かない。

### 3. GitHub 操作を MCP ツールで行う

- **ユーザー名（NOTIFY_USER）** … `get_me` の `login` を使う。
- **対象リポジトリ** … 通常はカレントのリモート（`git remote get-url origin`
  から `owner/repo` を導出）を使う。
- **トラッキング Issue**（新規作成の場合）… `issue_write`（create）で作成する。
  - タイトル例: `Expo tunnel status`
  - 本文例: 「Expo トンネルの状態通知用の Issue です。Expo Tunnel ワークフローが
    実行されるたびに、この Issue に `exp://` URL とスキャン用の QR コードが
    コメントされます。クローズしないでください。」
  - 返ってきた **Issue 番号** を控える。既存 Issue を使う場合はその番号を使う。
  - 作成が `403 Resource not accessible by integration` で失敗する場合は、
    「Claude」GitHub App のリポジトリ権限（`Issues: write` など）が不足している。
    README のトラブルシューティングを案内する。

### 4. セットアップスクリプトを実行する

このスキルと同じフォルダの `configure.sh` に、手順3で得た値を渡して実行する
（このスクリプトは `gh` を使わず、ファイル書き換えだけを行う）：

```sh
.claude/skills/init-project/configure.sh \
  --issue <Issue番号> \
  --notify-user <get_meのlogin> \
  --branch <dev-branch> \
  --slug <app-slug> \
  --name "<表示名>"
```

- `--issue` と `--notify-user` は必須。
- `--branch` を省くと `push.branches` は既定（`develop`）のまま。
- `--slug` / `--name` を省けばアプリ名は変更しない。

スクリプトがやること：`expo-tunnel.yml` の `STATUS_ISSUE_NUMBER` /
`NOTIFY_USER` / `push.branches` を書き換え → 指定があれば
`app.json` / `package.json` の名前を変更。

### 5. 結果を確認して報告する

- `git diff .github/workflows/expo-tunnel.yml app.json package.json` で
  変更内容を確認する。
- 作成された Issue 番号・URL、設定した `NOTIFY_USER`・ブランチ・アプリ名を
  ユーザーに報告する。
- 次アクションを伝える：開発ブランチに push（または Actions タブから
  Expo Tunnel を手動実行）すると、トンネルが立ち上がり Issue に `exp://` URL と
  QR コードが通知される。

### 6. （オプション）Supabase バックエンドのセットアップを提案する

初回セットアップの締めくくりに、バックエンド（DB / Auth / Storage）が必要か
どうかをユーザーに確認する。**これは任意**であり、不要なら飛ばしてよい。

- `AskUserQuestion` などで「Supabase（DB/Auth/Storage）も今セットアップするか？」
  を尋ねる。
- **必要な場合** → そのまま `/setup-supabase` スキルに進む。ただし前提として
  `SUPABASE_ACCESS_TOKEN`（パーソナルアクセストークン）を環境変数にセット
  しておく必要があるので、未設定なら README の
  「Supabase パーソナルアクセストークンの取得手順」を案内し、セット後に
  `/setup-supabase` を実行する流れを伝える。ネットワークポリシーで
  `api.supabase.com` / `*.supabase.co` の許可が要る点も併せて伝える
  （詳細は README / `CLAUDE.md` の Supabase セクション）。
- **不要／後回しの場合** → 「あとで必要になったら `/setup-supabase` を実行すれば
  いつでも追加できる」とだけ伝えて終了する。

このステップは案内・誘導のみで、`configure.sh` の対象外（Supabase 側の実処理は
`/setup-supabase` が担当する）。

## 注意

- パーソナルアクセストークンは不要。Issue 作成はセッションの GitHub MCP
  ツール（＝「Claude」GitHub App の権限）で行い、実行中のトンネル通知は
  ワークフロー自身の `permissions: issues: write` で行う。
- Issue 作成が `403 Resource not accessible by integration` になる場合は、
  「Claude」GitHub App のリポジトリ権限不足。README のトラブルシューティング
  （`Issues / Contents / Actions: Read and write`）を確認する。
- `configure.sh` は `git rev-parse` でリポジトリルートを判定してファイルを
  書き換えるだけ。GitHub 操作（`get_me` / Issue 作成）は手順3で Claude が
  MCP ツールで済ませてから渡すこと。
- SDK バージョンの固定については `CLAUDE.md` の該当セクションを参照
  （このスキルの範囲外）。
