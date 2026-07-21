---
name: tunnel
description: Start the Expo tunnel on GitHub Actions and report the exp:// URL and QR code so the app can be opened in Expo Go on a phone. Triggers the Expo Tunnel workflow, waits for it to come up, and returns the connection URL. Use when the user wants to run/open/launch the app on their phone, start the tunnel, or get a fresh exp:// link.
---

# Expo トンネルを起動して実機で開く

GitHub Actions 上で Expo トンネルを起動し、スマホの Expo Go で開くための
`exp://` URL / QR コードを取得する。テンプレートの中心的な開発ループ。

## 実行手順

### 1. 前提を確認する

- `gh` がログイン済みか（`gh auth status`）。未ログインなら `!gh auth login`
  をユーザーに促す。
- `.github/workflows/expo-tunnel.yml` の `STATUS_ISSUE_NUMBER` /
  `NOTIFY_USER` がプレースホルダ（`REPLACE_WITH_...`）のままでないか。
  まだなら先に `/setup-template` を実行するよう案内する。

### 2. 配信するコードが push 済みか意識する

トンネルは Actions 上で **リモートのブランチをチェックアウトして** 配信する。
ローカルの未 push の変更は反映されない。直前に編集した内容を試したい場合は、
先に対象ブランチへ push してあるか確認する（必要ならユーザーに確認する）。

### 3. 起動スクリプトを実行する

このスキルと同じフォルダの `launch.sh` を実行する：

```sh
.claude/skills/tunnel/launch.sh
```

- 別ブランチで配信したいときは `--ref <branch>`。
- 待機上限を変えたいときは `--timeout <秒>`（既定 420）。

スクリプトがやること：yml からトラッキング Issue 番号と配信ブランチを読み取り
→ `gh workflow run` でワークフローを起動 → その Issue に新しく付く `exp://`
入りコメントをポーリング → 検出したら URL と QR リンクを表示。

### 4. 結果を報告する

- 取得した `exp://` URL と QR リンクをユーザーに伝える。
- 「スマホの Expo Go で QR を読み取る／リンクを開くと起動します」と案内する。
- タイムアウトした場合は、スクリプトが出す Actions ラン URL を伝え、ログ確認を促す
  （`gh run view <id> --log-failed` などで原因を調べられる）。

## 注意

- 同時に走るトンネルは常に1本（yml の固定 `concurrency` グループ）。再実行すると
  実行中のランは自動キャンセルされる。
- トンネルは Actions UI からキャンセルするか約 350 分で自動終了する。
- ホットリロードは無い（ランナーは固定コミットを配信するだけ）。コード変更を
  反映するには push し直して再度このスキルを実行する。
- push だけでもトンネルは起動する（yml の `push.branches`）。このスキルは
  `workflow_dispatch` 経由なのでコミットを作らずに起動できる、という違い。
