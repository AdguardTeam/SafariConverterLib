import ContentBlockerConverter
import Foundation
import XCTest

@testable import FilterEngine

final class FilterRuleStorageTests: XCTestCase {
    private var tempDirectory: URL!
    private var tempFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        tempFileURL = tempDirectory.appendingPathComponent("filterRules.bin")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testInitFromLinesWithValidRules() throws {
        // Arrange
        let lines = [
            "@@||example.org^$jsinject",  // An allowlist jsinject rule
            "##.banner",  // A cosmetic rule
            "@@||example.com^$elemhide",  // An allowlist elemhide rule
        ]

        // Act
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Assert
        XCTAssertEqual(storage.count, 3)
    }

    func testInitFromLinesWithSomeInvalidRules() throws {
        // Arrange
        // One rule is definitely invalid, so it should be skipped in writing
        let lines = [
            "||example.org^",  // Blocking rules will be discarded
            "##.banner",  // A cosmetic rule
            "@@||example.com^$elemhide",  // An allowlist elemhide rule
        ]

        // Act
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Assert
        // The invalid rule should have been skipped.
        XCTAssertEqual(storage.count, 2)
    }

    func testCreateAndReadHeader() throws {
        // Arrange
        let lines = ["@@||example.org^$document"]
        // Act
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)
        // Assert
        // Implicitly tests readHeader()
        XCTAssertEqual(storage.count, 1)
        XCTAssertNotNil(storage)
    }

    func testLoadExistingStorage() throws {
        // Arrange
        let lines = [
            "@@||example.org^$document",
            "##.ad-banner",
        ]
        _ = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Act
        let reopened = try FilterRuleStorage(fileURL: tempFileURL)

        // Assert
        XCTAssertEqual(reopened.count, 2)
    }

    func testSubscriptReturnsCorrectRule() throws {
        // Arrange
        // Note that the order of the rules may be different and depends on `RuleFactory`.
        // For now this works.
        let lines = [
            "##.banner",
            "##.ad-banner",
        ]
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Get an iterator to find the offset for the second rule.
        let iterator = try storage.makeIterator()
        let item1 = iterator.next()
        let item2 = iterator.next()

        // Assert
        XCTAssertNotNil(item1)
        XCTAssertNotNil(item2)
        if let second = item2 {
            // Act
            let subscriptRule = try storage[second.0]

            // Assert
            XCTAssertEqual(subscriptRule.cosmeticContent, ".ad-banner")
        }
    }

    func testIteratorReadsAllRules() throws {
        // Arrange
        let lines = [
            "@@||example.org^$jsinject",
            "@@||example.net^$elemhide",
            "##.sidebar",
        ]
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Act
        let iterator = try storage.makeIterator()

        var readRules: [FilterRule] = []
        while let (_, filterRule) = iterator.next() {
            readRules.append(filterRule)
        }

        // Assert
        XCTAssertEqual(readRules.count, 3)
        XCTAssertTrue(readRules.contains { $0.urlPattern == "||example.org^" })
        XCTAssertTrue(readRules.contains { $0.urlPattern == "||example.net^" })
        XCTAssertTrue(readRules.contains { $0.cosmeticContent == ".sidebar" })
    }

    func testIteratorEndCondition() throws {
        // Arrange
        let lines = ["@@||example.org^$document"]
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Act
        let iterator = try storage.makeIterator()
        let first = iterator.next()
        let second = iterator.next()  // should be nil after first

        // Assert
        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testWrongMagicHeaderThrows() throws {
        // Arrange
        let data = "BAD0".data(using: .utf8)!  // Wrong magic
        try data.write(to: tempFileURL)

        // Attempt to open storage
        XCTAssertThrowsError(try FilterRuleStorage(fileURL: tempFileURL)) { error in
            guard case FilterRuleStorage.FilterRuleStorageError.fileFormatError(let reason) = error
            else {
                XCTFail("Expected fileFormatError, got \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Wrong magic header"))
        }
    }

    func testMissingRuleCountThrows() throws {
        // Arrange
        let data = Data("FRS0".utf8)  // correct magic
        // but no 4-byte count
        try data.write(to: tempFileURL)

        // Attempt to open
        XCTAssertThrowsError(try FilterRuleStorage(fileURL: tempFileURL)) { error in
            guard case FilterRuleStorage.FilterRuleStorageError.fileFormatError(let reason) = error
            else {
                XCTFail("Expected fileFormatError, got \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Missing rule count"))
        }
    }

    func testIndexOffsetIsPreserved() throws {
        // Arrange
        let lines = [
            "@@||example.com^$jsinject",
            "@@||example.org^$elemhide",
        ]
        let storage = try FilterRuleStorage(from: lines, for: .safari16_4, fileURL: tempFileURL)

        // Act
        let iterator = try storage.makeIterator()
        let firstItem = iterator.next()
        let secondItem = iterator.next()

        // Assert
        XCTAssertNotNil(firstItem)
        XCTAssertNotNil(secondItem)

        if let (idx1, _) = firstItem, let (idx2, _) = secondItem {
            XCTAssertNotEqual(idx1.offset, idx2.offset)
        }
    }

    func testAccessOutOfBoundsIndexThrows() throws {
        // Arrange
        let storage = try FilterRuleStorage(
            from: ["||test.com^"],
            for: .safari16_4,
            fileURL: tempFileURL
        )
        let largeOffset = UInt32(9999999)
        let index = FilterRuleStorage.Index(offset: largeOffset)

        // Act & Assert
        XCTAssertThrowsError(try storage[index]) { error in
            // We expect a readError because the offset is well beyond the file length
            guard case FilterRuleStorage.FilterRuleStorageError.readError(let reason) = error else {
                XCTFail("Expected readError, got \(error)")
                return
            }
            XCTAssertTrue(reason.contains("Cannot read length at offset"))
        }
    }

    func testCorruptedRuleReturnsNilInIterator() throws {
        // Arrange
        // We'll simulate a single rule that cannot parse.
        let magic = Data("FRS0".utf8)
        try magic.write(to: tempFileURL)

        let handle = try FileHandle(forUpdating: tempFileURL)
        defer { handle.closeFile() }

        // We'll write a single "rule" of length 4, containing random data
        var ruleCount: UInt32 = 1
        let ruleCountData = withUnsafeBytes(of: &ruleCount) { Data($0) }

        // Update count in file
        handle.seek(toFileOffset: 4)
        handle.write(ruleCountData)

        // Move to the end
        handle.seekToEndOfFile()

        // Write length of 4
        var length: UInt32 = 4
        let lengthData = withUnsafeBytes(of: &length) { Data($0) }
        handle.write(lengthData)
        // Write 4 random bytes
        let randomBytes = Data([0xFF, 0x45, 0xAA, 0x00])
        handle.write(randomBytes)

        // Act
        let storage = try FilterRuleStorage(fileURL: tempFileURL)
        let iterator = try storage.makeIterator()
        let firstItem = iterator.next()  // returns nil on decode error

        // Assert
        XCTAssertNil(firstItem, "Iterator should skip corrupted rule and return nil immediately")
    }
}
