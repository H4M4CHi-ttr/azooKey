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

GitHub Actionsの **azooKey Dev unsigned IPA** を専用ブランチで手動実行します。macOS 15 / Xcode 26.3で、既存Swiftテスト、Releaseビルド、IPA内の本体・Keyboard.appexと識別子を検査します。App Store Connectへの送信処理やAppleの秘密情報は使いません。新規Workflowの手動実行UIはGitHubの既定ブランチ上の登録状態に依存します。登録が必要な場合は別途承認が必要です。既定ブランチを自動で変更しません。

## 実機で確認する操作（すべて未検証）

1. 正規版を削除せずに、開発版IPAを本体と拡張を含めて再署名・インストールする。
2. ホーム画面に正規版と`DEV`アイコンの`azooKey Dev`が並ぶ。
3. iOSの「設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加」で開発版だけを追加する。
4. 必要なフルアクセスは**開発版だけ**に許可する。正規版の設定を変更しない。
5. 開発版を開き、共有領域のエラーが出ないことを確認する。
6. 開発版へテスト単語を1件登録し、開発版キーボードの候補へ反映されることを確認する。
7. 正規版で同じ単語が登録されていないこと、以前の設定・辞書が保たれていることを読み取りで確認する。

インストールできたことだけでは合格にしません。共有領域エラー、拡張起動、候補への反映は別々に記録します。署名期限は7日なので、正規版を残したまま開発版のみ更新します。
