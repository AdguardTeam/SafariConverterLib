import Foundation
import XCTest

@testable import ContentBlockerConverter

final class NetworkRuleTests: XCTestCase {
    func testNetworkRule() throws {
        struct TestCase {
            let ruleText: String
            var version: SafariVersion = DEFAULT_SAFARI_VERSION
            let expectedUrlRuleText: String
            let expectedUrlRegExpSource: String?
            var expectedWhiteList = false
            var expectedThirdParty = false
            var expectedCheckThirdParty = false
            var expectedImportant = false
            var expectedDocumentWhitelist = false
            var expectedWebsocket = false
            var expectedUrlBlock = false
            var expectedCssExceptionRule = false
            var expectedJsInject = false
            var expectedMatchCase = false
            var expectedBlockPopups = false
            var expectedBadfilter = false
            var expectedPermittedDomains: [String] = []
            var expectedRestrictedDomains: [String] = []
            var expectedPermittedContentTypes: NetworkRule.ContentType = .all
            var expectedRestrictedContentTypes: NetworkRule.ContentType = []
            var expectedEnabledOptions: NetworkRule.Option = []
            var expectedDisabledOptions: NetworkRule.Option = []
        }

        let testCases: [TestCase] = [
            TestCase(
                // Normal rule without modifiers.
                ruleText: "||example.org^",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$"
            ),
            TestCase(
                // Whitelist rule.
                ruleText: "@@||example.org^",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWhiteList: true
            ),
            TestCase(
                // $match-case rule.
                ruleText: "||example.org^$match-case",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedMatchCase: true
            ),
            TestCase(
                // $popup rule.
                ruleText: "||example.org^$popup",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: .popup
            ),
            TestCase(
                // $important rule.
                ruleText: "||example.org^$important",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedImportant: true
            ),
            TestCase(
                // $document rule.
                ruleText: "@@||example.org^$document",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWhiteList: true,
                expectedDocumentWhitelist: true,
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: [.document]
            ),
            TestCase(
                // $elemhide rule.
                ruleText: "@@||example.org^$elemhide",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWhiteList: true,
                expectedCssExceptionRule: true,
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: [.elemhide]
            ),
            TestCase(
                // $jsinject rule.
                ruleText: "@@||example.org^$jsinject",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWhiteList: true,
                expectedJsInject: true,
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: [.jsinject]
            ),
            TestCase(
                // $jsinject rule.
                ruleText: "@@||example.org^$urlblock",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWhiteList: true,
                expectedUrlBlock: true,
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: [.urlblock]
            ),
            TestCase(
                // $jsinject rule.
                ruleText: "@@||example.org^$specifichide",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWhiteList: true,
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: [.specifichide]
            ),
            TestCase(
                // Third-party rule.
                ruleText: "||example.org^$third-party",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedThirdParty: true,
                expectedCheckThirdParty: true
            ),
            TestCase(
                // Third-party alias.
                ruleText: "||example.org^$3p",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedThirdParty: true,
                expectedCheckThirdParty: true
            ),
            TestCase(
                // Third-party alias.
                ruleText: "||example.org^$~1p",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedThirdParty: true,
                expectedCheckThirdParty: true
            ),
            TestCase(
                // Third-party alias.
                ruleText: "||example.org^$~first-party",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedThirdParty: true,
                expectedCheckThirdParty: true
            ),
            TestCase(
                // $all for Safari is the same as a standard rule.
                ruleText: "||example.org^$all",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$"
            ),
            TestCase(
                ruleText: "||example.org/this$is$path$image,font,media",
                expectedUrlRuleText: "||example.org/this$is$path",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org\\/this\\$is\\$path",
                expectedPermittedContentTypes: [.image, .font, .media]
            ),
            TestCase(
                // $websocket rule.
                ruleText: "||example.org^$websocket",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedWebsocket: true,
                expectedPermittedContentTypes: .websocket
            ),
            TestCase(
                // $subdocument blocking rule with $third-party.
                ruleText: "||example.org^$subdocument,third-party",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedThirdParty: true,
                expectedCheckThirdParty: true,
                expectedPermittedContentTypes: .subdocument
            ),
            TestCase(
                // $subdocument blocking rule (allowed starting with Safari 15).
                ruleText: "||example.org^$subdocument",
                version: SafariVersion.safari15,
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedContentTypes: .subdocument
            ),
            TestCase(
                // $document for blocking page load.
                ruleText: "||example.org^$document",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedContentTypes: .document,
                expectedEnabledOptions: [.document]
            ),
            TestCase(
                ruleText: "||example.org\\$smth",
                expectedUrlRuleText: "||example.org\\$smth",
                expectedUrlRegExpSource: "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org\\\\\\$smth"
            ),
            TestCase(
                // Test $domain modifier.
                ruleText: "||example.org^$domain=example.org|~sub.example.org",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedDomains: ["example.org"],
                expectedRestrictedDomains: ["sub.example.org"]
            ),
            TestCase(
                // Test $from alias.
                ruleText: "||example.org^$from=example.org",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                ruleText: "//$from=example.org",
                expectedUrlRuleText: "//",
                expectedUrlRegExpSource: "\\/\\/",
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                ruleText: "/regex/",
                expectedUrlRuleText: "/regex/",
                expectedUrlRegExpSource: "regex"
            ),
            TestCase(
                ruleText: "@@/regex/",
                expectedUrlRuleText: "/regex/",
                expectedUrlRegExpSource: "regex",
                expectedWhiteList: true
            ),
            TestCase(
                ruleText: "@@/regex/$third-party",
                expectedUrlRuleText: "/regex/",
                expectedUrlRegExpSource: "regex",
                expectedWhiteList: true,
                expectedThirdParty: true,
                expectedCheckThirdParty: true
            ),
            TestCase(
                ruleText: "/example{/",
                expectedUrlRuleText: "/example{/",
                expectedUrlRegExpSource: "example{"
            ),
            TestCase(
                ruleText: #"/^http:\/\/example\.org\/$/"#,
                expectedUrlRuleText: #"/^http:\/\/example\.org\/$/"#,
                expectedUrlRegExpSource: #"^http:\/\/example\.org\/$"#
            ),
            TestCase(
                // Checking if correctly transformed to regex.
                ruleText: "/addyn|*|adtech",
                expectedUrlRuleText: "/addyn|*|adtech",
                expectedUrlRegExpSource: #"\/addyn\|.*\|adtech"#
            ),
            TestCase(
                // Rule that matches all URLs.
                ruleText: "$image,frame,domain=a.com",
                expectedUrlRuleText: "",
                expectedUrlRegExpSource: nil,
                expectedPermittedDomains: ["a.com"],
                expectedPermittedContentTypes: [.image, .subdocument]
            ),
            TestCase(
                // $ping rule (supported starting with Safari 14 only).
                ruleText: "||example.org^$ping",
                version: SafariVersion.safari14,
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedContentTypes: .ping
            ),
            TestCase(
                // $~ping rule (supported starting with Safari 14 only).
                ruleText: "||example.org^$~ping",
                version: SafariVersion.safari14,
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedRestrictedContentTypes: .ping
            ),
            TestCase(
                // Testing egde case - the rule looks like it's a regex, but it has options.
                ruleText: "/example/$domain=test.com/",
                expectedUrlRuleText: "/example/",
                expectedUrlRegExpSource: "example",
                // Domain is invalid, but it doesn't break Safari.
                expectedPermittedDomains: ["test.com/"]
            ),
            TestCase(
                // $badfilter rule.
                ruleText: "||example.org^$badfilter",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedBadfilter: true
            ),
            TestCase(
                // Testing if we can correctly convert domain in the rule to punycode.
                ruleText: "||почта.рф^",
                expectedUrlRuleText: "||xn--80a1acny.xn--p1ai^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?xn--80a1acny\\.xn--p1ai([\\/:&\\?].*)?$"
            ),
            TestCase(
                // Testing if we can correctly convert domain in the $domain modifier to punycode.
                ruleText: "||example.org^$domain=почта.рф|example.net",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedDomains: ["xn--80a1acny.xn--p1ai", "example.net"]
            ),
            TestCase(
                // Noop modifier
                ruleText:
                    "||example.org^$domain=example.org,__,_,image,__________,script,_,___,_,_,_,_,__",
                expectedUrlRuleText: "||example.org^",
                expectedUrlRegExpSource:
                    "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$",
                expectedPermittedDomains: ["example.org"],
                expectedPermittedContentTypes: [.image, .script]
            ),
        ]

        for testCase in testCases {
            let result = try NetworkRule(ruleText: testCase.ruleText, for: testCase.version)

            let msg = "Rule (\(testCase.ruleText)) does not match expected"

            XCTAssertEqual(result.ruleText, testCase.ruleText, msg)
            XCTAssertEqual(result.urlRuleText, testCase.expectedUrlRuleText, msg)
            XCTAssertEqual(result.urlRegExpSource, testCase.expectedUrlRegExpSource, msg)
            XCTAssertEqual(result.isWhiteList, testCase.expectedWhiteList, msg)
            XCTAssertEqual(result.isThirdParty, testCase.expectedThirdParty, msg)
            XCTAssertEqual(result.isCheckThirdParty, testCase.expectedCheckThirdParty, msg)
            XCTAssertEqual(result.isImportant, testCase.expectedImportant, msg)
            XCTAssertEqual(result.isDocumentWhiteList, testCase.expectedDocumentWhitelist, msg)
            XCTAssertEqual(result.isWebSocket, testCase.expectedWebsocket, msg)
            XCTAssertEqual(result.isUrlBlock, testCase.expectedUrlBlock, msg)
            XCTAssertEqual(result.isJsInject, testCase.expectedJsInject, msg)
            XCTAssertEqual(result.isCssExceptionRule, testCase.expectedCssExceptionRule, msg)
            XCTAssertEqual(result.isMatchCase, testCase.expectedMatchCase, msg)
            XCTAssertEqual(result.isBadfilter, testCase.expectedBadfilter, msg)
            XCTAssertEqual(result.permittedDomains, testCase.expectedPermittedDomains, msg)
            XCTAssertEqual(result.restrictedDomains, testCase.expectedRestrictedDomains, msg)
            XCTAssertEqual(result.permittedContentType, testCase.expectedPermittedContentTypes, msg)
            XCTAssertEqual(
                result.restrictedContentType,
                testCase.expectedRestrictedContentTypes,
                msg
            )
            XCTAssertEqual(result.enabledOptions, testCase.expectedEnabledOptions, msg)
            XCTAssertEqual(result.disabledOptions, testCase.expectedDisabledOptions, msg)
        }
    }

