<p align="center">
  <img src="docs/assets/mac-drag-scroll-icon.png" width="112" alt="Mac Drag Scrollアプリアイコン">
</p>

<h1 align="center">Mac Drag Scroll</h1>

<p align="center">
  <strong>macOSに馴染む、中ボタンドラッグスクロール。</strong><br>
  ホイールを押したままマウスを動かすだけで、長いページ、エディタ、タイムライン、キャンバスを滑らかに移動できます。
</p>

<p align="center">
  <a href="https://github.com/martincalander/MacDragScroll/releases/latest"><img alt="最新リリース" src="https://img.shields.io/github/v/release/martincalander/MacDragScroll?display_name=tag&sort=semver"></a>
  <a href="https://github.com/martincalander/MacDragScroll/actions/workflows/checks-summary.yml"><img alt="Checks 3/3" src="https://github.com/martincalander/MacDragScroll/actions/workflows/checks-summary.yml/badge.svg?branch=main"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/martincalander/MacDragScroll"><img alt="OpenSSF Scorecard" src="https://api.scorecard.dev/projects/github.com/martincalander/MacDragScroll/badge"></a>
  <a href="https://www.bestpractices.dev/projects/13546"><img alt="OpenSSF Best Practices" src="https://www.bestpractices.dev/projects/13546/badge"></a>
  <img alt="macOS 14以降" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="MITライセンス" src="https://img.shields.io/badge/license-MIT-2f80ed.svg"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a>
</p>

<p align="center">
  <img src="docs/assets/mac-drag-scroll-hero.png" alt="小さなLiquid Glassインジケーターで長い文書を操作するMac Drag Scroll">
</p>

<p align="center">
  <strong><a href="https://github.com/martincalander/MacDragScroll/releases/latest">macOS版をダウンロード</a></strong>
  &nbsp;·&nbsp;
  <a href="#クイックスタート">Homebrewでインストール</a>
  &nbsp;·&nbsp;
  <a href="#ソースからビルド">ソースからビルド</a>
</p>

Mac Drag Scrollは、Windowsでおなじみの中クリックドラッグジェスチャーをmacOSの外部マウスで使えるようにする、小さなネイティブメニューバーユーティリティです。アカウントもクラウドサービスも不要で、通常のトラックパッドジェスチャーを妨げません。

## 動作デモ

<p align="center">
  <img src="docs/assets/mac-drag-scroll-usage-demo.gif" width="800" alt="中ボタンを押したままドラッグしてスクロールし、素早く反転してから離して停止する操作">
</p>

マウスの中ボタンを押したまま、開始位置から離れるように動かします。距離で速度、方向でスクロールベクトルが決まり、ボタンを離すとすぐに停止します。小さなビジュアライザーは、サイズ、外観、アニメーションを調整したり、完全にオフにしたりできます。

## Mac Drag Scrollを選ぶ理由

| | |
| --- | --- |
| **自然な操作** | 1回の連続したジェスチャーで、縦、横、斜めにスクロールできます。 |
| **安定した対象** | ドラッグを開始したウィンドウにジェスチャーが固定されます。 |
| **外部マウスに特化** | トラックパッドジェスチャーを横取りしたり、割り当て直したりせずに無視します。 |
| **素早いフィードバック** | 1つのドットを持つLiquid Glassビジュアライザーが、方向、距離、ダブルクリック、高速反転に反応します。 |
| **メニューバーに常駐** | バックグラウンドで静かに動作し、必要なときだけ設定を開けます。 |
| **復旧しやすい設計** | 権限修復、永続設定、ローカル診断、検証済みアップデートを備えています。 |

## クイックスタート

### Homebrew

```sh
brew install --cask martincalander/tap/mac-drag-scroll
```

### 直接ダウンロード

