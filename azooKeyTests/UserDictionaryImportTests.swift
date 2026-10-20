import DictionaryImport
import Foundation
import KeyboardExtensionUtils
import XCTest
@testable import azooKey

@MainActor
final class UserDictionaryImportTests: XCTestCase {
    func testGroupSelectionNeverAcceptsTheProductionGroup() {
        XCTAssertFalse(DevAppIdentity.isDevelopmentGroup("group.com.azooKey.keyboard"))
        XCTAssertFalse(DevAppIdentity.isDevelopmentGroup(DevAppIdentity.baseGroup + "other"))
        XCTAssertTrue(DevAppIdentity.isDevelopmentGroup(DevAppIdentity.baseGroup))
        XCTAssertTrue(DevAppIdentity.isDevelopmentGroup(DevAppIdentity.baseGroup + ".TESTTEAM01"))
    }

    func testAdditionsKeepExistingFlagsTemplatesAndNeverShare() throws {
        let existing = UserDictionary(items: [
            UserDictionaryData(ruby: "ひづけ", word: "日時", isVerb: false, isPersonName: false, isPlaceName: false,
                               id: 0, shared: true, isTemplateMode: true, formatLiteral: "<date format=\"yyyy\">"),
            UserDictionaryData(ruby: "たろう", word: "太郎", isVerb: false, isPersonName: true, isPlaceName: false, id: 1)
        ])
        let result = existing.adding([
            .init(ruby: "タロウ", word: "太郎"),
            .init(ruby: "とうきょう", word: "東京", partOfSpeech: .place),
            .init(ruby: "かえる", word: "帰る", partOfSpeech: .godanRa)
        ])
        XCTAssertEqual(Array(result.items.prefix(2)), existing.items)
        XCTAssertEqual(result.items.count, 4)
        XCTAssertTrue(result.items[2].isPlaceName)
        XCTAssertTrue(result.items[3].isVerb)
        XCTAssertEqual(result.items[2].shared, false)
        XCTAssertFalse(result.items[2].isTemplateMode)
        XCTAssertEqual(Set(result.items.map(\.id)).count, 4)
    }

    func testMalformedImportDoesNotChangeSavedDictionary() throws {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "user_dict")
        defer { defaults.set(original, forKey: "user_dict") }
        let dictionary = UserDictionary(items: [.init(ruby: "あ", word: "亜", isVerb: false, isPersonName: false, isPlaceName: false, id: 0)])
        XCTAssertTrue(dictionary.save())
        let before = defaults.data(forKey: "user_dict")
        XCTAssertThrowsError(try DictionaryImporter.parse(Data("あ,亜\nい,\"未完".utf8)))
        XCTAssertEqual(defaults.data(forKey: "user_dict"), before)
        XCTAssertEqual(UserDictionary.get()?.items, dictionary.items)
    }

    func testRegenerationCreatesMainAndShortcutDictionaryWithoutSavingSource() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = UserDefaults.standard.data(forKey: "user_dict")
        let dictionary = UserDictionary(items: [.init(ruby: "あずーきー", word: "開発テスト", isVerb: false, isPersonName: false, isPlaceName: false, id: 0)])
        let builder = UserDictionaryUpdater(additionalSystemDictionaries: [], denylist: [])
        XCTAssertFalse(builder.char2UInt8.isEmpty, "Test host must bundle charID.chid")
        try builder.generate(userDictionary: dictionary, directoryURL: directory)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("user.") })
        XCTAssertTrue(names.contains { $0.hasPrefix("user_shortcuts.") })
        XCTAssertEqual(UserDefaults.standard.data(forKey: "user_dict"), before)
    }

    func testGenerationRejectsCandidateCountOverflowBeforePublishing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let entries = (0...Int(UInt16.max)).map { index in
            UserDictionaryData(ruby: "あ", word: "語\(index)", isVerb: false, isPersonName: false, isPlaceName: false, id: index)
        }
        let dictionary = UserDictionary(items: entries)
        let builder = UserDictionaryUpdater(additionalSystemDictionaries: [], denylist: [])
        XCTAssertThrowsError(try builder.generate(userDictionary: dictionary, directoryURL: directory))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testGeneratedFilesRollbackAfterPublishFailure() throws {
        let manager = FailingMoveFileManager()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let staging = root.appendingPathComponent("staging", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        for name in ["user.louds", "user_shortcuts.louds"] {
            try Data("old-\(name)".utf8).write(to: destination.appendingPathComponent(name))
            try Data("new-\(name)".utf8).write(to: staging.appendingPathComponent(name))
        }
        manager.failAfterStagingMoves = 1
        XCTAssertThrowsError(try DictionaryGeneratedFiles.publish(from: staging, to: destination, manager: manager))
        for name in ["user.louds", "user_shortcuts.louds"] {
            XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(name)), Data("old-\(name)".utf8))
        }
    }

    func testGeneratedFilesPublishLeavesUnrelatedFilesAlone() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let staging = root.appendingPathComponent("staging", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        try Data("new".utf8).write(to: staging.appendingPathComponent("user.louds"))
        try Data("preserve".utf8).write(to: destination.appendingPathComponent("settings.json"))
        try DictionaryGeneratedFiles.publish(from: staging, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("user.louds")), Data("new".utf8))
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("settings.json")), Data("preserve".utf8))
    }
}

private final class FailingMoveFileManager: FileManager, @unchecked Sendable {
    var failAfterStagingMoves = Int.max
    private var stagingMoves = 0

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if srcURL.deletingLastPathComponent().lastPathComponent == "staging" {
            if stagingMoves == failAfterStagingMoves { throw CocoaError(.fileWriteUnknown) }
            stagingMoves += 1
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
