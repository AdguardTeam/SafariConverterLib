import Foundation
import XCTest

@testable import ContentBlockerConverter

final class CosmeticRuleTests: XCTestCase {
    func testCosmeticRule() {
        struct TestCase {
            let ruleText: String
            var version: SafariVersion = DEFAULT_SAFARI_VERSION
            let expectedContent: String
            var expectedIsWhiteList = false
            var expectedIsElemhide = false
            var expectedIsExtendedCss = false
            var expectedIsInjectCss = false
            var expectedIsScript = false
            var expectedIsScriptlet = false
            var expectedPathModifier: String?
            var expectedPathRegExpSource: String?
            var expectedPermittedDomains: [String] = []
            var expectedRestrictedDomains: [String] = []
        }

        let testCases: [TestCase] = [
            TestCase(ruleText: "##.banner", expectedContent: ".banner", expectedIsElemhide: true),
            TestCase(ruleText: "*###banner", expectedContent: "#banner", expectedIsElemhide: true),
            TestCase(
                // Domain limitation.
                ruleText: "example.org,~example.com##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org"],
                expectedRestrictedDomains: ["example.com"]
            ),
            TestCase(
                // Punycode domain.
                ruleText: "почта.рф##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["xn--80a1acny.xn--p1ai"]
            ),
            TestCase(
                // Whitelist cosmetic rule.
                ruleText: "example.org#@#.banner",
                expectedContent: ".banner",
                expectedIsWhiteList: true,
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // CSS cosmetic rule.
                ruleText: "example.org#$#.textad { visibility: hidden; }",
                expectedContent: ".textad { visibility: hidden; }",
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // CSS injection cosmetic rule.
                ruleText: "example.org#$#div[id^=\"imAd_\"] { visibility: hidden!important; }",
                expectedContent: "div[id^=\"imAd_\"] { visibility: hidden!important; }",
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // CSS injection cosmetic whitelist rule.
                ruleText: "example.org#@$#.textad { visibility: hidden; }",
                expectedContent: ".textad { visibility: hidden; }",
                expectedIsWhiteList: true,
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // Extended CSS cosmetic rule.
                ruleText: "#?#.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true
            ),
            TestCase(
                // Extended CSS whitelist cosmetic rule.
                ruleText: "example.org#@?#.banner",
                expectedContent: ".banner",
                expectedIsWhiteList: true,
                expectedIsElemhide: true,
                expectedIsExtendedCss: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // Extended CSS cosmetic rule (auto-detect).
                ruleText: "##.banner:contains(cookies)",
                expectedContent: ".banner:contains(cookies)",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true
            ),
            TestCase(
                // Extended CSS cosmetic rule (auto-detect).
                ruleText: "##.banner:-abp-has(div)",
                expectedContent: ".banner:-abp-has(div)",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true
            ),
            TestCase(
                // Extended CSS whitelist cosmetic rule (auto-detect).
                ruleText: "#@#.sponsored[-ext-contains=test]",
                expectedContent: ".sponsored[-ext-contains=test]",
                expectedIsWhiteList: true,
                expectedIsElemhide: true,
                expectedIsExtendedCss: true
            ),
            TestCase(
                // Extended CSS whitelist cosmetic rule (auto-detect).
                ruleText: "example.org#@#.banner:contains(cookies)",
                expectedContent: ".banner:contains(cookies)",
                expectedIsWhiteList: true,
                expectedIsElemhide: true,
                expectedIsExtendedCss: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // Extended CSS injection cosmetic rule.
                ruleText: "#$?#.banner { display: none; }",
                expectedContent: ".banner { display: none; }",
                expectedIsExtendedCss: true,
                expectedIsInjectCss: true
            ),
            TestCase(
                // Extended CSS injection whitelist cosmetic rule.
                ruleText: "example.org#@$?#.banner { display: none; }",
                expectedContent: ".banner { display: none; }",
                expectedIsWhiteList: true,
                expectedIsExtendedCss: true,
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // Script rule.
                ruleText: "#%#test = 1;",
                expectedContent: "test = 1;",
                expectedIsScript: true
            ),
            TestCase(
                // Script whitelist rule.
                ruleText: "example.org#@%#test = 1;",
                expectedContent: "test = 1;",
                expectedIsWhiteList: true,
                expectedIsScript: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // Scriptlet rule.
                ruleText: "#%#//scriptlet(\"set-constant\", \"test\", \"true\")",
                expectedContent: "//scriptlet(\"set-constant\", \"test\", \"true\")",
                expectedIsScript: true,
                expectedIsScriptlet: true
            ),
            TestCase(
                // Scriptlet rule.
                ruleText: "#%#//scriptlet(\"noeval\")",
                expectedContent: "//scriptlet(\"noeval\")",
                expectedIsScript: true,
                expectedIsScriptlet: true
            ),
            TestCase(
                // Scriptlet whitelist rule.
                ruleText: "example.org#@%#//scriptlet(\"noeval\")",
                expectedContent: "//scriptlet(\"noeval\")",
                expectedIsWhiteList: true,
                expectedIsScript: true,
                expectedIsScriptlet: true,
                expectedPermittedDomains: ["example.org"]
            ),
            TestCase(
                // Cosmetic rule with $domain modifier options.
                ruleText: "[$domain=example.org|~example.com]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org"],
                expectedRestrictedDomains: ["example.com"]
            ),
            TestCase(
                // Cosmetic rule with mixed $domain options.
                ruleText: "[$domain=example.org|~example.com]example.net##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org", "example.net"],
                expectedRestrictedDomains: ["example.com"]
            ),
            TestCase(
                // Cosmetic rule with $from (alias of $domain).
                ruleText: "[$from=example.org|~example.com]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org"],
                expectedRestrictedDomains: ["example.com"]
            ),
            TestCase(
                // Cosmetic rule with path modifier.
                ruleText: "[$path=/]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPathModifier: "/",
                expectedPathRegExpSource: "\\/"
            ),
            TestCase(
                // Cosmetic rule with both options.
                ruleText: "[$domain=mail.ru,path=/^\\/$/]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPathModifier: "/^/$/",
                expectedPathRegExpSource: "^/$",
                expectedPermittedDomains: ["mail.ru"]
            ),
            TestCase(
                // :has is detected as extended CSS for Safari older than 16.4
                ruleText: "##div:has(.banner)",
                version: SafariVersion.safari16,
                expectedContent: "div:has(.banner)",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true
            ),
            TestCase(
                // :has is considered normal CSS for Safari 16.4 or newer
                ruleText: "##div:has(.banner)",
                version: SafariVersion.safari16_4,
                expectedContent: "div:has(.banner)",
                expectedIsElemhide: true
            ),
            TestCase(
                // :is is detected as extended CSS for Safari 13
                ruleText: "##div:is(.banner)",
                version: SafariVersion.safari13,
                expectedContent: "div:is(.banner)",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true
            ),
            TestCase(
                // :is is detected as normal CSS for Safari 14 or newer
                ruleText: "##div:is(.banner)",
                version: SafariVersion.safari14,
                expectedContent: "div:is(.banner)",
                expectedIsElemhide: true
            ),
        ]

        for testCase in testCases {
            let result = try! CosmeticRule(ruleText: testCase.ruleText, for: testCase.version)

            let msg = "Rule (\(testCase.ruleText)) does not match expected"

            XCTAssertEqual(result.ruleText, testCase.ruleText, msg)
            XCTAssertEqual(result.content, testCase.expectedContent, msg)
            XCTAssertEqual(result.isWhiteList, testCase.expectedIsWhiteList, msg)
            XCTAssertEqual(result.isElemhide, testCase.expectedIsElemhide, msg)
            XCTAssertEqual(result.isExtendedCss, testCase.expectedIsExtendedCss, msg)
            XCTAssertEqual(result.isInjectCss, testCase.expectedIsInjectCss, msg)
            XCTAssertEqual(result.isScript, testCase.expectedIsScript, msg)
            XCTAssertEqual(result.isScriptlet, testCase.expectedIsScriptlet, msg)
            XCTAssertEqual(result.pathModifier, testCase.expectedPathModifier, msg)
            XCTAssertEqual(result.pathRegExpSource, testCase.expectedPathRegExpSource, msg)
            XCTAssertEqual(result.permittedDomains, testCase.expectedPermittedDomains, msg)
            XCTAssertEqual(result.restrictedDomains, testCase.expectedRestrictedDomains, msg)
        }
    }

    func testForbiddenCSSRules() {
        XCTAssertThrowsError(try CosmeticRule(ruleText: "#$#.banner { background: url(test.png) }"))
        XCTAssertThrowsError(
            try CosmeticRule(ruleText: "#$?#.banner { background: url(test.png) }")
        )
    }
}
