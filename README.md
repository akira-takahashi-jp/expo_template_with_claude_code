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

このエラーは「呼び出し元の integration（App／トークン）に、その操作を行う
権限が無い」ことを示します。Claude Code on the web／モバイルから GitHub と
連携している場合、Issue 作成やワークフロー起動などの操作は実体として
**「Claude」GitHub App のインストール権限**で行われるため、まずここを疑う。

1. GitHub の **Settings → Applications → Installed GitHub Apps**
   （Organization リポジトリなら Organization の **Settings → GitHub Apps**）
   を開く。
2. 「Claude」アプリの **Configure** を開き、**Repository permissions** で
   `Issues: Read and write` / `Contents: Read and write` /
   `Actions: Read and write` が許可されているか確認し、不足していれば
   追加する。
3. 対象リポジトリがアプリのアクセス範囲（All repositories／Only select
   repositories）に含まれているかも確認する。

上記を見直しても直らない場合、`expo-tunnel.yml` 内の `gh issue comment` は
ワークフロー自身の `GITHUB_TOKEN` で実行されるため、こちらの権限が原因の
こともある：

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

## Supabase を使う場合（オプション）

バックエンド（DB / Auth / Storage）が必要なら Supabase を追加できます。
テンプレートの基本ファイルには何も先回りして追加していません。次の2つの
スキルを実行したときだけ、関連ファイル・依存が増えます。

- `/supabase-setup` — Supabase プロジェクトを CLI で作成・リンクし、
  `@supabase/supabase-js` クライアントを配線する（一度きり）。
- `/supabase-migrate` — マイグレーション SQL を書いてリモート DB に push し、
  TypeScript の型を再生成する（繰り返し使う）。

立ち上げ手順（全て CLI）：

```
スマホのブラウザで PAT 発行 → セッションに SUPABASE_ACCESS_TOKEN をセット（これだけ手動）
supabase projects create <name> --org-id <id> --db-password <pw>
supabase init でローカルに supabase/ と config.toml 生成
supabase link --project-ref <ref>
マイグレーション書く → supabase db push
supabase gen types typescript で型生成 → Expo 側に取り込み
```

### Supabase PAT（アクセストークン）の取得手順

1. スマホのブラウザで https://supabase.com/dashboard/account/tokens を開く
   （Supabase アカウントにログイン）。
2. 「Generate new token」をタップする。
3. トークン名を入力する（例: `claude-code-mobile` など、用途がわかる名前に
   しておくと後で管理しやすい）。
4. 生成されたトークンをコピーする。
5. コピーしたトークンは **チャットに直接貼り付けない**。この Claude Code
   環境の環境変数設定で `SUPABASE_ACCESS_TOKEN` としてセットする
   （設定方法は https://code.claude.com/docs/en/claude-code-on-the-web の
   環境変数の項目を参照）。会話ログに残ってしまうため、必ず環境変数経由で
   渡してください。

トークンをセットしたら `/supabase-setup` を実行してください。

### 生成されるファイル

- `supabase/`（`config.toml` とマイグレーション SQL。`supabase init` で生成）
- `.env`（`.gitignore` 対象。Supabase の URL と `anon` キーのみ。コミットしない）
- `.env.example`（コミット対象。プレースホルダのみ）
- `lib/supabase.ts`（Supabase クライアント）
- `lib/database.types.ts`（`/supabase-migrate` で生成される型。`db push` の
  たびに更新される）

**注意**：Expo は `EXPO_PUBLIC_` 接頭辞の付いた環境変数だけをアプリのバンドルに
埋め込みます。そのため `.env` に置くのは公開してよい `anon` / `publishable`
キーのみにしてください。`service_role` キーなどの秘密情報を `EXPO_PUBLIC_`
変数にすると、アプリのバンドルから丸見えになります。

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
| `/supabase-setup` | Supabase プロジェクトを CLI で作成・リンクし、クライアントを配線（一度きり） | 「Supabaseを使いたい」「バックエンドが欲しい」 |
| `/supabase-migrate` | マイグレーション SQL を書いてリモート DB に push し、型を再生成（繰り返し使う） | 「テーブルを追加して」「マイグレーション実行して」 |

スラッシュコマンドを直接使わなくても、上記のような自然な日本語の指示で
Claude Code が該当スキルを判断して実行します。

## ディレクトリ構成

```
.github/workflows/expo-tunnel.yml  トンネル起動 + GitHub 通知
.claude/skills/                    Claude Code スキル（setup-template / tunnel / sdk-check / supabase-setup / supabase-migrate）
CLAUDE.md                         開発フローと SDK バージョンの注意点（Claude 向け）
App.tsx                            アプリのエントリー（ここから書き始める）
index.ts                           ルート登録
app.json                          Expo 設定（name / slug を変更）
package.json                      SDK 固定済みの依存関係
tsconfig.json                     TypeScript 設定
assets/                           アイコン / スプラッシュ画像（差し替え可）
supabase/                         （オプション）/supabase-setup 実行時に生成。config.toml とマイグレーション
lib/                              （オプション）/supabase-setup 実行時に生成。supabase.ts / database.types.ts
.env.example                      （オプション）Supabase の環境変数プレースホルダ（コミット対象）
```