1. [最新リリース](https://github.com/martincalander/MacDragScroll/releases/latest)から`MacDragScroll.dmg`をダウンロードします。
2. ディスクイメージを開き、**Mac Drag Scroll**を**アプリケーション**へドラッグします。
3. Finderでアプリを右クリックして**開く**を選び、初回起動を確認します。
4. macOSに求められたら、アクセシビリティを許可します。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-install-demo.gif" width="800" alt="Mac Drag Scrollをアプリケーションフォルダへドラッグする手順">
</p>

<details>
<summary><strong>初回起動で「右クリック → 開く」が必要な理由</strong></summary>

現在のリリースには固定されたプロジェクト用コード署名がありますが、有料のApple Developerメンバーシップが必要なDeveloper ID署名と公証は行っていません。そのため、新しくダウンロードしたビルドを通常どおりダブルクリックすると、macOSがブロックする場合があります。Finderで**Mac Drag Scroll**を右クリックし、**開く**を選んで確認してください。手動でダウンロードしたビルドごとに1回だけ必要です。

固定されたプロジェクトIDにより、アップデート後もアクセシビリティの許可が維持されます。リリースファイルを独立して検証できるよう、Sparkle署名とGitHubのビルド来歴も公開しています。詳しくは[セキュリティ](SECURITY.md)と[リリース手順](docs/RELEASING.md)を参照してください。
</details>

<details>
<summary><strong>Homebrewを使わずにインストール</strong></summary>

```sh
curl -fsSL https://github.com/martincalander/MacDragScroll/raw/main/install.sh | bash
```
</details>

## 権限を許可する

Mac Drag Scrollは、設定されたマウスボタンをグローバルに検出し、対象ウィンドウへスクロールイベントを送信するために**アクセシビリティ**権限を使用します。入力内容の記録やコンテンツの確認には使用しません。入力監視は不要です。

<p align="center">
  <img src="docs/assets/mac-drag-scroll-permission-demo.gif" width="800" alt="Mac Drag Scrollのアクセシビリティを有効にする手順">
</p>

**システム設定 → プライバシーとセキュリティ → アクセシビリティ**を開き、Mac Drag Scrollを有効にします。アクセスが有効になるとアプリが自動的に確認して監視を開始します。macOSがイベントタップをすぐに有効化しない場合にのみ、再起動操作が表示されます。

## 操作感を調整する

メニューバーアイコンから設定を開きます。

| 設定 | 調整内容 |
| --- | --- |
| 速度と加速 | 基本のスクロール速度と、ドラッグ距離に応じた速度の上がり方。 |
| デッドゾーン | ジェスチャー開始位置の周囲にあるニュートラル範囲。 |
| カーソル固定 | 必要に応じてポインタを中クリックの開始位置に保ち、ポインタ位置に反応するコンテンツをスクロールし続けます。 |
| トリガー | 既定は中クリック。主ボタンと副ボタンの代替設定には安全用の修飾キーを使用します。 |
| ビジュアライザー | サイズ、不透明度、色合い、ガラスの強さ、モーション効果。 |
| 除外アプリ | ドラッグスクロールを無効にしておくアプリ。 |
| 起動動作 | ログイン時の起動と、メニューバーで動作を続けるかどうか。 |
| アップデート | 自動確認、リリース履歴、手動アップデート操作。 |

設定はmacOSユーザーごとに保存され、アプリのアップデートや通常の削除・再インストール後も維持されます。保存場所と復旧手順は[サポート](SUPPORT.md)に記載しています。

## 信頼性のための設計

- **端末内で完結:** アカウント、分析、広告、クラウドバックエンドはありません。
- **限定された入力範囲:** 設定したマウストリガーだけがスクロールを開始し、トラックパッドジェスチャーは除外されます。
- **権限の状態を監視:** 必要なアクセスが不足したり取り消されたりすると、スクロールを自動的に無効にします。
- **確認できるリリース:** 自動チェック、シークレットスキャン、CodeQL、Sparkle署名、GitHub Attestationsを公開リポジトリで実行します。
- **非公開の診断情報:** クラッシュレポートは、ユーザーが共有を選ぶまでMac内に保存されます。

[プライバシー](PRIVACY.md)、[セキュリティ](SECURITY.md)、実装の[アーキテクチャ](ARCHITECTURE.md)も参照してください。

## ソースからビルド

macOS 14以降とXcode 26.2以降が必要です。

```sh
git clone https://github.com/martincalander/MacDragScroll.git
cd MacDragScroll
xcodebuild -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -configuration Debug \
  build
```

テストスイートを実行するには次のコマンドを使います。

```sh
xcodebuild -project macdragscroll.xcodeproj \
  -scheme macdragscroll \
  -destination 'platform=macOS' \
  test
```

コントリビューションを歓迎します。最初に[Contributing](CONTRIBUTING.md)、[Code of Conduct](CODE_OF_CONDUCT.md)、[Roadmap](ROADMAP.md)を確認してください。

## プロジェクトガイド

| ドキュメント | 内容 |
| --- | --- |
| [サポート](SUPPORT.md) | 権限修復、診断、よくある質問。 |
| [アーキテクチャ](ARCHITECTURE.md) | 実行時の境界、安全性の不変条件、イベントフロー。 |
| [プライバシー](PRIVACY.md) | アプリがアクセスできる内容と、収集しない情報。 |
| [セキュリティ](SECURITY.md) | 脆弱性の報告方法とリリース検証。 |
| [ガバナンス](GOVERNANCE.md) | メンテナーの役割、レビューポリシー、プロジェクトの意思決定。 |
| [変更履歴](CHANGELOG.md) | バージョン履歴とリリースノート。 |
| [Scorecardノート](docs/SCORECARD.md) | OpenSSFの状況、対策、現在の制限。 |
| [リリース手順](docs/RELEASING.md) | メンテナー向けのリリースと来歴の手順。 |

## 動作要件

- macOS 14以降
- 中ボタンまたはクリック可能なスクロールホイールを備えた外部マウス
- アクセシビリティ権限

## クレジット

- 日本語翻訳レビュー: [uglykatsuki](https://github.com/uglykatsuki)

## ライセンス

Mac Drag Scrollは[MIT License](LICENSE)で公開されています。

<p align="center">
  制作: <a href="https://martincalander.com">Martin Calander</a>
</p>
