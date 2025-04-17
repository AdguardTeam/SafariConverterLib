import Foundation
import XCTest

@testable import ContentBlockerConverter

final class RuleFactoryTests: XCTestCase {
    func testCreateRule() {
        struct TestCase {
            let ruleText: String
            var expectedNil: Bool = false
            var expectedError: Bool = false
            var expectedNetworkRule: Bool = false
            var expectedCosmeticRule: Bool = false
        }

        let testCases: [TestCase] = [
            // Empty rule
            TestCase(
                ruleText: "",
                expectedNil: true
            ),

            // Comment
            TestCase(
                ruleText: "! test",
                expectedNil: true
            ),

            // Invalid modifier
            TestCase(
                ruleText: "test$domain=",
                expectedNil: true,
                expectedError: true
            ),

            // Simple network rule
            TestCase(
                ruleText: "test",
                expectedNetworkRule: true
            ),

            // Complex network rule
            TestCase(
                ruleText: "@@||test$image,font",
                expectedNetworkRule: true
            ),

            // Element hiding rule
            TestCase(
                ruleText: "##.banner",
                expectedCosmeticRule: true
            ),

            // Scriptlet rule
            TestCase(
                ruleText: "#%#//scriptlet(\"test\")",
                expectedCosmeticRule: true
            ),

            // CSS injection rule
            TestCase(
                ruleText: "example.org#$#banner { display: none }",
                expectedCosmeticRule: true
            ),
        ]

        for testCase in testCases {
            var rule: Rule?

            do {
                rule = try RuleFactory.createRule(
                    ruleText: testCase.ruleText,
                    for: DEFAULT_SAFARI_VERSION
                )
            } catch {
                if !testCase.expectedError {
                    XCTAssertTrue(
                        false,
                        "Did not expect error \(error.localizedDescription) for \(testCase.ruleText)"
                    )
                    continue
                }
            }

            if testCase.expectedNil {
                XCTAssertNil(rule, "Expected nil for \(testCase.ruleText)")
            }

            if testCase.expectedNetworkRule {
                XCTAssertNotNil(rule, "Expected not nil for \(testCase.ruleText)")
                XCTAssertTrue(rule is NetworkRule, "Expected network rule for \(testCase.ruleText)")
            }

            if testCase.expectedCosmeticRule {
                XCTAssertNotNil(rule, "Expected not nil for \(testCase.ruleText)")
                XCTAssertTrue(
                    rule is CosmeticRule,
                    "Expected cosmetic rule for \(testCase.ruleText)"
                )
            }
        }
    }

    func testFilterOutRules() {
        struct ExpectedRule {
            /// For network rules we'll only check urlPattern
            var networkPattern: String?
            /// For cosmetic rules we'll only check content
            var cosmeticContent: String?
            var permittedDomains: [String] = []
            var restrictedDomains: [String] = []
        }

        struct TestCase {
            let name: String
            let rules: [String]
            let expectedRules: [ExpectedRule]
            let expectedErrorsCount: Int
        }

        let testCases: [TestCase] = [
            TestCase(
                name: "simple rules",
                rules: [
                    "||example.org^",
                    "##.banner",
                ],
                expectedRules: [
                    ExpectedRule(networkPattern: "||example.org^"),
                    ExpectedRule(cosmeticContent: ".banner"),
                ],
                expectedErrorsCount: 0
            ),
            TestCase(
                name: "all rules badfiltered",
                rules: [
                    "||example.org^",
                    "||example.org^$badfilter",
                ],
                expectedRules: [],
                expectedErrorsCount: 0
            ),
            TestCase(
                name: "negate css",
                rules: [
                    "##.banner",
                    "example.org#@#.banner",
                ],
                expectedRules: [
                    ExpectedRule(
                        cosmeticContent: ".banner",
                        restrictedDomains: ["example.org"]
                    )
                ],
                expectedErrorsCount: 0
            ),
            TestCase(
                name: "negate completely",
                rules: [
                    "example.org##.banner",
                    "example.org#@#.banner",
                ],
                expectedRules: [],
                expectedErrorsCount: 0
            ),
            TestCase(
                name: "negate all domains",
                rules: [
                    "example.org##.banner",
                    "#@#.banner",
                ],
                expectedRules: [],
                expectedErrorsCount: 0
            ),
            TestCase(
                name: "negate subdomain",
                rules: [
                    "sub.example.org##.banner",
                    "example.org#@#.banner",
                ],
                expectedRules: [],
                expectedErrorsCount: 0
            ),
            TestCase(
                name: "negate and not invalidate",
                rules: [
                    "example.com##.banner",
                    "example.org#@#.banner",
                ],
                expectedRules: [
                    ExpectedRule(
                        cosmeticContent: ".banner",
                        permittedDomains: ["example.com"]
                    )
                ],
                expectedErrorsCount: 0
            ),
        ]

        for testCase in testCases {
            let errorsCounter = ErrorsCounter()

            var rules = RuleFactory.createRules(
                lines: testCase.rules,
                for: SafariVersion.safari16_4,
                errorsCounter: errorsCounter
            )

            // Filter out CSS exceptions and $badfilter.
            rules = RuleFactory.filterOutExceptions(from: rules)

            XCTAssertEqual(testCase.expectedErrorsCount, errorsCounter.getCount())
            XCTAssertEqual(testCase.expectedRules.count, rules.count, testCase.name)

            if testCase.expectedRules.count == rules.count {
                for (index, expectedRule) in testCase.expectedRules.enumerated() {
                    let rule = rules[index]

                    XCTAssertEqual(
                        expectedRule.permittedDomains,
                        rule.permittedDomains,
                        testCase.name
                    )
                    XCTAssertEqual(
                        expectedRule.restrictedDomains,
                        rule.restrictedDomains,
                        testCase.name
                    )

                    if expectedRule.networkPattern != nil {
                        XCTAssertTrue(rule is NetworkRule, testCase.name)
                        let networkRule = rule as! NetworkRule
                        XCTAssertEqual(
                            expectedRule.networkPattern!,
                            networkRule.urlRuleText,
                            testCase.name
                        )
                    } else if expectedRule.cosmeticContent != nil {
                        XCTAssertTrue(rule is CosmeticRule, testCase.name)
                        let cosmeticRule = rule as! CosmeticRule
                        XCTAssertEqual(
                            expectedRule.cosmeticContent!,
                            cosmeticRule.content,
                            testCase.name
                        )
                    }
                }
            }
        }
    }
}
