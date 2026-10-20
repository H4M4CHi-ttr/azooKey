# azooKey

## このフォーク: azooKey Devと辞書インポート

**App Store版azooKeyを残したまま、別アプリ「azooKey Dev」でテストするフォークです。** 正規版の削除・上書き・設定変更・データ消去は行いません。開発は`feature/dev-dictionary-import`で進めます。実機動作は未検証で、インストール成功だけでは動作成功にしません。

- ユーザ辞書画面の「ファイルからインポート」でCSV・TSV（Google日本語入力/Mozc/MS-IME）とmacOSのテキスト置換plistを選択します。文字コード・品詞・重複・不正行を解析し、候補を確認してから追加します。全件置換や単語の自動共有申請は行いません。
- 本体は`io.github.h4m4chi-ttr.azookey.dev.a159b2`、拡張は同IDの`.keyboard`、App Groupは`group.io.github.h4m4chi-ttr.azookey.dev.a159b2`に分離。表示名は両方`azooKey Dev`、URLは`azooKeyDev://`、アイコンはDEV表示です。本家のAssociated Domainsとファイル所有・カスタムUTI宣言も開発版から除いています。
- [開発版Workflow](.github/workflows/dev-unsigned-ipa.yml)はGitHub-hosted macOS / Xcode 26.3でSwiftテストとiPhone Releaseビルドを行います。手動実行に加え、ユーザーの許可を得て専用ブランチへのpushでも起動します。App Store Connectへは送信しません。

### Windowsから実機へ入れる

1. [Actions](https://github.com/H4M4CHi-ttr/azooKey/actions)から、成功した **azooKey Dev unsigned IPA** のArtifactsを取得します。
2. ZIP内の`azooKey-Dev-resign.ipa`をAltStore ClassicまたはSideloadlyで、無料Apple Accountを使って再署名します。**Keyboard.appexを残して、本体と拡張の両方を署名**してください。完全未署名の`azooKey-Dev-unsigned.ipa`も同梱しますが、直接インストールはできません。再署名用IPAはApp Groups要求を残すため、Apple証明書なしのad-hoc署名を付けています。
3. 開発版だけをiOSのキーボードへ追加し、必要なフルアクセスも開発版だけに許可します。ユーザ辞書画面の共有テストと、手動登録語・インポート語の候補反映を順に確認します。

無料署名は7日で期限切れになり、同じアカウント・開発版IDでの更新が必要です。Appleの現行表ではApp Groupsは無料でも利用可能ですが、署名ツールによるID変更後に本体と拡張が同じグループを使えるかを実機で確認します。AltStoreのグループ名書換えには開発版の範囲内で追従します。正規版の共有先へはフォールバックしません。

詳しい手順、Bundle ID書換え・無料署名の制約、失敗の切り分け、実機チェックリストは[Windows実機テストガイド](docs/WINDOWS-DEV.md)に記載しています。[Phase A](docs/DEV-BASELINE.md)、[検証結果](docs/DEV-VALIDATION.md)、[本家PR向けの変更整理](docs/UPSTREAM-IMPORT.md)も参照してください。

---

azooKeyはiOS / iPadOS向けの日本語キーボードアプリです。Swiftで実装され、「ニューラルかな漢字変換システム Zenzai」を含む独自開発の高精度変換エンジン、ライブ変換、さらにカスタムキー・カスタムタブなどのユニークなカスタマイズ機能を提供します。

azooKeyは[App Store](https://apps.apple.com/jp/app/azookey-%E8%87%AA%E7%94%B1%E8%87%AA%E5%9C%A8%E3%81%AA%E3%82%AD%E3%83%BC%E3%83%9C%E3%83%BC%E3%83%89%E3%82%A2%E3%83%97%E3%83%AA/id1542709230)で公開しています。

azooKeyの変換エンジンについては[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を参照ください。

azooKeyのmacOS版については[azooKey-Desktop](https://github.com/azooKey/azooKey-Desktop)を参照ください。

## コミュニティ＆ベータ版

azooKeyの開発に参加したい方、使い方に質問がある方、要望や不具合報告がある方は、ぜひ[azooKeyのDiscordサーバ](https://discord.gg/dY9gHuyZN5)にご参加ください。

開発中のベータ版は[TestFlight](https://testflight.apple.com/join/x6TKEeB2)で利用できます。フィードバックをDiscordやIssue等でお寄せください。

## 開発ガイド
パフォーマンス改善、バグ修正、機能追加などのPull Requestを歓迎します。機能追加の場合は事前にIssueで議論した方がスムーズです。

開発は基本的に`main`で行います。新規にPRを作成する場合、まずこのレポジトリをフォークし、`main`からブランチを切ってください。

[Let's Contribute](docs/CONTRIBUTING.md)も合わせてお読みください。

### ビルド・利用方法

Apple Developer Account（無料）が必要です。開発環境は最新のXcodeを利用してください。

1. azooKeyを開発環境にクローンします。azooKeyはサブモジュールを利用しているため、`--recursive`オプションを必ず追加してください。

   ```
   git clone https://github.com/azooKey/azooKey --recursive
   ```

1. `azooKey.xcodeproj`を開き、Xcodeの指示に従って「Run (Command+R)」を実行してください。

1. アプリを開くとキーボードのインストール方法が説明されるので、従ってください。

### テスト方法
[Document](docs/tests.md)をご覧ください。

### 辞書の変更

標準辞書は[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)の`KanaKanjiConverterModuleWithDefaultDictionary`に同梱されています。利用する辞書を変更する場合は、同リポジトリ側の辞書参照を変更してください。

### さらに詳しく

`docs/`内の[Document](./docs/overview.md)をご覧ください。

不明な点は気軽にIssue等でご質問ください。

## 今後のリリース
* 現在、v3.0.1に向けた作業を行っています。

## azooKeyを支援する
GitHub Sponsorsをご利用ください。

## ライセンス
Copyright (c) 2020-2025 Keita Miwa (ensan).

azooKeyはMIT Licenseでライセンスされています。詳しくは[LICENSE](./LICENSE)をご覧ください。