    func testNetworkRuleWithInvalidRules() {
        // $replace is not supported by Safari.
        XCTAssertThrowsError(try NetworkRule(ruleText: "/example/$replace=/test/test2/"))
        // $elemhide is only allowed for whitelist rules.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$elemhide"))
        // $jsinject is only allowed for whitelist rules.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$jsinject"))
        // $specifichide is only allowed for whitelist rules.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$specifichide"))
        // $urlblock is only allowed for whitelist rules.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$urlblock"))
        // $csp is not supported by Safari.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$csp=script-src self"))
        // $redirect-rule is not supported by Safari.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$redirect-rule=noopjs"))
        // $redirect is not supported by Safari.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$redirect=noopjs"))
        // $empty is not supported by Safari.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$empty"))
        // $mp4 is not supported by Safari.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$mp4"))
        // $document cannot have a value.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$doc=test"))
        // $domain must have a valid value.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$domain="))
        // $domain must have a valid value.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$domain=~"))
        // $object not supported.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$object"))
        // $domain must have a valid value.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$domain=e"))
        // $domain must have a valid value.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$domain=~e"))
        // $domain with regexes are not supported.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org^$domain=/example.org/"))
        // $domain with regexes are not supported.
        XCTAssertThrowsError(
            try NetworkRule(ruleText: "||example.org^$domain=example.org|/test.com/")
        )
        // Non-ASCII symbols outside the domain are not supported and not encoded.
        XCTAssertThrowsError(try NetworkRule(ruleText: "||example.org/почта"))
        // $ping is not supported in the older Safari versions
        XCTAssertThrowsError(
            try NetworkRule(ruleText: "||example.org^$ping", for: SafariVersion.safari13)
        )
        XCTAssertThrowsError(
            try NetworkRule(ruleText: "||example.org^$~ping", for: SafariVersion.safari13)
        )
        // $subdocument blocking without $third-party is only allowed starting with
        // Safari 15 when load-context was introduced.
        XCTAssertThrowsError(
            try NetworkRule(ruleText: "||example.org^$subdocument", for: SafariVersion.safari14)
        )
    }

