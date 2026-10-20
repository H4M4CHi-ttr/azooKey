import AzooKeyUtils
import SwiftUI

struct DevDictionarySharingView: View {
    @State private var status = "未検証"

    var body: some View {
        Section("開発版の共有テスト") {
            Text("本体とキーボードのデータ共有: \(status)")
            Button("1. 共有テストを開始") {
                SharedStore.userDefaults.set(UUID().uuidString, forKey: "devProbeFromApp")
                status = "開発版キーボードへ切り替え、戻ってから結果を確認してください"
            }
            Button("2. キーボードからの応答を確認") {
                let sent = SharedStore.userDefaults.string(forKey: "devProbeFromApp")
                let received = SharedStore.userDefaults.string(forKey: "devProbeFromKeyboard")
                status = sent != nil && sent == received ? "往復確認済み（変換候補は別途確認）" : "応答なし。フルアクセス・拡張の署名・App Groupsを確認してください"
            }
        }
    }
}
