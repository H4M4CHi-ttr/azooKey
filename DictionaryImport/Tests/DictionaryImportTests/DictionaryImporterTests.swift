import Foundation
import XCTest
@testable import DictionaryImport

final class DictionaryImporterTests: XCTestCase {
    private func parse(_ text: String, encoding: String.Encoding = .utf8) throws -> ImportPreview {
        try DictionaryImporter.parse(XCTUnwrap(text.data(using: encoding)))
    }

    func testMozcAndIMECommentsAndPartOfSpeech() throws {
        let result = try parse("!Microsoft IME Dictionary Tool\r\n# Mozc\r\nたろう\t太郎\t人名\tcomment\r\nとうきょう\t東京\t地名\r\nかえる\t帰る\t動詞ラ行五段\r\n")
        XCTAssertEqual(result.entries.map(\.partOfSpeech), [.person, .place, .godanRa])
        XCTAssertEqual(result.errorCount, 0)
    }

    func testUTF8BOMAndUTF16BothByteOrdersAndShiftJIS() throws {
        let text = "よみ\t単語\t品詞\nあずーきー\t開発辞書\t名詞\n"
        let expected = try parse(text).entries
        for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .shiftJIS] {
            XCTAssertEqual(try parse(text, encoding: encoding).entries, expected)
        }
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
        XCTAssertEqual(try DictionaryImporter.parse(bom).entries, expected)
    }

    func testCSVQuotedCommaEscapedQuoteAndReorderedHeader() throws {
        let result = try parse("word,reading,pos\n\"Hello, \"\"world\"\"\",はろー,名詞\n")
        XCTAssertEqual(result.entries.first?.word, "Hello, \"world\"")
        XCTAssertEqual(result.entries.first?.ruby, "はろー")
        XCTAssertEqual(result.errorCount, 0)
    }

    func testInvalidRowsDoNotHideValidCandidatesOrInjectDictionaryColumns() throws {
        let result = try parse("あ\t亜\n\t欠落\n一列\nか\t\"タブ\t混入\"\nき\t\"改\n行\"\nく\t句\n")
        XCTAssertEqual(result.entries.map(\.word), ["亜", "句"])
        XCTAssertEqual(result.errorCount, 4)
        XCTAssertEqual(result.issues.count, 4)
    }

    func testUnterminatedQuoteAbortsWholeParse() {
        XCTAssertThrowsError(try parse("あ,亜\nい,\"未完"))
    }

    func testDeduplicationNormalizesReadingAndPreservesExistingInput() throws {
        let existing = [ImportEntry(ruby: "あずーきー", word: "azooKey", partOfSpeech: .person)]
        let original = existing
        let result = try DictionaryImporter.parse(Data("アズーキー\tazooKey\t名詞\nあずーきー\tazooKey\nあ\t亜\nあ\t亜\n".utf8), existing: existing)
        XCTAssertEqual(result.entries.map(\.word), ["亜"])
        XCTAssertEqual(result.duplicateCount, 3)
        XCTAssertEqual(existing, original)
        let again = result.additions(to: existing + result.entries)
        XCTAssertTrue(again.isEmpty)
    }

    func testUnsupportedPOSIsVisibleAndDoesNotInventConjugation() throws {
        let result = try parse("かく\t書く\t動詞カ行五段\nたべる\t食べる\t動詞一段\nいぬ\t犬\tunknown\n")
        XCTAssertEqual(result.entries.map(\.partOfSpeech), [.word, .word, .word])
        XCTAssertEqual(result.warningCount, 3)
        XCTAssertEqual(result.errorCount, 0)
    }

    func testMacOSXMLAndBinaryPlist() throws {
        let value = [["phrase": "開発辞書", "shortcut": "かいはつじしょ"], ["phrase": "欠落"]]
        for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
            let data = try PropertyListSerialization.data(fromPropertyList: value, format: format, options: 0)
            let result = try DictionaryImporter.parse(data, fileExtension: "plist")
            XCTAssertEqual(result.entries.first?.word, "開発辞書")
            XCTAssertEqual(result.errorCount, 1)
        }
    }

    func testAllowedReadingCharactersAndControlCharacters() throws {
        let result = try DictionaryImporter.parse(Data("あ\t亜\nい\t伊\nか\t<script>\n".utf8), allowedReadingCharacters: Set("アカ"))
        XCTAssertEqual(result.errorCount, 1)
        XCTAssertEqual(result.entries.map(\.word), ["亜", "<script>"])
        XCTAssertEqual(try parse("あ\t\u{0000}\n").errorCount, 1)
    }

    func testBoundedErrorsAndLargeLinearImport() throws {
        let rows = (0..<50_000).map { "よみ\($0)\t単語\($0)\t名詞" }.joined(separator: "\n")
        let result = try parse(rows)
        XCTAssertEqual(result.entries.count, 50_000)
        XCTAssertEqual(result.errorCount, 0)
        let invalid = try parse(String(repeating: "一列\n", count: 500))
        XCTAssertEqual(invalid.errorCount, 500)
        XCTAssertEqual(invalid.issues.count, 100)
    }

    func testInputAndEntryLimitsAreExplicitFailures() {
        XCTAssertThrowsError(try DictionaryImporter.parse(Data(repeating: 65, count: DictionaryImporter.maximumBytes + 1)))
        XCTAssertThrowsError(try parse(String(repeating: "あ\t亜\n", count: DictionaryImporter.maximumRecords + 1)))
        XCTAssertThrowsError(try parse(String(repeating: ",", count: 100_000)))
    }

    func testMalformedEncodingAndCommentsWithQuotes() throws {
        XCTAssertThrowsError(try DictionaryImporter.parse(Data([0xEF, 0xBB, 0xBF, 0xFF])))
        let result = try parse("  !comment with unclosed \"\nあ\t亜\n")
        XCTAssertEqual(result.entries.map(\.word), ["亜"])
        XCTAssertTrue(try parse(String(repeating: " ", count: 100_000)).entries.isEmpty)
    }

    func testImportedWordsDoNotActivateTemplateExpressions() throws {
        let result = try parse("あ\t<random length=\"100000000\">\nい\t<date format=\"yyyy\">\nう\t<database>\n")
        XCTAssertEqual(result.errorCount, 2)
        XCTAssertEqual(result.entries.map(\.word), ["<database>"])
    }

    func testReadingNormalizationPreservesLongVowelsAndCombinesVoicing() {
        XCTAssertEqual(ImportEntry.normalizedReading("ハロー"), "はろー")
        XCTAssertEqual(ImportEntry.normalizedReading("はろー"), "はろー")
        XCTAssertEqual(ImportEntry.normalizedReading("ウ\u{3099}ァ"), "ゔぁ")
        XCTAssertEqual(ImportEntry.normalizedReading("ABC123"), "ABC123")
    }
}
