# azooKey Dev 検証記録

専用ブランチ: `feature/dev-dictionary-import`。実機操作はすべて未検証です。

## Phase A

- ベースラインの識別子分離チェック: WindowsとGitHub macOSで成功。
- iPhone向けReleaseビルド: インポート機能を含まない`d4d59619`の既存Build on pushで成功。[実行](https://github.com/H4M4CHi-ttr/azooKey/actions/runs/39443264336)
- 専用WorkflowのPhase AでReleaseビルド・未署名IPA生成・本体/Keyboard.appex/識別子検査が成功。[実行と成果物](https://github.com/H4M4CHi-ttr/azooKey/actions/runs/39446599304)。Phase AとmacOS上の当時のパーサーテスト成功後、古いコードの後続処理を止めて最新版へ実行枠を移しました。このため実行全体は取消表示です。
- 取得したPhase A IPAはSHA-256が一致し、本体と拡張の実行ファイルがARM64 Mach-OであることもWindowsで確認しました。
- 初期の共有ID読取処理はFoundationの必須引数/型の差で失敗し、修正しました。失敗した実行を成功とは扱いません。
- 初回の手動実行はWorkflow未登録により404。ユーザーの明示許可を得て専用ブランチへのpushで登録し、その後はID指定のworkflow_dispatchが成功しました。[手動実行記録](https://github.com/H4M4CHi-ttr/azooKey/actions/runs/39447983699)。古いコードの実行枠は最新版へ移しています。main・App Store Connectは変更していません。

## Phase B

- Pythonの配布保護・署名テスト: Windowsでは5件成功、macOS専用1件はスキップ。macOSでは6件成功し、証明書なし署名とentitlements XMLの往復を含みます。正規版ID混入・拡張欠落・署名状態も検出します。
- SwiftパーサーはLinux/macOSとも17件成功。iOSシミュレーターのインポート統合テスト8件と幅比較1件、計9件が成功。文字コード、品詞、引用符、不正行、重複、5万件の解析、保存データ保持、辞書生成、書出失敗の復元を対象にしています。
- WindowsではSwift/Xcodeが見つからないため、Swiftテストをローカル成功とは報告しません。
- iOSのテスト用ビルドで、既存幅比較の未解決シンボルと、既存辞書ストアテストの削除済みAPIを修正しました。アプリへのパーサーの直接リンク不足も検出し、本体・テスト両方の直接依存へ修正。構成チェックは修正前に失敗し、修正後に成功しました。
- アイコン: 生成画像と1024px・不透明PNGに整えた最終画像を目視確認済み。実際のIPAでAppIconDevが選択されていることも検査しました。元画像は削除していません。

## 機能追加版のIPA

[実行 39466109224](https://github.com/H4M4CHi-ttr/azooKey/actions/runs/39466109224)の新機能テスト・iPhone Release・IPA検査・アップロードが成功しました。成果物は`479b15a3`のソースから生成しています。

- `azooKey-Dev-unsigned.ipa`: 127,925,038 bytes。Apple Developer証明書・プロファイルなし。
- `azooKey-Dev-resign.ipa`: 128,626,147 bytes。証明書なしad-hoc署名で本体・拡張のApp Groups要求を保持し、読み戻しとdeep/strict検証が成功。Windows側での再署名が必要です。
- 取得後に両IPAのSHA-256がCI同梱値と一致し、両方の本体・Keyboard.appexがARM64、AppIconDevであることをWindowsでも再確認しました。
- 生成ファイルを実際の変換エンジンへ渡し、テスト登録語「開発テスト」が候補に出る検証も成功しました。
- 大量データは5万件のパース、1万件のHotfix重複除外、同じ読み65,536候補の安全な拒否を検証しました。iPhone実機の時間・ピークメモリは未測定です。

## Phase C

本体・拡張の無料署名、iPhone 17 Proへの導入、正規版との共存、グループ共有、変換候補、削除の分離、再署名後の保持はすべて**未検証**です。[実機チェックリスト](WINDOWS-DEV.md#phase-c-実機チェックリスト)で確認してください。

## アイコンの作成記録

組み込みimage generationで新規作成（生成1回）。指示: 濃紺背景、白いキーボードとシアンのキー、下部にオレンジ帯と大きく読める`DEV`、不透明な正方形。既存の正規版アイコンとは区別する。保存先は`MainApp/Assets.xcassets/AppIconDev.appiconset/DevIcon.png`です。

## 既存回帰テストの失敗・未解決事項

同じ実行の`Existing converter and keyboard regressions`は失敗しました。取得した`legacy-tests.log`で次の不一致を確認しています。全テスト合格とは扱いません。

| 対象 | 観測結果 |
| --- | --- |
| `testFullConversion`、`testGradualConversion`、`testGradualConversionWithDelete`、`testSemiGradualConversion` | 「ロサンゼルス近郊」の期待に対し「ロサンゼルス銀行」が第一候補となり、4件失敗。 |
| `testMeaningBasedConversionAccuracy` | 0.582089552238806となり、既存の基準`> 0.7`を満たさない。 |
| `DicdataStoreTests.testMustWords` | 「テキナ」に対する「的な」が見つからない。今回のAPI移行は固定版エンジン自身の呼び出しと一致。同エンジンの候補一覧にはこの期待語がないものの、API移行前との動作比較までは未実施のため、原因は確定していない。 |
| `testMozcEvaluationData` | 実行中に`unexpected exit, crash, or test timeout`でプロセスが再起動。成功結果なし。詳細原因は未確定。 |
| iOS 27を必要とする既存テスト3件 | iOS 26シミュレーター上でスキップ。成功には数えない。 |

`testAccuracy`、`testMustCases`、`testRoman2KanaGradualConversion`、`testVerbalAccuracy`などは成功しています。ログには変換モジュールのクラス二重読込警告もあり、異常終了との因果関係は未確定です。ConverterTestsとエンジンの固定リビジョン、辞書語の期待値・精度基準は変更していません。これらの既存精度・評価環境の調査は未解決として残します。

新機能の回帰テストを先に実行し、合格後に開発用IPAを生成してから既存回帰を実行します。したがって「IPAを生成できた」と「全既存テストが合格した」は同義ではありません。IMEの変換精度そのものの改修は今回のインポート・署名環境の変更から切り離しています。
