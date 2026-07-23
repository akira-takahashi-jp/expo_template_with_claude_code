---
name: setup-template
description: Initialize this Expo phone-only template for a new project — creates the GitHub tracking issue, auto-detects and sets NOTIFY_USER, patches STATUS_ISSUE_NUMBER and the dev branch in the tunnel workflow, optionally renames the app, and optionally offers to set up a Supabase backend. Use right after creating a new repo from this template, or when the user asks to run the initial/one-time setup.
---

# テンプレート初回セットアップ

このテンプレート（Expo をスマホだけで開発する構成）を新しいプロジェクト用に
初期化する。`CLAUDE.md` の「初回セットアップ」を自動で実行する。

## 実行手順

### 1. 前提を確認する

以下を順に確認し、問題があればユーザーに知らせて中断する。

- カレントがこのテンプレートのルートか（`.github/workflows/expo-tunnel.yml`
  が存在するか）。
- `gh` CLI がインストールされ、ログイン済みか：`gh auth status`。
  未ログインなら、ユーザーに「プロンプトで `!gh auth login` を実行して」と伝える
  （対話ログインはこのセッションからは代行できない）。
- リモートの GitHub リポジトリが設定済みか：`gh repo view --json nameWithOwner`。
  まだなら、先に新リポジトリを作成／push するよう案内する。

### 2. 必要な値をユーザーに確認する

`AskUserQuestion` などで以下を確認する（分かるものはデフォルトを提示）：

- **開発ブランチ名**（デフォルト `develop`）。push でトンネルを起動したいブランチ。
- **アプリの slug**（`app.json` の `slug` と `package.json` の `name`。
  英小文字・ハイフンのみ。例 `my-app`）。
- **アプリの表示名**（`app.json` の `name`。省略時は slug と同じ）。
- 既存の Issue を使うか、新規作成するか（通常は新規作成）。

`NOTIFY_USER` はログイン中の GitHub アカウントから自動検出するので聞かない。

### 3. セットアップスクリプトを実行する

このスキルと同じフォルダの `configure.sh` を、確認した値で実行する：

```sh
.claude/skills/setup-template/configure.sh \
  --branch <dev-branch> \
  --slug <app-slug> \
  --name "<表示名>"
```

- 既存 Issue を使う場合は `--issue <番号>` を付ける（新規作成をスキップ）。
- `--slug` / `--name` を省けばアプリ名は変更しない。

スクリプトがやること：`gh` でユーザー名を検出 → トラッキング用 Issue を作成 →
`expo-tunnel.yml` の `STATUS_ISSUE_NUMBER` / `NOTIFY_USER` / `push.branches`
を書き換え → 指定があれば `app.json` / `package.json` の名前を変更。

### 4. 結果を確認して報告する

- `git diff .github/workflows/expo-tunnel.yml app.json package.json` で
  変更内容を確認する。
- 作成された Issue 番号・URL、設定した `NOTIFY_USER`・ブランチ・アプリ名を
  ユーザーに報告する。
- 次アクションを伝える：開発ブランチに push（または Actions タブから
  Expo Tunnel を手動実行）すると、トンネルが立ち上がり Issue に `exp://` URL と
  QR コードが通知される。

### 5. （オプション）Supabase バックエンドのセットアップを提案する

初回セットアップの締めくくりに、バックエンド（DB / Auth / Storage）が必要か
どうかをユーザーに確認する。**これは任意**であり、不要なら飛ばしてよい。

- `AskUserQuestion` などで「Supabase（DB/Auth/Storage）も今セットアップするか？」
  を尋ねる。
- **必要な場合** → そのまま `/supabase-setup` スキルに進む。ただし前提として
  `SUPABASE_ACCESS_TOKEN`（パーソナルアクセストークン）を環境変数にセット
  しておく必要があるので、未設定なら README の
  「Supabase パーソナルアクセストークンの取得手順」を案内し、セット後に
  `/supabase-setup` を実行する流れを伝える。ネットワークポリシーで
  `api.supabase.com` / `*.supabase.co` の許可が要る点も併せて伝える
  （詳細は README / `CLAUDE.md` の Supabase セクション）。
- **不要／後回しの場合** → 「あとで必要になったら `/supabase-setup` を実行すれば
  いつでも追加できる」とだけ伝えて終了する。

このステップは案内・誘導のみで、`configure.sh` の対象外（Supabase 側の実処理は
`/supabase-setup` が担当する）。

## 注意

- secret もパーソナルアクセストークンも不要。ワークフロー自身の `permissions: issues: write` だけで
  Issue にコメントできる。
- スクリプトが `gh` 未ログインやリポジトリ未設定で失敗した場合は、その原因を
  ユーザーに伝え、解消してから再実行する。
- SDK バージョンの固定については `CLAUDE.md` の該当セクションを参照
  （このスキルの範囲外）。
