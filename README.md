# Expo + Claude Code テンプレート（スマホだけで開発）

PC・Xcode・Android Studio を一切使わず、**スマホと Claude Code だけ**で
Expo / React Native アプリを開発するためのテンプレートリポジトリです。

コードの編集とコミットは Claude Code が行い、実機での動作確認は GitHub
Actions が立ち上げる Expo トンネル経由で行います。ローカルで
`npx expo start` を動かす必要はありません。

## 開発フロー

1. Claude Code がコードを編集し、コミットを push する。
2. `develop` への push（または Claude Code の `/tunnel` スキル、Actions タブ /
   GitHub モバイルアプリからの **Expo Tunnel** ワークフロー手動実行）で
   `.github/workflows/expo-tunnel.yml` が起動する。
3. ワークフローが GitHub ホストランナー上で `npx expo start --tunnel` を実行し、
   トンネルが立ち上がるとトラッキング用 Issue に `exp://` URL と QR コードを
   コメントする（自分宛メンション付き＝通常の GitHub 通知として届く）。
4. スマホの Expo Go で QR を読み取る（または `exp://` リンクを直接開く）と
   アプリがトンネル経由で起動する。
5. トンネルは Actions UI からキャンセルするか約 350 分経過するまで動き続ける。
   再 push すると実行中のトンネルは自動でキャンセルされ、同時に 2 本以上
   立ち上がることはない。

Codespaces / devcontainer は使いません（PAT 不要・課金なしで Actions ジョブ内で
直接トンネルを動かすほうが単純で確実なため）。

## 新しいプロジェクトでの初回セットアップ

> **かんたん設定**: Claude Code で `/setup-template` を実行すると、以下の
> 2〜5（トラッキング Issue の作成、`NOTIFY_USER` の自動設定、workflow の
> 書き換え、アプリ名の変更）を自動で行います。手動でやる場合は以下の手順。

1. このテンプレートから新しいリポジトリを作成する。
2. トラッキング用の Issue を 1 つ作成し、その番号を控える。
3. `.github/workflows/expo-tunnel.yml` を編集する：
   - `env.STATUS_ISSUE_NUMBER` → その Issue 番号
   - `env.NOTIFY_USER` → 自分の GitHub ユーザー名
   - `push.branches` → 使う開発ブランチ名（無ければ `workflow_dispatch`
     のみでも動く）
4. `app.json` と `package.json` の `name` / `slug` を新プロジェクト用に変更する。
5. secret や PAT の追加設定は不要。`gh` はランナーにプリインストール済みで、
   ワークフロー自身の `permissions: issues: write` だけで Issue にコメントできる。

## トラブルシューティング

### Actions 実行時に `403 Resource not accessible by integration`

`expo-tunnel.yml` は Issue にコメントするため `permissions: issues: write` を
宣言していますが、リポジトリ（または Organization）側の設定でワークフローに
許可する権限の上限が「読み取りのみ」に絞られていると、ワークフロー内の
`permissions` 指定は無視されてこのエラーになります。

対処法：

1. リポジトリの **Settings → Actions → General** を開く。
2. **Workflow permissions** セクションで
   **「Read and write permissions」** を選択し、Save する。
3. Organization 側で Actions のデフォルト権限が制限されている場合は、
   Organization の **Settings → Actions → General** でも同様に確認する
   （個人アカウント配下のリポジトリではこの項目は無い）。

設定変更後、ワークフローを再実行（Actions タブから Re-run、または再度
push / `/tunnel`）すれば通るはずです。

## Expo SDK のバージョン固定について（重要）

**最新の Expo SDK は使わないこと。** App Store 版の Expo Go は最新 SDK に
数バージョン遅れることがあり、新しすぎる SDK だと実機で
「Project is incompatible with this version of Expo Go」エラーになります。
プロジェクトの SDK を「今 App Store / Play Store に出ている Expo Go」が
対応するバージョンに合わせる必要があります。

現在このテンプレートは **SDK 54** に固定しています（2026-07 時点。SDK 55 の
Expo Go は Apple の審査待ちのため）。詳細な確認手順は `CLAUDE.md` を参照。

## 動作確認

このテンプレートは **PC を前提にしません**（スマホ + Claude Code のみ）。
`npx expo start --web` のようなローカルのブラウザプレビューは、その画面を
スマホから見る手段が無いため使いません。UI・動作の確認は `/tunnel` で
トンネルを起動し、スマホの Expo Go 実機で行います。

型チェック（`npx tsc --noEmit`）などコードレベルの検証は Claude Code の実行
環境で走り、結果がテキストで返るのでスマホからでも確認できます。

## Claude Code のスキル

このテンプレートには、スマホからの開発を助けるスキルが同梱されています。

| スキル | 用途 | 自然文での呼び出し例 |
| --- | --- | --- |
| `/setup-template` | 新規プロジェクトの初期化（Issue 作成・`NOTIFY_USER` 設定・workflow 書き換え・アプリ名変更） | 「セットアップして」「このテンプレートを初期化して」 |
| `/tunnel` | Expo トンネルを起動し `exp://` URL / QR を取得（実機で開く） | 「トンネル起動して」「アプリを実機で動かしたい」 |
| `/sdk-check` | 今ストアで稼働中の Expo Go に合う SDK バージョンを確認して固定 | 「SDKのバージョンを確認して」「incompatibleエラーが出た」 |

スラッシュコマンドを直接使わなくても、上記のような自然な日本語の指示で
Claude Code が該当スキルを判断して実行します。

## ディレクトリ構成

```
.github/workflows/expo-tunnel.yml  トンネル起動 + GitHub 通知
.claude/skills/                    Claude Code スキル（setup-template / tunnel / sdk-check）
CLAUDE.md                         開発フローと SDK バージョンの注意点（Claude 向け）
App.tsx                            アプリのエントリー（ここから書き始める）
index.ts                           ルート登録
app.json                          Expo 設定（name / slug を変更）
package.json                      SDK 固定済みの依存関係
tsconfig.json                     TypeScript 設定
assets/                           アイコン / スプラッシュ画像（差し替え可）
```
