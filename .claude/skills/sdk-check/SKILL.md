---
name: sdk-check
description: Determine and pin the correct Expo SDK version so the project stays compatible with the Expo Go app currently published on the App Store / Play Store. Checks which SDK is live vs stuck in review, fetches the known-good dependency set, updates package.json, reinstalls, and type-checks. Use before starting a new project, when the user reports the "incompatible with this version of Expo Go" error, or when considering an SDK upgrade.
---

# Expo SDK バージョンの確認・固定

このテンプレート最大の落とし穴への対策。**最新 SDK は使わない** —— 公開中の
Expo Go は最新 SDK に数バージョン遅れることがあり、新しすぎる SDK だと実機で
「Project is incompatible with this version of Expo Go」エラーになる。
プロジェクトの SDK を「今ストアに出ている Expo Go が対応する版」に合わせる。
背景の詳細は `CLAUDE.md` の該当セクション参照。

## 実行手順

### 1. 今ストアで稼働中の SDK を調べる（Web 調査）

`WebFetch` で https://expo.dev/changelog を読むか、`WebSearch` で
「Expo Go and the App Store <当月・当年>」を検索する。判断したいのは：

- **どの SDK が App Store / Play Store で実際に稼働中か**（＝使ってよい上限）
- どの SDK が審査待ちで止まっているか（＝まだ使えない）

Apple と Google で状況が違うことがある点に注意。両方に配布するなら低い方に合わせる。
稼働中と分かった SDK 番号（例 54）を次のステップで使う。

### 2. その SDK の既知の正しい依存関係を取得する

バージョンを手で推測しない。ヘルパースクリプトで公式テンプレートから取得する：

```sh
.claude/skills/sdk-check/check.sh 54    # 54 は手順1で決めた番号
```

これで以下が並んで表示される：
- 公開中の `sdk-NN` タグ一覧
- 指定 SDK の正しい `expo` / `react` / `react-native` / `expo-status-bar` 版
- 現在の `package.json` の依存

### 3. 現在の依存と比較する

表示された「正しい版」と現在の `package.json` を突き合わせる。
- すべて一致していれば固定済み。変更不要である旨を報告して終了。
- ずれていれば次へ。

### 4. package.json を更新する

`expo` / `react` / `react-native` / `expo-status-bar` を手順2の値に書き換える。
このテンプレートには `react-dom` / `react-native-web` も含まれる。コアだけ
手で直すと他の依存とずれやすいので、書き換え後に `npx expo install --fix`
で SDK に合わせて全依存を整合させるのが確実（`--check` で差分の事前確認も可能）。

### 5. 再インストールして型チェックする

```sh
rm -rf node_modules package-lock.json && npm install
npx tsc --noEmit
```

`tsc` が通れば固定完了。`app.json` に `sdkVersion` を明示している場合はそれも
合わせる（このテンプレートは既定では持たないので通常は不要）。

### 6. 報告する

- 稼働中と判断した SDK 番号と、その根拠（changelog の記述など）
- 変更した依存の before/after
- `tsc` の結果
- 併せて `CLAUDE.md` 内の「現在 SDK NN に固定」の記述も実態に合わせて更新するか
  ユーザーに確認する。

## 注意

- 審査状況は時間とともに変わる。過去のメモや記憶ではなく、必ず手順1で最新を確認する。
- SDK を上げると Expo Go 側が追いついていない場合に実機で開けなくなる。
  「動いていたのに実機で開けない」ときは、まずここを疑う。
