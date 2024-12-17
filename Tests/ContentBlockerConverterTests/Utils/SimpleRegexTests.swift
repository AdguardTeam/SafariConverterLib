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
            ("test.png|", "test\\.png$", false)
        ]

        for (pattern, expectedRegex, expectedError) in testPatterns {
            if expectedError {
                XCTAssertThrowsError(try SimpleRegex.createRegexText(pattern: pattern))
            } else {
                let regexText = try! SimpleRegex.createRegexText(pattern: pattern)
                XCTAssertEqual(regexText, expectedRegex, "Pattern \(pattern): expected regex \(expectedRegex), but got \(regexText)")
            }
        }
    }
}
