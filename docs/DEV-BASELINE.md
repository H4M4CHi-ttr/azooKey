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

## 実機で確認する操作（すべて未検証）

1. 正規版を削除せずに、開発版IPAを本体と拡張を含めて再署名・インストールする。
2. ホーム画面に正規版と`DEV`アイコンの`azooKey Dev`が並ぶ。
3. iOSの「設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加」で開発版だけを追加する。
4. 必要なフルアクセスは**開発版だけ**に許可する。正規版の設定を変更しない。
5. 開発版を開き、共有領域のエラーが出ないことを確認する。
6. 開発版へテスト単語を1件登録し、開発版キーボードの候補へ反映されることを確認する。
7. 正規版で同じ単語が登録されていないこと、以前の設定・辞書が保たれていることを読み取りで確認する。

インストールできたことだけでは合格にしません。共有領域エラー、拡張起動、候補への反映は別々に記録します。署名期限は7日なので、正規版を残したまま開発版のみ更新します。
