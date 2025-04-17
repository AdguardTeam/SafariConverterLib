import XCTest

@testable import FilterEngine

final class FilterRuleExtractShortcutsTests: XCTestCase {
    // MARK: - Basic tests

    /// Tests an empty pattern; should return an empty array.
    func testExtractsShortcutsEmptyPattern() {
        let pattern = ""
        let expected: [String] = []
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(result, expected, "Empty pattern should yield no shortcuts.")
    }

    /// Tests a pattern containing only special characters; no shortcuts can be formed.
    func testExtractShortcutsOnlySpecialCharacters() {
        let pattern = "^^||**|^"
        let expected: [String] = []
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(result, expected, "Only special characters should yield no shortcuts.")
    }

    /// Tests a pattern without any special characters; entire pattern is one shortcut if >= 3.
    func testExtractShortcutsNoSpecialCharactersShort() {
        let pattern = "ab"  // only 2 characters
        let expected: [String] = []
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(result, expected, "Shorter than 3 characters should yield no shortcuts.")
    }

    /// Tests a pattern with no special characters and length >= 3.
    func testExtractShortcutsNoSpecialCharactersLongEnough() {
        let pattern = "abcdef"
        let expected = ["abcdef"]
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(result, expected, "Entire pattern is one valid shortcut if length >= 3.")
    }

    /// Tests a pattern where special characters appear at the start and end.
    func testExtractShortcutsSpecialCharactersAtBoundaries() {
        let pattern = "|abcde^"
        // 'abcde' is 5 letters long, valid since >= 3
        let expected = ["abcde"]
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(result, expected, "Should ignore leading and trailing special characters.")
    }

    /// Tests multiple consecutive special characters.
    /// They should act like repeated separators.
    func testExtractShortcutsMultipleConsecutiveSpecialCharacters() {
        let pattern = "abc||*^def"
        // 'abc' => length 3, valid
        // 'def' => length 3, valid
        let expected = ["abc", "def"]
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            expected,
            "Multiple consecutive special chars should treat each chunk separately."
        )
    }

    /// Tests a pattern that yields multiple shortcuts of different lengths.
    func testExtractShortcutsMultipleShortcuts() {
        let pattern = "abc|12^defgh**xyz"
        // 'abc' => length 3, valid
        // '12' => length 2, not valid
        // 'defgh' => length 5, valid
        // 'xyz' => length 3, valid
        let expected = ["abc", "defgh", "xyz"]
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            expected,
            "Should correctly parse multiple chunks of various lengths."
        )
    }

    /// Tests patterns with exactly 3-character chunks surrounded by special characters.
    func testExtractShortcutsExactlyThreeCharactersChunks() {
        let pattern = "^abc|def*ghi^jkl|mn"
        // 'abc' => length 3
        // 'def' => length 3
        // 'ghi' => length 3
        // 'jkl' => length 3
        // 'mn'  => length 2
        let expected = ["abc", "def", "ghi", "jkl"]
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(
            result,
            expected,
            "All exactly 3-char segments are valid, ignoring shorter segments."
        )
    }

    /// Tests patterns containing Unicode characters beyond ASCII.
    func testExtractShortcutsUnicodeCharacters() {
        // Using a 3-character substring that includes a multi-byte character (e.g., "é").
        // This will still be valid since 'String(bytes:encoding:)' can decode them if the bytes are valid UTF-8.
        let pattern = "abé|ç|abcdef^ghïjk"
        // Splits into:
        //  - "abé" => length 3 (in terms of user-visible characters, though more bytes in UTF-8)
        //  - "ç" => length 1
        //  - "abcdef" => length 6
        //  - "ghïjk" => length 5
        // Notice that while "abé" is 3 user-visible characters, in UTF-8 it’s actually more bytes.
        // But as long as it’s valid UTF-8, it forms a valid substring with ≥ 3 visible characters
        //  (the "length" we check is in bytes, but for typical Unicode text,
        //   3 user-visible characters will usually be >= 3 bytes anyway).
        let expected = ["abé", "abcdef", "ghïjk"]
        let result = FilterRule.extractShortcuts(from: pattern)
        XCTAssertEqual(result, expected, "Should handle Unicode characters properly.")
    }

    // MARK: - Performance tests

    /// A performance test that generates a series of random patterns of varying lengths,
    /// then measures the time required to parse them using `extractShortcuts(from:)`.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.023 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testExtractShortcutsPerformanceRandomPatterns() {
        // Number of random patterns we want to generate and test.
        let iterationCount = 10_000
        let patternLengthRange: ClosedRange<Int> = 0...50

        // Possible characters, including special chars.
        let characters = Array("abcdefghijklmnopqrstuvwxyz0123456789|*^")

        // Generate random patterns.
        let randomPatterns: [String] = (0..<iterationCount).map { _ in
            let length = Int.random(in: patternLengthRange)
            var pattern = ""
            pattern.reserveCapacity(length)
            for _ in 0..<length {
                pattern.append(characters.randomElement()!)
            }
            return pattern
        }

        measure {
            // The measure block will run multiple times by default,
            // and Xcode will report the average execution time.
            for pattern in randomPatterns {
                _ = FilterRule.extractShortcuts(from: pattern)
            }
        }
    }
}
