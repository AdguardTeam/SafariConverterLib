import ContentBlockerConverter
import XCTest

@testable import FilterEngine

final class FilterRuleTests: XCTestCase {
    // MARK: - Init from rules

    func testInitFromRule() {
        struct TestCase {
            let ruleText: String
            var expectedError: Bool = false
            var expectedAction: Action?
            var safariVersion = SafariVersion.safari16_4
            var expectedUrlPattern: String?
            var expectedUrlRegex: String?
            var expectedPathRegex: String?
            var expectedPriority: UInt8 = 1
            var expectedPermittedDomains: [String]? = []
            var expectedRestrictedDomains: [String]? = []
            var expectedCosmeticContent: String?
        }

        let testCases: [TestCase] = [
            TestCase(
                ruleText: "@@||example.org^$elemhide",
                expectedAction: [.disableCSS],
                expectedUrlPattern: "||example.org^",
                expectedUrlRegex: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$"
            ),
            TestCase(
                ruleText: "@@||example.org^$elemhide,jsinject",
                expectedAction: [.disableCSS, .disableScript],
                expectedUrlPattern: "||example.org^",
                expectedUrlRegex: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$"
            ),
            TestCase(
                ruleText: "##.banner",
                expectedAction: [.cssDisplayNone],
                expectedUrlPattern: "*",
                expectedPriority: 0,
                expectedCosmeticContent: ".banner"
            ),
            TestCase(
                ruleText: "example.org#@#.banner",
                expectedError: true
            ),
            TestCase(
                ruleText: "@@||example.com^$jsinject",
                expectedAction: [.disableScript],
                expectedUrlPattern: "||example.com^",
                expectedUrlRegex: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.com([\\/:&\\?].*)?$",
                expectedPriority: 1
            ),
            TestCase(
                ruleText: "@@||example.com^$specifichide",
                expectedAction: [.disableSpecificCSS],
                expectedUrlPattern: "||example.com^",
                expectedUrlRegex: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.com([\\/:&\\?].*)?$",
                expectedPriority: 1
            ),
            TestCase(
                ruleText: "example.org#$#div[id^=\"imAd_\"] { visibility: hidden!important; }",
                expectedAction: [.cssInject],
                expectedUrlPattern: "*",
                expectedPriority: 0,
                expectedPermittedDomains: ["example.org"],
                expectedCosmeticContent: "div[id^=\"imAd_\"] { visibility: hidden!important; }"
            ),
            TestCase(
                ruleText: "||example.org^$third-party",
                expectedError: true
            ),
            TestCase(
                ruleText: "@@||example.org^$important",
                expectedError: true
            ),
            TestCase(
                ruleText: "@@||example.org^$important,elemhide",
                expectedAction: [.disableCSS],
                expectedUrlPattern: "||example.org^",
                expectedUrlRegex: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPriority: 2
            ),
            TestCase(
                ruleText: "||example.org^$important",
                expectedError: true
            ),
            TestCase(
                ruleText: "[$domain=example.org|~example.com]##.banner",
                expectedAction: [.cssDisplayNone],
                expectedUrlPattern: "*",
                expectedUrlRegex: nil,
                expectedPriority: 0,
                expectedPermittedDomains: ["example.org"],
                expectedRestrictedDomains: ["example.com"],
                expectedCosmeticContent: ".banner"
            ),
            TestCase(
                ruleText: "[$path=/]##.banner",
                expectedAction: [.cssDisplayNone],
                expectedUrlPattern: "*",
                expectedPathRegex: "\\/",
                expectedPriority: 0,
                expectedCosmeticContent: ".banner"
            ),
            TestCase(
                ruleText: "##div:has(.banner)",
                expectedAction: [.cssDisplayNone],
                expectedUrlPattern: "*",
                expectedPriority: 0,
                expectedCosmeticContent: "div:has(.banner)"
            ),
            TestCase(
                ruleText: "##div:is(.banner)",
                expectedAction: [.cssDisplayNone],
                expectedUrlPattern: "*",
                expectedPriority: 0,
                expectedCosmeticContent: "div:is(.banner)"
            ),
            TestCase(
                ruleText: "##div:contains(banner)",
                expectedAction: [.cssDisplayNone, .extendedCSS],
                expectedUrlPattern: "*",
                expectedPriority: 0,
                expectedCosmeticContent: "div:contains(banner)"
            ),
            TestCase(
                ruleText: "#$#div:contains(banner) { display: none; }",
                expectedAction: [.cssInject, .extendedCSS],
                expectedUrlPattern: "*",
                expectedPriority: 0,
                expectedCosmeticContent: "div:contains(banner) { display: none; }"
            ),
        ]

        for testCase in testCases {
            do {
                let rule = try RuleFactory.createRule(
                    ruleText: testCase.ruleText,
                    for: testCase.safariVersion
                )
                let filterRule = try FilterRule(from: rule!)

                let msg = "Rule (\(testCase.ruleText)) does not match expected"

                XCTAssertEqual(filterRule.action, testCase.expectedAction, msg)
                XCTAssertEqual(filterRule.urlPattern, testCase.expectedUrlPattern, msg)
                XCTAssertEqual(filterRule.urlRegex, testCase.expectedUrlRegex, msg)
                XCTAssertEqual(filterRule.priority, testCase.expectedPriority, msg)
                XCTAssertEqual(filterRule.permittedDomains, testCase.expectedPermittedDomains, msg)
                XCTAssertEqual(
                    filterRule.restrictedDomains,
                    testCase.expectedRestrictedDomains,
                    msg
                )
                XCTAssertEqual(filterRule.cosmeticContent, testCase.expectedCosmeticContent, msg)
                XCTAssertFalse(
                    testCase.expectedError,
                    "Unexpected success for rule: \(testCase.ruleText)"
                )
            } catch {
                XCTAssertTrue(
                    testCase.expectedError,
                    "Unexpected error for rule: \(testCase.ruleText)"
                )
            }
        }
    }
}
