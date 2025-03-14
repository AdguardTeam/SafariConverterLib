import XCTest

@testable import ContentBlockerConverter

final class SimpleRegexTests: XCTestCase {
    func testCreateRegexText() throws {
        let testPatterns: [(pattern: String, expectedRegex: String, expectedError: Bool)] = [
            ("||example.org", #"^[htpsw]+:\/\/([a-z0-9-]+\.)?example\.org"#, false),
            ("||example.org^", #"^[htpsw]+:\/\/([a-z0-9-]+\.)?example\.org([\/:&\?].*)?$"#, false),
            ("экзампл.org", "", true),
            ("test", "test", false),
            ("//test.png", "\\/\\/test\\.png", false),
            ("|test.png", "^test\\.png", false),
            ("test.png|", "test\\.png$", false),
        ]

        for (pattern, expectedRegex, expectedError) in testPatterns {
            if expectedError {
                XCTAssertThrowsError(try SimpleRegex.createRegexText(pattern: pattern))
            } else {
                let regexText = try! SimpleRegex.createRegexText(pattern: pattern)
                XCTAssertEqual(
                    regexText,
                    expectedRegex,
                    "Pattern \(pattern): expected regex \(expectedRegex), but got \(regexText)"
                )
            }
        }
    }

    func testIsRegexPattern() {
        let testCases: [(pattern: String, expected: Bool)] = [
            ("/regex/", true),
            ("//", false),  // Do not consider this a regex
            ("/a/", true),  // Minimal valid regex
            ("/regex", false),  // Missing closing slash
            ("regex/", false),  // Missing opening slash
            ("regex", false),  // No slashes
            ("", false),  // Empty string
            ("||example.org", false),  // Domain pattern
            ("|example.org|", false),  // Pipe-enclosed pattern
            ("/regex\\/with\\/escaped\\/slashes/", true),  // Regex with escaped slashes
        ]

        for (pattern, expected) in testCases {
            let result = SimpleRegex.isRegexPattern(pattern)
            XCTAssertEqual(
                result,
                expected,
                "Pattern '\(pattern)': expected isRegexPattern to be \(expected), but got \(result)"
            )
        }
    }

    func testExtractRegex() {
        let testCases: [(pattern: String, expected: String?)] = [
            ("/regex/", "regex"),
            ("//", nil),  // Not a regex
            ("/a/", "a"),  // Minimal valid regex
            ("/complex\\d+regex[a-z]*/", "complex\\d+regex[a-z]*"),
            ("/regex\\/with\\/escaped\\/slashes/", "regex\\/with\\/escaped\\/slashes"),
            ("regex", nil),  // Not a regex pattern
            ("", nil),  // Empty string
            ("||example.org", nil),  // Domain pattern
            ("|test|", nil),  // Not a regex pattern
        ]

        for (pattern, expected) in testCases {
            let result = SimpleRegex.extractRegex(pattern)
            XCTAssertEqual(
                result,
                expected,
                "Pattern '\(pattern)': expected extractRegex to be \(expected ?? "nil"), but got \(result ?? "nil"))"
            )
        }
    }
}
