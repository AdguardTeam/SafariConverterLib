import XCTest

@testable import ContentBlockerConverter

/// Helper methods and structs for testing converter.
extension ContentBlockerConverterTests {
    /// Helper struct that combines all the information for testing conversion.
    struct TestCase {
        let rules: [String]
        var version: SafariVersion = DEFAULT_SAFARI_VERSION
        var advancedBlocking: Bool = false
        let expectedSafariRulesJSON: String
        var expectedAdvancedRulesText: String?
        var expectedSourceRulesCount = 0
        var expectedSourceSafariCompatibleRulesCount = 0
        var expectedSafariRulesCount = 0
        var expectedAdvancedRulesCount = 0
        var expectedErrorsCount = 0
    }

    /// Runs an individual test case.
    func runTest(_ testCase: TestCase) {
        let converter = ContentBlockerConverter()
        let result = converter.convertArray(
            rules: testCase.rules,
            safariVersion: testCase.version,
            advancedBlocking: testCase.advancedBlocking
        )

        let msg =
            "Unexpected result for converting rules\n \(testCase.rules.joined(separator: "\n"))"

        XCTAssertEqual(result.sourceRulesCount, testCase.expectedSourceRulesCount, msg)
        XCTAssertEqual(
            result.sourceSafariCompatibleRulesCount,
            testCase.expectedSourceSafariCompatibleRulesCount,
            msg
        )
        XCTAssertEqual(result.safariRulesCount, testCase.expectedSafariRulesCount, msg)
        XCTAssertEqual(result.advancedRulesCount, testCase.expectedAdvancedRulesCount, msg)
        XCTAssertEqual(result.errorsCount, testCase.expectedErrorsCount, msg)
        assertContentBlockerJSON(result.safariRulesJSON, testCase.expectedSafariRulesJSON, msg)
        XCTAssertEqual(result.advancedRulesText, testCase.expectedAdvancedRulesText, msg)
    }

    /// Runs a list of test cases.
    func runTests(_ testCases: [TestCase]) {
        for testCase in testCases {
            runTest(testCase)
        }
    }

    /// Parses JSON into an array of `BlockerEntry`.
    func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8)!

        let decoder = JSONDecoder()
        let parsedData = try decoder.decode([BlockerEntry].self, from: data)

        return parsedData
    }

    /// Helper function that checks if the specified json matches the expected one.
    func assertContentBlockerJSON(_ json: String, _ expected: String, _ msg: String) {
        if expected == "" && json == "" {
            XCTAssertEqual(json, expected)
        }

        let expectedRules = try! parseJsonString(json: expected)
        let actualRules = try! parseJsonString(json: json)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let expectedRulesJSON = String(data: try! encoder.encode(expectedRules), encoding: .utf8)!
        let actualRulesJSON = String(data: try! encoder.encode(actualRules), encoding: .utf8)!

        XCTAssertEqual(expectedRulesJSON, actualRulesJSON, msg)
    }
}
