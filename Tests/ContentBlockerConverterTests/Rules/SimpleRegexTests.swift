import XCTest

@testable import ContentBlockerConverter

final class SimpleRegexTests: XCTestCase {
    func testCreateRegexText() throws {
        let testPatterns: [(pattern: String, expectedRegex: String, expectedError: Bool)] = [
            ("||example.org", #"^[^:]+://+([^:/]+\.)?example\.org"#, false),
            ("||example.org:8080", #"^[^:]+://+([^:/]+\.)?example\.org:8080"#, false),
            ("||example.org^", #"^[^:]+://+([^:/]+\.)?example\.org[/:]"#, false),
            ("||example.org^|", #"^[^:]+://+([^:/]+\.)?example\.org[/:]$"#, false),
            (
                "||example.org^path^param=value",
                #"^[^:]+://+([^:/]+\.)?example\.org[/:]path[/:&?]param=value"#,
                false
            ),
            (
                "||example.org*^test=123",
                #"^[^:]+://+([^:/]+\.)?example\.org.*[/:&?]test=123"#,
                false
            ),
            ("test^", #"test[/:&?]?"#, false),
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

    func testSplitAlternateRegexEndSeparator() {
        // Returns nil for inputs that don't end with regexEndSeparator
        let nilCases = [
            "",
            "test",
            #"^[^:]+://+([^:/]+\.)?example\.org[/:]"#,
            #"test[/:&?]"#,
            "abc$",
            "[/:&?",
        ]

        for input in nilCases {
            XCTAssertNil(
                SimpleRegex.splitAlternateRegexEndSeparator(input),
                "Expected nil for '\(input)'"
            )
        }

        // Splits inputs ending with "[/:&?]?" into two variants
        let splitCases: [(input: String, first: String, second: String)] = [
            // Realistic: pattern "test^" produces "test[/:&?]?"
            (
                #"test[/:&?]?"#,
                #"test[/:&?]"#,
                "test$"
            ),
            // Realistic: "||example.org/path^" conversion result
            (
                #"^[^:]+://+([^:/]+\.)?example\.org\/path[/:&?]?"#,
                #"^[^:]+://+([^:/]+\.)?example\.org\/path[/:&?]"#,
                #"^[^:]+://+([^:/]+\.)?example\.org\/path$"#
            ),
            // Minimal: just the suffix itself
            (
                "[/:&?]?",
                "[/:&?]",
                "$"
            ),
        ]

        for (input, expectedFirst, expectedSecond) in splitCases {
            let result = SimpleRegex.splitAlternateRegexEndSeparator(input)
            XCTAssertNotNil(result, "Expected non-nil for '\(input)'")
            XCTAssertEqual(result?.count, 2, "Expected 2 elements for '\(input)'")
            XCTAssertEqual(
                result?[0],
                expectedFirst,
                "First variant mismatch for '\(input)'"
            )
            XCTAssertEqual(
                result?[1],
                expectedSecond,
                "Second variant mismatch for '\(input)'"
            )
        }
    }

    func testUnescapeDomainRegex() {
        let testCases: [(pattern: String, expected: String)] = [
            (#"abc"#, #"abc"#),
            (#"a\/b"#, #"a/b"#),
            (#"a\|b"#, #"a|b"#),
            (#"a\$b"#, #"a$b"#),
            (#"a\,b"#, #"a,b"#),
            (#"a\.b"#, #"a\.b"#),
            (#"a\\/"#, #"a\/"#),
            ("a\\", "a\\"),
        ]

        for (pattern, expected) in testCases {
            let result = SimpleRegex.unescapeDomainRegex(pattern)
            XCTAssertEqual(
                result,
                expected,
                "Pattern '\(pattern)': expected unescapeDomainRegex to return \(expected), but got \(result)"
            )
        }
    }
}