    func testExtractDomain() {
        let testPatterns:
            [(pattern: String, expectedDomain: String, expectedPatternMatchesPath: Bool)] = [
                ("", "", false),
                ("/", "", false),
                ("@@", "", false),
                ("@@^", "", false),
                ("@@/", "", false),
                ("example", "example", false),
                ("test.com/path^", "test.com", true),
                ("example.com", "example.com", false),
                ("||example.com", "example.com", false),
                ("||example.com/path", "example.com", true),
                ("||invalid/path", "invalid", true),
                ("http://example.org$", "example.org", false),
                ("https://example.org^someother", "example.org", true),
            ]

        for testPattern in testPatterns {
            let result = NetworkRuleParser.extractDomain(pattern: testPattern.pattern)
            XCTAssertEqual(
                result.domain,
                testPattern.expectedDomain,
                "Pattern \(testPattern.pattern): expected domain \(testPattern.expectedDomain), but got \(result.domain)"
            )
            XCTAssertEqual(
                result.patternMatchesPath,
                testPattern.expectedPatternMatchesPath,
                "Pattern \(testPattern.pattern): expected patternMatchesPath \(testPattern.expectedPatternMatchesPath), but got \(result.patternMatchesPath)"
            )
        }
    }

    func testExtractDomainAndValidate() {
        let testPatterns:
            [(pattern: String, expectedDomain: String, expectedPatternMatchesPath: Bool)] = [
                ("", "", false),
                ("/", "", false),
                ("@@", "", false),
                ("@@^", "", false),
                ("@@/", "", false),
                ("example", "", false),
                ("example.com", "example.com", false),
                ("||example.com", "example.com", false),
                ("||example.com/path", "example.com", true),
                ("||invalid/path", "", false),
                ("http://example.org$", "example.org", false),
                ("https://example.org^someother", "example.org", true),
            ]

        for testPattern in testPatterns {
            let result = NetworkRuleParser.extractDomainAndValidate(pattern: testPattern.pattern)
            XCTAssertEqual(
                result.domain,
                testPattern.expectedDomain,
                "Pattern \(testPattern.pattern): expected domain \(testPattern.expectedDomain), but got \(result.domain)"
            )
            XCTAssertEqual(
                result.patternMatchesPath,
                testPattern.expectedPatternMatchesPath,
                "Pattern \(testPattern.pattern): expected patternMatchesPath \(testPattern.expectedPatternMatchesPath), but got \(result.patternMatchesPath)"
            )
        }
    }

