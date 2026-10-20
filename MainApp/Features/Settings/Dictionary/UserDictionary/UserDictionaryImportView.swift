import AzooKeyUtils
import DictionaryImport
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct UserDictionaryImportView: View {
    let existing: [UserDictionaryData]
    let commit: ([ImportEntry]) async throws -> Int
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var preview: ImportPreview?
    @State private var busy = false
    @State private var error: String?
    @State private var importedCount: Int?

    var body: some View {
        Form {
            Section {
                Text("CSV・TSV（Google日本語入力、Mozc、MS-IME）とmacOS日本語入力のplistを読み込みます。読み・単語・品詞の順に並べるか、列名を付けてください。")
                Text("確認後に既存の辞書へ追加します。同じ読みと単語は追加しません。インポートした単語の共有申請や外部送信は行いません。")
                Button("ファイルを選択", systemImage: "doc.badge.plus") { showPicker = true }
                    .disabled(busy)
            }
            if busy {
                Section { ProgressView("処理中です…") }
            }
            if let error {
                Section("エラー") { Text(error).foregroundStyle(.red) }
            }
            if let importedCount {
                Section {
                    Text("\(importedCount)件を追加し、変換用辞書を再生成しました。開発版キーボードを開き直して確認してください。")
                    Button("閉じる") { dismiss() }
                }
            } else if let preview {
                Section("取り込み内容") {
                    LabeledContent("文字コード", value: preview.encoding)
                    LabeledContent("登録候補", value: "\(preview.entries.count)件")
                    LabeledContent("重複（追加しない）", value: "\(preview.duplicateCount)件")
                    LabeledContent("エラー（追加しない）", value: "\(preview.errorCount)件")
                    LabeledContent("品詞の警告", value: "\(preview.warningCount)件")
                    Text("未対応の品詞は通常の単語として登録します。活用するのは既存形式が対応するラ行五段のみです。")
                        .font(.caption)
                    Button("候補をまとめて追加") {
                        busy = true
                        error = nil
                        Task {
                            do { importedCount = try await commit(preview.entries) }
                            catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    }
                    .disabled(busy || preview.entries.isEmpty)
                }
                Section("登録候補（先頭100件）") {
                    ForEach(Array(preview.entries.prefix(100).enumerated()), id: \.offset) { _, entry in
                        LabeledContent(entry.word, value: entry.ruby)
                    }
                }
                if !preview.issues.isEmpty {
                    Section("エラー・警告の詳細（先頭100件）") {
                        ForEach(Array(preview.issues.enumerated()), id: \.offset) { _, issue in
                            Text("\(issue.record)行目: \(issue.message)")
                        }
                    }
                }
            }
        }
        .navigationTitle("ファイルからインポート")
        .interactiveDismissDisabled(busy)
        .navigationBarBackButtonHidden(busy)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.data]) { result in
            switch result {
            case .failure(let failure): error = failure.localizedDescription
            case .success(let url):
                busy = true
                preview = nil
                error = nil
                importedCount = nil
                let existingEntries = existing.map(\.importEntry)
                let characterURL = Bundle.main.bundleURL.appendingPathComponent("charID.chid")
                Task {
                    do {
                        preview = try await Task.detached(priority: .userInitiated) {
                            let accessible = url.startAccessingSecurityScopedResource()
                            defer { if accessible { url.stopAccessingSecurityScopedResource() } }
                            let handle = try FileHandle(forReadingFrom: url)
                            defer { try? handle.close() }
                            var data = Data()
                            while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                                guard data.count + chunk.count <= DictionaryImporter.maximumBytes else {
                                    throw DictionaryImportError.tooLarge
                                }
                                data.append(chunk)
                            }
                            let characters = try String(contentsOf: characterURL, encoding: .utf8)
                            return try DictionaryImporter.parse(
                                data, fileExtension: url.pathExtension,
                                existing: existingEntries, allowedReadingCharacters: Set(characters)
                            )
                        }.value
                    } catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
        }
    }
}

extension UserDictionaryData {
    var importEntry: ImportEntry {
        .init(ruby: ruby, word: word, partOfSpeech: isPersonName ? .person : isPlaceName ? .place : isVerb ? .godanRa : .word)
    }
}
