import Foundation

public struct ImportEntry: Sendable, Equatable {
    public enum PartOfSpeech: String, Sendable {
        case word, person, place, godanRa
    }
    public let ruby: String
    public let word: String
    public let partOfSpeech: PartOfSpeech

    public init(ruby: String, word: String, partOfSpeech: PartOfSpeech = .word) {
        self.ruby = Self.normalizedReading(ruby)
        self.word = word
        self.partOfSpeech = partOfSpeech
    }

    public static func normalizedReading(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .applyingTransform(.hiraganaToKatakana, reverse: true) ?? value
    }

    fileprivate var key: Key { Key(ruby: ruby, word: word) }
    fileprivate struct Key: Hashable {
        let ruby: String
        let word: String
    }
}

public struct ImportIssue: Sendable {
    public let record: Int
    public let message: String
}

public struct ImportPreview: Sendable {
    public fileprivate(set) var entries: [ImportEntry] = []
    public fileprivate(set) var duplicateCount = 0
    public fileprivate(set) var errorCount = 0
    public fileprivate(set) var warningCount = 0
    public fileprivate(set) var issues: [ImportIssue] = []
    public fileprivate(set) var encoding = ""

    /// Recheck against the current dictionary at confirmation time.
    public func additions(to existing: [ImportEntry]) -> [ImportEntry] {
        DictionaryImporter.additions(entries, to: existing)
    }
}

public enum DictionaryImportError: Error, LocalizedError, Sendable {
    case tooLarge, tooManyRecords, tooManyColumns, encoding, malformedCSV, invalidPlist

    public var errorDescription: String? {
        switch self {
        case .tooLarge: "ファイルは16 MiB以下に分割してください。既存の辞書は変更していません。"
        case .tooManyRecords: "一度に取り込めるのは10万行までです。ファイルを分割してください。"
        case .tooManyColumns: "一行の列数が64列を超えています。CSV・TSVの区切りを確認してください。"
        case .encoding: "文字コードを判別できません。UTF-8で保存し直してください。"
        case .malformedCSV: "CSVの引用符が閉じていません。ファイルを修正してください。"
        case .invalidPlist: "対応するplistではありません。phraseとshortcutを持つ配列を指定してください。"
        }
    }
}

public enum DictionaryImporter {
    public static let maximumBytes = 16 * 1024 * 1024
    public static let maximumRecords = 100_000

    public static func additions(_ candidates: [ImportEntry], to existing: [ImportEntry]) -> [ImportEntry] {
        var seen = Set(existing.map(\.key))
        return candidates.filter { seen.insert($0.key).inserted }
    }

    public static func parse(
        _ data: Data,
        fileExtension: String = "",
        existing: [ImportEntry] = [],
        allowedReadingCharacters: Set<Character>? = nil
    ) throws -> ImportPreview {
        guard data.count <= maximumBytes else { throw DictionaryImportError.tooLarge }
        var preview = ImportPreview()
        var seen = Set(existing.map(\.key))
        var records = 0

        func issue(_ message: String, warning: Bool = false) {
            if warning { preview.warningCount += 1 } else { preview.errorCount += 1 }
            if preview.issues.count < 100 {
                preview.issues.append(ImportIssue(record: records, message: message))
            }
        }

        func append(ruby: String, word: String, pos: String) {
            let ruby = ImportEntry.normalizedReading(ruby.trimmingCharacters(in: .whitespaces))
            guard !ruby.isEmpty, !word.trimmingCharacters(in: .whitespaces).isEmpty else {
                issue("読みまたは単語が空です")
                return
            }
            // The existing dictionary generator uses TSV internally.
            guard !(ruby + word).unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
                issue("読みまたは単語にタブ・改行・制御文字が含まれています")
                return
            }
            if let allowedReadingCharacters,
               !(ruby.applyingTransform(.hiraganaToKatakana, reverse: false) ?? ruby)
                .allSatisfy(allowedReadingCharacters.contains) {
                issue("読みに使用できない文字が含まれています")
                return
            }
            let (partOfSpeech, warning) = Self.partOfSpeech(pos, ruby: ruby, word: word)
            if warning { issue("品詞「\(pos.prefix(60))」は通常の単語として登録します（活用なし）", warning: true) }
            let entry = ImportEntry(ruby: ruby, word: word, partOfSpeech: partOfSpeech)
            if seen.insert(entry.key).inserted { preview.entries.append(entry) } else { preview.duplicateCount += 1 }
        }

        if fileExtension.lowercased() == "plist" || data.starts(with: Data("bplist".utf8)) {
            guard let value = try? PropertyListSerialization.propertyList(from: data, options: 0, format: nil),
                  let rows = value as? [Any] else { throw DictionaryImportError.invalidPlist }
            guard rows.count <= maximumRecords else { throw DictionaryImportError.tooManyRecords }
            preview.encoding = "plist"
            for row in rows {
                records += 1
                guard let fields = row as? [String: Any],
                      let ruby = fields["shortcut"] as? String,
                      let word = fields["phrase"] as? String else {
                    issue("phraseまたはshortcutがありません")
                    continue
                }
                append(ruby: ruby, word: word, pos: "")
            }
            return preview
        }

        let (decoded, encoding) = try decode(data)
        preview.encoding = encoding
        let text = decoded.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let separator = delimiter(in: text)
        var header: (ruby: Int, word: Int, pos: Int?)?
        var firstRecord = true

