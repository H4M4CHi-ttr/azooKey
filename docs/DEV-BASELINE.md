# Phase A: azooKey Dev のベースライン

インポート機能を追加する前に、識別子とストレージを分離したビルドを記録します。

- 専用ブランチ: `feature/dev-dictionary-import`
- 本体: `io.github.h4m4chi-ttr.azookey.dev.a159b2`
- キーボード拡張: `io.github.h4m4chi-ttr.azookey.dev.a159b2.keyboard`
- App Group: `group.io.github.h4m4chi-ttr.azookey.dev.a159b2`
- 表示名: 本体・キーボードとも `azooKey Dev`
- URL: `azooKeyDev://`
- 正規版のAssociated Domainsとファイルの所有宣言は開発版から除去。カスタムキーボードのファイル選択はアプリ内から利用します。

`Config/Dev.xcconfig`をDebug/Release共通で読み込みます。正規版のApp Groupへのフォールバックやデータ移行は行いません。AltStoreが付加するチームIDは、開発版のグループに限って実行時に解決します。

GitHub Actionsの **azooKey Dev unsigned IPA** を専用ブランチで手動実行します。macOS 15 / Xcode 26.3で、Releaseビルド、IPA内の本体・Keyboard.appexと識別子・署名メタデータを検査します。App Store Connectへの送信処理やAppleの秘密情報は使いません。初回の手動実行は未登録のため404になりました。ユーザーの明示許可を得た専用ブランチへのpushで登録した後、Workflow ID `390655469`を指定した手動実行に成功しました。mainは変更していません。Phase Aの再生成には手動入力`build_baseline=true`を指定します。この場合は固定版のPhase Aのみを生成し、Phase Bのインポート・既存変換回帰テストは実行しません。Phase Bの検証結果は`DEV-VALIDATION.md`で別に記録しています。

## AltStoreへ渡すファイル

`azooKey-Dev-baseline-resign.ipa`を使います。未署名ベースラインと同じソースから、Apple証明書を使わないad-hoc署名で開発版App Groupsの要求を本体・拡張の両方へ付けたコピーです。AltStore Classicがこの要求を読み、無料Apple Account用のプロファイルで両方を再署名します。コピーの作成だけではiPhoneへインストールできません。

以前保存した`azooKey-Dev-baseline-unsigned.ipa`だけでは、再署名ツールがApp Groups要求を読み取れない可能性があります。共有を確認する導入には再署名用コピーを使ってください。アプリのソースは`d4d59619`から変更していません。

Phase Aには「ファイルからインポート」と「共有テストを開始」ボタンはありません。共有は下記の手動登録語で確認します。

## Windows未導入からの手順

Windows 11 / iPhone 17 Pro（申告されたiOS 26.6.1）向けの案内です。実機での成功はまだ確認していません。

1. [AltStore公式のWindows手順](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)にあるApple配布版のiTunesとiCloudをインストールします。Microsoft Store版とは配布元が異なります。
2. 同じページからWindows版AltServerを取得し、ZIPを展開して`Setup.exe`を実行します。最新版を使ってください。公式掲載のWindows版1.7.4にはiOS 26.4での署名後クラッシュ修正が含まれます。[リリースノート](https://faq.altstore.io/release-notes/altserver)
3. iPhoneをUSBで接続し、ロックを解除して「このコンピュータを信頼」を承認します。iTunesにiPhoneが表示されることを確認し、公式手順に従いWi-Fi同期を有効にします。「消去して同期」や復元を求められた場合は、その操作を進めず表示内容を確認してください。
4. AltServerを管理者として起動します。ファイアウォールの確認が出たら、自宅等のプライベートネットワークへの通信を許可します。右下の通知領域（隠れている場合は`^`）にAltServerがあることを確認します。
5. AltServerの`Install AltStore`から接続したiPhoneを選びます。Apple Accountと必要な認証情報はAltServerの画面へ入力します。
6. iPhoneの「設定 → 一般 → VPNとデバイス管理」で、自分のApple Accountのデベロッパを信頼します。「設定 → プライバシーとセキュリティ → デベロッパモード」を有効にし、案内に従って再起動・確認します。AltStore Classicが開けば、この段階は完了です。
7. `azooKey-Dev-baseline-resign.ipa`をiCloud Drive等でiPhoneの「ファイル」から選べる場所へコピーします。AltServerを起動したままUSB接続を維持し、AltStoreの`My Apps`の`+`からIPAを選びます。ログインを求められたらAltServerと同じApple Accountを使います。
8. 拡張の扱いを聞かれたら、`Keep App Extensions`等の残す選択をします。Keyboard.appexが必要です。正規版の削除・置換を求められた場合は中止します。
9. 下記の共存・キーボード・辞書共有を順番に確認します。エラー時は段階とエラー文を記録し、正規版の設定や保存先は変更しません。

## 実機で確認する操作（すべて未検証）

1. 正規版を削除せずに、開発版IPAを本体と拡張を含めて再署名・インストールする。
2. ホーム画面に正規版と`DEV`アイコンの`azooKey Dev`が並ぶ。
3. iOSの「設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加」で開発版だけを追加する。
4. 必要なフルアクセスは**開発版だけ**に許可する。正規版の設定を変更しない。
5. 開発版を開き、共有領域のエラーが出ないことを確認する。
6. 開発版の「ユーザ辞書 → +」で、読み`でぶかくにん`、単語`開発版確認A159`を登録する。「この単語をシェアする」はOFFにして保存。開発版キーボードを一度閉じてからメモ等で開き直し、同じ読みを入力して候補に現れることを確認する。これが本体から拡張への辞書共有の確認になる。
7. 正規版で同じ単語が登録されていないこと、以前の設定・辞書が保たれていることを読み取りで確認する。

インストールできたことだけでは合格にしません。共有領域エラー、拡張起動、候補への反映は別々に記録します。署名期限は7日なので、正規版を残したまま開発版のみ更新します。