    func testNegatesBadfilter() {
        let testRules: [(rule: String, badfilter: String, expected: Bool)] = [
            ("||example.org^", "||example.org^$badfilter", true),
            ("||example.org", "||example.org^$badfilter", false),
            ("||example.org^$script", "||example.org^$badfilter", false),
            ("||example.org^$script", "||example.org^$script,badfilter", true),
            ("||example.org^$script,xhr", "||example.org^$script,badfilter", false),
            ("||example.org^$script,xhr", "||example.org^$script,xhr,badfilter", true),
            ("||example.org^", "||example.org^$badfilter,domain=example.com", false),
            ("||example.org^$domain=~example.com", "||example.org^$badfilter", false),
            (
                "||example.org^$domain=~example.com",
                "||example.org^$domain=~example.com,badfilter", true
            ),
            (
                "||example.org^$domain=example.com", "||example.org^$badfilter,domain=example.com",
                true
            ),
            (
                "||example.org^$domain=example.com|example.net",
                "||example.org^$badfilter,domain=example.org|example.com", true
            ),
        ]

        for (rule, badfilter, expected) in testRules {
            let networkRule = try! NetworkRule(ruleText: rule)
            let badfilterRule = try! NetworkRule(ruleText: badfilter)
            XCTAssertEqual(
                badfilterRule.negatesBadfilter(specifiedRule: networkRule),
                expected,
                "Rule \(badfilter) expected to \(expected ? "negate" : "not negate") \(rule)"
            )
        }
    }
}
