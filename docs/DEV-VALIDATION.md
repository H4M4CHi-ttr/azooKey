# azooKey Dev 検証記録

専用ブランチ: `feature/dev-dictionary-import`。実機操作はすべて未検証です。

## Phase A

- ベースラインの識別子分離チェック: WindowsとGitHub macOSで成功。
- iPhone向けReleaseビルド: インポート機能を含まない`d4d59619`の既存Build on pushで成功。[実行](https://github.com/H4M4CHi-ttr/azooKey/actions/runs/39443264336)
- 専用WorkflowでのSwiftテスト・IPA生成: 実行中またはランナー待ち。最終結果を追記します。
- 初期の共有ID読取処理はFoundationの必須引数/型の差で失敗し、修正しました。失敗した実行を成功とは扱いません。
- 手動Workflowは既定ブランチ未登録により404。ユーザーの明示許可を得て専用ブランチへのpushトリガーを追加しました。main・App Store Connectは変更していません。

## Phase B

- Pythonの配布保護テスト: 5件成功。正規版ID混入・拡張欠落・署名状態を検出します。
- Swiftパーサー/アプリ統合テスト: CIで検証中。文字コード、品詞、引用符、不正行、重複、5万件の解析、保存データ保持、辞書生成、書出失敗の復元を対象にしています。
- WindowsではSwift/Xcodeが見つからないため、Swiftテストをローカル成功とは報告しません。
- アイコン: 生成画像と1024px・不透明PNGに整えた最終画像を目視確認済み。元画像の削除はしていません。

## Phase C

本体・拡張の無料署名、iPhone 17 Proへの導入、正規版との共存、グループ共有、変換候補、削除の分離、再署名後の保持はすべて**未検証**です。[実機チェックリスト](WINDOWS-DEV.md#phase-c-実機チェックリスト)で確認してください。

## アイコンの作成記録

組み込みimage generationで新規作成（生成1回）。指示: 濃紺背景、白いキーボードとシアンのキー、下部にオレンジ帯と大きく読める`DEV`、不透明な正方形。既存の正規版アイコンとは区別する。保存先は`MainApp/Assets.xcassets/AppIconDev.appiconset/DevIcon.png`です。
