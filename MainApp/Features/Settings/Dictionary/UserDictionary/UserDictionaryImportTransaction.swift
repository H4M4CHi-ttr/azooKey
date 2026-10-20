import DictionaryImport
import Foundation

extension UserDictionary {
    func adding(_ entries: [ImportEntry]) -> Self {
        let additions = DictionaryImporter.additions(entries, to: items.map(\.importEntry))
        let firstID = (items.map(\.id).max() ?? -1) + 1
        let newItems = additions.enumerated().map { offset, entry in
            UserDictionaryData(
                ruby: entry.ruby, word: entry.word,
                isVerb: entry.partOfSpeech == .godanRa,
                isPersonName: entry.partOfSpeech == .person,
                isPlaceName: entry.partOfSpeech == .place,
                id: firstID + offset, shared: false, isTemplateMode: false, formatLiteral: nil
            )
        }
        return Self(items: items + newItems)
    }
}

enum UserDictionaryImportCommitError: Error, LocalizedError {
    case sharedContainerUnavailable, unreadableDictionary, dictionaryChanged, encoding, tooManyCandidates

    var errorDescription: String? {
        switch self {
        case .sharedContainerUnavailable: "共有領域を利用できません。開発版の署名とApp Groupsを確認してください。"
        case .unreadableDictionary: "既存の辞書を読み込めません。元の保存データを保護するため取り込みを中止しました。"
        case .dictionaryChanged: "処理中に辞書が変更されました。元の内容を保護するため、ファイルを選び直してください。"
        case .encoding: "辞書の保存データを作成できませんでした。既存の辞書は変更していません。"
        case .tooManyCandidates: "同じ読みの変換候補が65,535件を超えています。既存の辞書は変更していません。"
        }
    }
}

/// Publish only after both dictionaries have been generated successfully.
enum DictionaryGeneratedFiles {
    // shortcut: multiple file moves are not crash-atomic; use versioned directories if crash recovery is needed.
    static func publish(from staging: URL, to destination: URL, manager: FileManager = .default) throws {
        let files = try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
        guard !files.isEmpty else { throw CocoaError(.fileReadUnknown) }
        let backup = destination.appendingPathComponent(".dictionary-backup-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: backup, withIntermediateDirectories: false)
        var movedOld: [String] = []
        var placedNew: [String] = []
        do {
            for file in files {
                let name = file.lastPathComponent
                let target = destination.appendingPathComponent(name)
                if manager.fileExists(atPath: target.path) {
                    try manager.moveItem(at: target, to: backup.appendingPathComponent(name))
                    movedOld.append(name)
                }
                try manager.moveItem(at: file, to: target)
                placedNew.append(name)
            }
        } catch {
            // Retain the backup if restoring an old file fails; never erase it.
            for name in placedNew.reversed() {
                try manager.removeItem(at: destination.appendingPathComponent(name))
            }
            for name in movedOld.reversed() {
                try manager.moveItem(at: backup.appendingPathComponent(name), to: destination.appendingPathComponent(name))
            }
            try? manager.removeItem(at: backup)
            throw error
        }
        try? manager.removeItem(at: backup)
    }
}
