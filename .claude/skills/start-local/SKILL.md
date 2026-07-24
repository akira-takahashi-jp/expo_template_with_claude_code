---
name: start-local
description: Help the user run the app locally on their own PC with `npm start` (Metro), opening it on a LAN-connected Expo Go device or an iOS/Android simulator. Validates that the project installs, type-checks, and boots in the Claude environment, then hands the user the exact commands to run on their machine. Use when the user wants to develop on a PC, run the app locally, or asks to start Metro / a local dev server.
---

# PC でローカル開発する（Metro をローカル起動）

手元の PC で `npm start`（Metro バンドラ）を起動し、同一 LAN のスマホ実機
（Expo Go）や iOS/Android シミュレータでアプリを開くための手順。トンネル運用
（`/start-tunnel`）の代わりに、PC がある人向けのローカル開発ループ。

## 大前提：`npm start` は「ユーザーの PC」で動かす

Claude Code のセッションは**リモートの実行環境**で動いており、ユーザーの PC でも
同一 LAN 上でもない。そのため Metro をこのセッション内で起動しても、ユーザーの
スマホからは到達できない（QR も LAN も届かない）。

したがってこのスキルの役割は 2 つ：

1. **Claude 側でできる検証を代行する** —— 依存が入るか、型が通るか、Metro が
   設定エラーなく起動するかをこの環境で確認し、コードが壊れていないことを保証する。
2. **ユーザーの PC で実行するコマンドを案内する** —— 実際の起動と実機/シミュレータ
   接続はユーザーが手元で行う。

## 実行手順

### 1. Claude 側で健全性を検証する

このセッションの実行環境で以下を走らせ、問題がないことを確認する：

```sh
npm install
npx tsc --noEmit
```

- `tsc` が通らなければ、まずそのエラーを直す（ローカルでも同じく失敗するため）。
- 依存を変更した直後などは `rm -rf node_modules package-lock.json && npm install`
  でクリーンに入れ直してもよい。

必要なら Metro が起動すること自体も確認できる（バンドルは実機がないと完了しない
ので、起動ログが出たら止めてよい）：

```sh
# CI=false で watch を有効化。数秒でメニュー/ログが出たら Ctrl-C で止める
CI=false npx expo start --port 8081
```

これは「設定エラーで即死しないか」の確認用。到達性の検証ではない点に注意。

### 2. ユーザーの PC 向けコマンドを案内する

検証が通ったら、ユーザーに以下を自分の PC で実行してもらう：

```sh
npm install     # 初回、または依存を変更した後だけ
npm start       # Metro が起動し、QR コードとメニューが出る
```

接続方法を状況に応じて案内する：

- **スマホ実機（同一 LAN）** … 表示された QR を Expo Go で読み取る。PC とスマホが
  同じ Wi-Fi にいる必要がある。
- **iOS シミュレータ**（macOS + Xcode）… ターミナルで `i`、または `npm run ios`。
- **Android エミュレータ**（Android Studio）… `a`、または `npm run android`。
- **LAN がうまくいかない**（社内ネットワークで隔離されている等）… `npm run tunnel`
  （`npx expo start --tunnel`）。`@expo/ngrok` は devDependency に入っているので
  追加インストール不要。Actions のトンネルと同じ ngrok 経由になる。

### 3. push との関係を確認する

ローカルの Metro は**ワーキングツリーのコード**をそのまま配信する（push 不要・
ホットリロードあり）。`/start-tunnel` が「リモートの push 済みブランチ」を配信
するのと対照的。ローカルで確認した変更をチームに共有したい / トンネルでも試したい
場合は、別途 push する必要がある旨を伝える。

## 注意

- **SDK 固定方針は変えない。** ローカル/シミュレータなら理論上は新しい SDK も動くが、
  スマホの Expo Go 実機運用と食い違うのを避けるため、`CLAUDE.md` の固定 SDK を維持
  する。SDK を上げたい相談は `/check-sdk` へ。
- **Web プレビューは対象外。** `react-dom` / `react-native-web` を入れていないため
  `expo start --web` は使わない。UI 確認は実機かシミュレータで。
- Xcode / Android Studio が無くても、同一 LAN のスマホ実機（Expo Go）だけで開発
  できる。シミュレータは必須ではない。
