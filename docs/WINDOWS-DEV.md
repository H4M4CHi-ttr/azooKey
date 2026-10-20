# Windows 11からazooKey Devを実機テストする

対象はWindows 11、iPhone 17 Pro、無料Apple Accountです。Macや有料Apple Developer Programは前提にしません。初回は「IPAを取得する」「Windowsで署名する」「共有を確認する」の順に進め、問題があれば切り分け表を参照してください。

**実機操作はすべて未検証です。** 自動ビルドの成功と、キーボード・辞書共有の動作成功は分けて扱います。正規版azooKeyの削除、上書き、設定変更、データ消去は不要です。

## IPAを取得する

1. フォークの[Actions](https://github.com/H4M4CHi-ttr/azooKey/actions)を開き、`feature/dev-dictionary-import`の **azooKey Dev unsigned IPA** を選びます。
2. 全ステップが成功した実行のArtifactsを保存期間の1日以内にダウンロードし、ZIPを展開します。初回はWorkflow未登録で手動実行が404になりました。ユーザーの許可を得た専用ブランチへのpushで登録した後、ID指定の手動実行に成功しました。mainは変更していません。手動での実行は `gh workflow run 390655469 --ref feature/dev-dictionary-import -f build_baseline=false` で行えます。
3. Windows PowerShellで`Get-FileHash .\azooKey-Dev-resign.ipa -Algorithm SHA256`を実行し、同梱の`.sha256`と一致することを確認します。

| ファイル | 署名状態と用途 |
| --- | --- |
| `azooKey-Dev-unsigned.ipa` | 完全未署名。Appleの証明書・プロファイルなし。パッケージ検査用。そのままではインストールできません。 |
| `azooKey-Dev-resign.ipa` | Appleの証明書を使わない`codesign --sign -`のad-hoc署名でApp Groups要求を保持。**Windowsからは原則こちらを使用**し、無料アカウントで再署名します。これも単独ではインストールできません。 |

ここでいうad-hoc署名は、Appleの有料アカウント用「Ad Hoc配布」とは別です。AltStoreの署名ライブラリは実行ファイルの署名からentitlementsを読みます。完全未署名ではApp Groups要求が欠ける可能性があるため、両方を用意しています。[AltSignの実装](https://github.com/rileytestut/AltSign/blob/master/AltSign/Model/ALTApplication.mm)

Phase Aはインポートを含まない固定commit `d4d59619`を使います。最初の比較ビルド後は、手動入力`build_baseline`を有効にした場合だけ再生成します。通常は機能追加版だけをビルドし、Markdownだけのpushでは専用Workflowを再実行しません。

WorkflowはIntel macOS 15 / Xcode 26.3で、Submodule取得、Swiftテスト、iPhone向けReleaseビルド、識別子・拡張・entitlementsの検査を行います。Apple ID、秘密鍵、Developer証明書をGitHubに登録しません。App Store Connect Workflowは起動しません。公開リポジトリの標準GitHub-hostedランナーを使用します。計算時間は無料ですが、Artifactsにはアカウント全体の保存枠があります（GitHub Freeは500 MB、Packagesと共用）。無料枠内で使い、必要ならGitHubの支出上限を0に設定してください。繰り返しビルドした成果物は取得後に整理します。private化・大容量ランナーはこの無料構成の対象外です。[GitHubの料金説明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

## Windowsで署名する

### AltStore Classicを使う

1. [公式Windows手順](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)に従い、Windows版AltServerと必要なApple製iTunes/iCloudを準備します。公式手順はMicrosoft Store版とApple配布版を区別しています。既存環境を無断で入れ替えず、公式の代替手順も確認してください。
2. iPhoneをUSB接続し、PCを信頼します。必要に応じてiTunesのWi-Fi同期を有効にします。
3. AltServerからAltStore Classicをインストールします。Apple Accountと2要素認証は公式アプリの画面にだけ入力します。チャット、リポジトリ、CIログには書きません。
4. iPhone側で開発者を信頼し、必要なら「設定 → プライバシーとセキュリティ → デベロッパモード」を有効にします。
5. `azooKey-Dev-resign.ipa`をiPhoneのFilesへ渡し、AltStore ClassicのMy Appsの追加操作から選びます。アプリ拡張の選択が出たら**Keyboard.appexを残します**。
6. 正規版を削除・置換する旨の案内が出た場合は中止します。開発版のIDへ署名することを確認してから進めます。

AltStore PALではなくClassicを使います。インストール後は下の「共有を確認する」へ進みます。iPhone 17 Proとインストール済みiOSバージョンでの一連の操作は未検証です。

### Sideloadlyを使う

[公式サイト](https://sideloadly.io/)と[FAQ](https://sideloadly.io/faq)を参照し、Windows版と必要なAppleドライバーを準備します。USB接続したiPhoneを選び、`azooKey-Dev-resign.ipa`を指定して無料Apple Accountで署名します。

- 「Remove App Extensions / PlugIns」に相当する設定で、Keyboard.appexを削除しないでください。
- 独自のBundle IDを指定する場合も、開発版の名前空間から変更しないでください。正規版の`DevEn3.azooKey`は指定しません。
- 本体と拡張を同じアカウントで署名します。拡張のIDは署名後の本体IDと整合している必要があります。
- App Groupsの保持・再登録・書き換えは、このIPAでの実機検証が済んでいません。インストールだけ成功して共有テストが失敗する場合は、AltStore Classicと結果を比較してください。

更新時は、同じ署名アカウントと同じ**開発版**Bundle IDを使います。IDやアカウントを変えると、開発版の保存先も変わる可能性があります。正規版を更新先にしません。[Sideloadly FAQ](https://sideloadly.io/faq)

## 無料署名で確認すべき制約

| 項目 | 確認できた範囲と実機での確認点 |
| --- | --- |
| 有効期間 | 無料プロファイルは発行から7日。期限前に再署名・更新します。期限切れ時は開発版の本体・拡張の動作も再確認します。 |
| 上限 | Apple公式は10 App IDs・3台のデバイス・1台あたり3アプリを案内しています。AltStore自身もサイドロードアプリです。本体と拡張には別App IDが必要で、他のアプリを含む残数を確認します。正規版を削除して枠を空ける必要はありません。 |
| App Groups | Appleの現行対応表では無料Apple Developer列も利用可能です。「無料だから必ず不可」とは判断しません。実際に本体と拡張の両プロファイルへ同じグループが付くかは別の検証です。 |
| キーボード拡張 | IPAへ含めるだけでなく、インストール時にも署名して残す必要があります。削除された拡張は設定に表示されません。 |
| フルアクセス | 開発版キーボードから共有コンテナーを利用するため、開発版だけへの許可を確認します。正規版の許可は変更しません。 |
| 署名サービス | Windowsの署名処理はAppleへの通信を行います。辞書ファイルはアプリのFiles選択後に端末内で処理し、署名サービスや共有申請へ送信しません。既存のアプリ機能全体の通信を無効化する変更ではありません。 |

有効期間と上限は[Appleのアカウント説明](https://developer.apple.com/help/account/basics/about-your-developer-account)、App Groupsは[Appleの対応表](https://developer.apple.com/help/account/reference/supported-capabilities-ios)で確認しました。AltStoreの更新動作は[公式Getting Started](https://faq.altstore.io/altstore-classic/your-altstore)も参照してください。確認日: 2026-10-20。

## 共有を確認する

1. ホーム画面に「azooKey」と、オレンジの`DEV`表示の「azooKey Dev」が並ぶことを確認します。
2. iOSの「設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加」で「azooKey Dev」を追加します。必要なフルアクセスは開発版だけに許可します。
3. 開発版のユーザ辞書画面で「共有テストを開始」を押します。
4. メモなどのテキスト入力欄で、地球儀ボタンから**開発版**キーボードへ切り替えます。
5. 開発版へ戻り「キーボードからの応答を確認」を押します。「往復確認済み」なら、本体が書いた乱数値を拡張が読み、応答したことを確認できます。辞書内容はこのテストでは扱いません。
6. 開発版へ固有のテスト単語を手動登録し、開発版キーボードを開き直して候補を確認します。共有テストだけでは変換用辞書の読取成功まで証明できません。
7. [sample.tsv](../DictionaryImport/Fixtures/sample.tsv)などをFilesからインポートし、件数と候補を確認します。

共有領域が取得できない場合、本体やキーボードは診断を表示します。正規版のApp Groupを代わりに利用しません。

## 署名後のIDと共有先の関係

| 対象 | ビルド時の値 |
| --- | --- |
| 本体 | `io.github.h4m4chi-ttr.azookey.dev.a159b2` |
| Keyboard Extension | `io.github.h4m4chi-ttr.azookey.dev.a159b2.keyboard` |
| App Group | `group.io.github.h4m4chi-ttr.azookey.dev.a159b2` |
| 表示名 | 本体・拡張とも`azooKey Dev`（日本語のInfoPlistローカライズも変更） |
| URLスキーム | `azooKeyDev://` |

値は`Config/Dev.xcconfig`にまとめ、Debug/Releaseの両方へ適用しています。SharedStoreは開発版の共有IDを使います。UserDefaults.standardは署名後の各アプリのコンテナー、辞書・学習・テーマ等の共有ファイルは開発版グループに分離されます。正規版データの読み取り・移行処理は追加していません。

AltStoreの公開実装は、App Groupに`.TEAMID`を付けて登録し、両バンドルのInfo.plistへ`ALTAppGroups`を保存します。このため開発版は、埋込プロファイルと`ALTAppGroups`から**開発版のグループだけ**を候補にし、取得できるコンテナーを選びます。本体のキーボード有効化判定は、埋込Keyboard.appexの実際のBundle IDを読みます。[プロファイル生成](https://github.com/altstoreio/AltStore/blob/develop/AltStore/Operations/FetchProvisioningProfilesOperation.swift)、[再署名](https://github.com/altstoreio/AltStore/blob/develop/AltStore/Operations/ResignAppOperation.swift)

本家のAssociated Domainsは除去し、`custard`/`json`の所有宣言・カスタムUTIのexportも開発版から除去しています。正規版のURLやファイル関連付けを取りません。カスタムキーボードのファイル取り込みは開発版アプリ内の選択操作から使えます。履歴説明文にある旧URLの表記はそのままです。

## 失敗を切り分ける

| 症状 | 確認すること |
| --- | --- |
| IPAをインストールできない | 7日期限、App ID残数、デバイス信頼、開発者モード、本体と拡張双方のプロファイルを確認。未署名IPAの直接インストールは不可。 |
| 本体だけ動き、キーボード一覧にない | Keyboard.appexを残して署名したか、拡張の識別子・拡張ポイント・本体IDとの整合を確認。 |
| 本体に共有領域エラー | 完全未署名版でなく再署名用IPAか、署名時にApp Groupsを登録したかを確認。 |
| 拡張だけ共有領域エラー | 開発版のフルアクセス、拡張側プロファイルのグループ、本体と一致するチーム・グループを確認。 |
| 共有テストが応答なし | 実際に開発版を選んだか確認。両側のApp Groupsが一致しない、または署名ツールがentitlementsを落とした可能性を調べる。 |
| 共有テストは通るが候補が出ない | 開発版へ手動登録して再確認。辞書生成エラー、読みの正規化、変換用ファイル、キーボードの再読込を分けて調べる。 |
| 再署名後に開発版データが見えない | 署名アカウント・本体ID・グループ名が前回と同じか確認。正規版の保存先へ切り替えない。 |

署名済みIPAをWindowsへ書き出せるツールではZIPとして展開し、本体とKeyboard.appexのInfo.plist・embedded.mobileprovisionを**端末内で**比較します。プロファイルには個人情報があるため、原本をチャットや公開Issueへ貼らないでください。Macを後から利用できる場合は`codesign -d --entitlements - <app/appex>`と`security cms -D -i <embedded.mobileprovision>`で最終的な署名と許可を照合できます。

### App Groupsが成立しない環境での代替案（未実装）

まずAltStore Classicで、同じ開発版グループを両ターゲットへ付ける経路を検証します。それでも無料プロビジョニング側で拒否される場合、正規版や有料契約に頼る変更は行いません。

共有コンテナーを使わない代替は、CIで辞書を拡張に同梱し、拡張専用の保存先・設定へ切り替える構成です。ただし、本体で選んだファイルが即座に拡張へ伝わる機能は失われ、辞書更新ごとに再ビルド・再署名が必要です。設定・テーマ・学習データの共有も別設計になるため、今回の実装には無条件のローカル保存フォールバックを追加していません。

## インポート形式と動作

ヘッダーなしは`読み,単語,品詞`または同じ順のTSVです。品詞は省略でき、4列目のコメントも読み飛ばします。CSVでは引用符内のカンマと`""`を処理します。ヘッダーがある場合は列順を変更でき、`reading`/`ruby`/`よみ`/`読み`、`word`/`phrase`/`単語`、`pos`/`品詞`等を認識します。

Mozc/Google日本語入力・MS-IMEの`#`/`!`コメントを読み飛ばします。文字コードはUTF-8、UTF-8 BOM、UTF-16 LE/BE（BOMあり・なし）、Shift_JISを判別します。判別不能なら元データを変更せずエラーにします。文字化けするファイルはプレビューで確定せず、UTF-8へ変換してください。

macOSのplistは、`phrase`（単語）と`shortcut`（読み）を持つ辞書の配列に対応し、XML/binaryの両方を扱います。Appleのすべての辞書内部形式に対応するものではありません。[Appleのテキスト置換の書き出し手順](https://support.apple.com/guide/mac-help/back-up-and-share-text-replacements-mchl2a7bd795/mac)

人名・姓・名を既存の人名フラグ、地名を地名フラグ、ラ行五段で語尾が「る」の語を既存の活用フラグへ対応付けます。既存モデルにない活用や品詞は、警告付きで通常の単語にします。読みはひらがなへ正規化し、読み＋単語で既存辞書内とファイル内の重複を省きます。品詞だけが違う既存語は上書きしません。

解析中は保存せず、エラー行を除いた候補・重複・エラー・品詞警告を確認してから一括追加します。タブ・改行・制御文字を含む語や利用できない読みは除外します。時刻・ランダム変換の書式は、取り込みで実行しないようエラーにし、専用の編集画面から登録します。ファイルは16 MiB、10万レコード、1行64列まで。1件の読みは256文字、単語はUTF-8で16 KiBまでです。同じ読みの候補数は既存データと合わせて65,535件を上限とし、変換エンジンの16bit件数を超える入力をエラーにします。候補とエラーの表示は先頭100件に制限します。読込と生成はバックグラウンドで行いますが、iPhone実機の所要時間・ピークメモリは未測定です。

`UserDictionary.save`と`AdditionalDictManager.userDictUpdate`を再利用します。変換用辞書を一時ディレクトリに生成し、成功後に公開して元辞書を保存します。通常の公開失敗は旧ファイルへ戻すテストを設けています。ただし複数ファイルの切替全体はOSによる突然の強制終了に対して原子的ではありません。処理中の強制終了は避け、発生した場合は開発版から再生成してください。元辞書の保存は生成成功後です。

## Phase C 実機チェックリスト

以下はすべて**未検証**です。1項目ずつ結果を記録してください。正規版は読み取りで比較し、テストのために設定を変更しません。

- [ ] 未検証: 正規版と開発版を同時にインストールできる。
- [ ] 未検証: ホーム画面で表示名とDEVアイコンを判別できる。
- [ ] 未検証: キーボード一覧に両方が表示される。
- [ ] 未検証: 開発版キーボードが起動し、通常入力できる。
- [ ] 未検証: 共有テストの往復応答を確認できる。
- [ ] 未検証: 開発版への手動登録語が開発版の候補へ反映される。
- [ ] 未検証: CSV・TSVをFilesから選択し、確定前に内容・件数を確認できる。
- [ ] 未検証: 重複を追加せず、エラー行を除外し、既存語・設定・テンプレートが保たれる。
- [ ] 未検証: 追加した語が開発版キーボードへ反映される。
- [ ] 未検証: 正規版の既存辞書・設定・学習結果に変化がない。
- [ ] 未検証: 7日期限前の再署名で開発版のデータを維持できる。
- [ ] 未検証: 開発版のみを削除しても正規版のアプリ・キーボード・データに影響がない。

用語: Bundle IDはアプリ/拡張の識別子、App Groupは両者が共有する専用保存先、entitlementsは署名で許可を要求する情報、プロビジョニングプロファイルはAppleが署名した利用許可です。解決しない場合は、iOS・署名ツールのバージョン、失敗した段階、秘密情報を除いたエラーを開発版フォークのIssue等へ報告してください。Issueへの投稿は別途行います。