        try scan(text, separator: separator) { fields, malformed in
            let first = fields.first?.trimmingCharacters(in: .whitespaces) ?? ""
            if fields.count == 1 && first.isEmpty { return }
            if first.hasPrefix("!") || first.hasPrefix("#") { return }
            records += 1
            guard records <= maximumRecords else { throw DictionaryImportError.tooManyRecords }
            if malformed {
                issue("引用符の位置が不正です")
                return
            }
            if firstRecord {
                firstRecord = false
                let names = fields.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                let rubyIndex = names.firstIndex { ["reading", "ruby", "shortcut", "よみ", "読み"].contains($0) }
                let wordIndex = names.firstIndex { ["word", "phrase", "単語", "語句", "表記"].contains($0) }
                if let rubyIndex, let wordIndex {
                    header = (rubyIndex, wordIndex, names.firstIndex { ["pos", "partofspeech", "part_of_speech", "品詞"].contains($0) })
                    return
                }
            }
            let columns = header ?? (ruby: 0, word: 1, pos: fields.count > 2 ? 2 : nil)
            let required = [columns.ruby, columns.word, columns.pos ?? 0].max() ?? 1
            guard fields.count > required, header != nil || fields.count <= 4 else {
                issue("読み・単語の列が足りないか、列が多すぎます")
                return
            }
            append(ruby: fields[columns.ruby], word: fields[columns.word], pos: columns.pos.map { fields[$0] } ?? "")
        }
        return preview
    }

    private static func partOfSpeech(_ raw: String, ruby: String, word: String) -> (ImportEntry.PartOfSpeech, Bool) {
        let pos = raw.trimmingCharacters(in: .whitespaces)
        if ["人名", "姓", "名", "固有名詞,人名", "人名姓", "人名名"].contains(pos) { return (.person, false) }
        if ["地名", "固有名詞,地名"].contains(pos) { return (.place, false) }
        if ["動詞ラ行五段", "ラ行五段", "五段動詞", "動詞・ラ行五段"].contains(pos),
           ruby.hasSuffix("る"), word.hasSuffix("る") || word.hasSuffix("ル") { return (.godanRa, false) }
        let ordinary = ["", "名詞", "普通名詞", "固有名詞", "短縮よみ", "短縮読み", "記号", "顔文字", "組織", "組織名", "その他", "名詞サ変", "サ変名詞"]
        return (.word, !ordinary.contains(pos))
    }

    private static func delimiter(in text: String) -> Character {
        var start = text.startIndex
        while start < text.endIndex {
            let end = text[start...].firstIndex(of: "\n") ?? text.endIndex
            let line = text[start..<end].trimmingCharacters(in: .whitespaces)
            if !line.isEmpty, !line.hasPrefix("!"), !line.hasPrefix("#") {
                return line.contains("\t") ? "\t" : ","
            }
            start = end == text.endIndex ? end : text.index(after: end)
        }
        return "\t"
    }

    private static func decode(_ data: Data) throws -> (String, String) {
        let bomEncodings: [(Data, String.Encoding, String)] = [
            (Data([0xEF, 0xBB, 0xBF]), .utf8, "UTF-8 BOM"),
            (Data([0xFF, 0xFE]), .utf16LittleEndian, "UTF-16 LE"),
            (Data([0xFE, 0xFF]), .utf16BigEndian, "UTF-16 BE")
        ]
        for (bom, encoding, name) in bomEncodings where data.starts(with: bom) {
            guard let text = String(data: data.dropFirst(bom.count), encoding: encoding) else { throw DictionaryImportError.encoding }
            return (text, name)
        }
        // BOM-less UTF-16 exports still contain zero bytes in delimiters.
        if data.contains(0), data.count.isMultiple(of: 2) {
            for (encoding, name) in [(String.Encoding.utf16LittleEndian, "UTF-16 LE"), (.utf16BigEndian, "UTF-16 BE")] {
                if let text = String(data: data, encoding: encoding), text.contains("\t") || text.contains(",") || text.contains("\n") {
                    return (text, name)
                }
            }
        }
        if let text = String(data: data, encoding: .utf8) { return (text, "UTF-8") }
        if let text = String(data: data, encoding: .shiftJIS) { return (text, "Shift_JIS") }
        throw DictionaryImportError.encoding
    }

    /// Scan one record at a time; never materialize a second array of all rows.
    private static func scan(
        _ text: String, separator: Character, consume: ([String], Bool) throws -> Void
    ) throws {
        var fields: [String] = []
        var field = ""
        var quoted = false
        var closedQuote = false
        var malformed = false
        var comment = false
        var iterator = text.makeIterator()
        var character = iterator.next()
        func emit() throws {
            fields.append(field)
            try consume(fields, malformed)
            fields.removeAll(keepingCapacity: true)
            field = ""
            closedQuote = false
            malformed = false
            comment = false
        }
        while let current = character {
            let next = iterator.next()
            if fields.isEmpty, field.allSatisfy(\.isWhitespace), !quoted, current == "!" || current == "#" { comment = true }
            if comment {
                if current == "\n" { try emit() } else { field.append(current) }
            } else if quoted {
                if current == "\"" {
                    if next == "\"" {
                        field.append("\"")
                        character = iterator.next()
                        continue
                    }
                    quoted = false
                    closedQuote = true
                } else { field.append(current) }
            } else if current == separator {
                guard fields.count < 63 else { throw DictionaryImportError.tooManyColumns }
                fields.append(field)
                field = ""
                closedQuote = false
            } else if current == "\n" {
                try emit()
            } else if current == "\"" {
                if field.isEmpty, !closedQuote { quoted = true } else { malformed = true }
            } else if closedQuote {
                if !current.isWhitespace { malformed = true }
            } else { field.append(current) }
            character = next
        }
        guard !quoted else { throw DictionaryImportError.malformedCSV }
        if !fields.isEmpty || !field.isEmpty || closedQuote { try emit() }
    }
}
