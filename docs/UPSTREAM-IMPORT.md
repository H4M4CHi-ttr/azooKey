# 本家PRへ分ける変更

このブランチは実機テスト用フォークです。本家へは辞書インポート機能だけを切り出し、開発版の名前や署名経路を含めない方針です。Issue・PRはまだ投稿していません。

## 機能側

- `DictionaryImport/`: Foundationだけで動くローカルSwift Package。CSV/TSV/plist解析、文字コード、品詞対応、重複と入力上限、XCTest。
- `azooKey.xcodeproj/project.pbxproj`: 本体とテストからローカルPackageを直接参照・リンク。新しい外部ライブラリはありません。
- `UserDictionaryImportView.swift`: Files選択、バックグラウンド読込、取り込み候補の確認。
- `UserDictionaryImportTransaction.swift`: 既存データへの追加、未共有フラグ、生成済みファイルの公開と通常エラー時の復元。
- 既存辞書画面・保存・AdditionalDictManager/UserDictionaryUpdater: UIへの入口、バックグラウンド生成、生成失敗時に保存しない経路。通常の手動登録は従来の保存経路を維持します。
- `azooKeyTests/UserDictionaryImportTests.swift`: 既存フラグ・テンプレートの維持、非共有、保存データ保護、生成、書出失敗の復元。

本家モデルは人名/地名/ラ行五段等のフラグで品詞を表現しています。一般の動詞活用や任意のCIDを新設せず、対応しない品詞はプレビューへ警告を出す設計です。取り込んだ語を共有申請する呼び出しはありません。

## フォーク固有

`Config/Dev.xcconfig`、Bundle ID/表示名/entitlements/URLスキーム、DEVアイコン、`DevAppIdentity`、起動ガード、`DevDictionarySharingView`、開発版Workflow、Windows導入文書、配布パッケージ検査は本家機能PRから外します。

`AzooKeyUserDictionary.swift`の共有テスト行と`KeyboardViewController.swift`の診断用応答はフォーク固有です。Swift Packageの追加を含むため、本家への提案時は既存Contributionガイドに沿って、仕様・テスト結果・品詞の制約・大量データの上限をIssueで先に相談する案です。投稿には別途許可が必要です。

## 検証環境に合わせた既存コードの互換修正

- `ResizingRect.swift`の幅比較は、IntelシミュレーターのDebugリンクで未解決だった数値補助関数を使わず、標準の絶対値比較で0.1ポイントの許容幅を保つ形へ変更。専用の境界テストを追加しました。
- 既存`DicdataStoreTests`の削除済みAPI呼び出し7か所を、固定リビジョンのエンジン自身のテストに合わせて`lookupDicdata`へ移行。語の期待値を維持し、入力位置と変換後文字位置の区別も検証します。

これらはインポート機能の本家PRとは別に整理できます。根拠は[使用中エンジンのテスト](https://github.com/azooKey/AzooKeyKanaKanjiConverter/blob/04ce2ec3afe2bd6f92fcae1dc15a2357d332c27a/Tests/KanaKanjiConverterModuleWithDefaultDictionaryTests/DicdataStoreTests/DicdataStoreTests.swift)です。

## 残る確認

実機のメモリ・所要時間、キーボード再起動後の候補反映、各インストーラーによる無料署名後の共有は未検証です。複数ファイルの公開は通常エラーへ復元できますが、プロセス強制終了時の完全な原子性を保証しません。検証結果は`DEV-VALIDATION.md`へ記録します。
