# Codex bar

macOSデスクトップにCodexの残り使用量を表示する、小さなメニューバーアプリ。
SwiftUI + AppKit製です。利用時のXcode・開発者アカウント設定は不要です。

## インストール

1. この非公開リポジトリにアクセスできるGitHubアカウントでログイン。
2. [Releases](https://github.com/piyoharu97/codex-bar/releases/latest) から `Codex-bar-v…-universal.zip` をダウンロードして展開。
3. `Codex bar.app` をユーザーの「アプリケーション」フォルダへ移動して起動。
4. 同じMacの公式Codex CLIでChatGPTログインしておく。CLIを自動検出できない場合はメニューバーの「Codex実行ファイルを選択…」で指定。

対応OSは **macOS 14以降**。配布バイナリはApple Silicon（Mシリーズ）とIntelのUniversalです。
Apple Siliconで動作確認済み。Intel版はクロスコンパイルとバイナリ構成の確認のみで、Intel実機では未検証です。
公式CLIがIntel Macに未導入なら、OpenAIの公式Codex CLIを別途インストールする必要があります。

現在の配布物はアドホック署名で、Appleの公証はしていません。ダウンロード先のMacでは初回起動がブロックされる場合があります。
内容と配布元を確認したうえで、必要な場合はmacOSの「システム設定 → プライバシーとセキュリティ」からこのアプリだけを許可してください。
会社管理Macでは管理方針に従ってください。Gatekeeper全体の無効化は不要です。
警告を減らした一般向け配布にはDeveloper ID署名とApple公証が必要です。

## 使い方

- 細いバーで5時間・週間枠の残り％とリセット日時を表示。
- クリックでCodexを起動、右クリックで設定、ドラッグで位置を移動。
- 背景は黒・ダーク・ダークグラス・グラス。ロゴはCodex／ChatGPT。
- 淡い水色のスイッチでログイン時起動をオン／オフ。
- 公式CLIの `account/rateLimits/read` を5分ごと・スリープ復帰時・手動で取得。
- 存在しない枠は未提供、取得失敗・古いデータ・リセット時刻経過を区別。

WidgetKitの標準ウィジェットではなく、デスクトップに表示する独立アプリです。ウィジェットギャラリーへの追加は不要です。
FinderのアイコンはCodex固定です。ロゴ設定はウィジェット・メニューバー・実行中のアプリに反映します。

## アップデート

設定の「アップデート」から配布ページを開けます。
新版の自動検知には、**各Macで**この非公開リポジトリ専用のGitHub読み取りトークンを設定します。
設定方法は [アップデート設定](docs/UPDATES.md) を参照してください。

自動確認は1日1回。通知の許可は設定内の「更新通知を許可…」から行います。
アプリのダウンロード・置換は手動です。新しいZIPを展開し、Codex barを終了して既存アプリを置き換えてください。
保存先・Bundle IDを維持するため、背景・配置・ログイン時起動などの設定は基本的に引き継がれます。
ローカル署名の変更によりキーチェーンへのアクセス確認が出る場合があります。

## 認証情報と保存データ

Codexのトークン・Cookie・auth.jsonを直接読み取りません。認証は公式CLIに委ねます。
更新用GitHubトークンはmacOSキーチェーンに端末限定で保存し、ソース・設定ファイル・配布物に含めません。
GitHubへの問い合わせ先を固定し、HTTPリダイレクトで認証ヘッダーを別の場所へ転送しません。
このリポジトリに実アカウントの使用量・ログ・認証情報は含めません。

## ビルド・検証

開発にはXcode本体またはCommand Line Toolsが必要です。アプリを使う人には不要です。

```sh
./Tools/check.sh
./Tools/package-release.sh
```

`dist/` にUniversal ZIPとSHA-256の確認ファイルを生成します。
`VERSION` と `BUILD_NUMBER` でバージョンを管理します。
VERSIONとBUILD_NUMBERを更新してmainへ保存すると、GitHub Actionsが検証・ビルド・Releases公開を行います。VERSIONと一致するタグのpushでも実行できます。既存リリースの添付ファイルは上書きしません。
Actionsの利用制限や課金設定はGitHubアカウント側の設定に従います。
詳しくは [リリース手順](docs/RELEASING.md) を参照してください。

## 参考・ロゴ

- [公式Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
- [Apple — Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

ロゴは利用者から提供されたCodex画像、および公式ChatGPTアプリに含まれる元のChatGPTベクトルデータを使用しています。
ロゴの権利は各権利者に帰属します。本アプリは個人用の非公式ユーティリティです。
