import Foundation

import XCTest
@testable import ContentBlockerConverter

final class CosmeticRuleTests: XCTestCase {
    override func tearDown() {
        // Restore the default state.
        SafariService.current.version = DEFAULT_SAFARI_VERSION
    }
    
    func testCosmeticRule() {
        struct TestCase {
            let ruleText: String
            let expectedContent: String
            var expectedIsWhitelist = false
            var expectedIsElemhide = false
            var expectedIsExtendedCss = false
            var expectedIsInjectCss = false
            var expectedIsScript = false
            var expectedIsScriptlet = false
            var expectedScriptlet: String?
            var expectedScriptletParam: String?
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
                expectedRestrictedDomains: ["example.com"]),
            TestCase(
                // Punycode domain.
                ruleText: "почта.рф##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["xn--80a1acny.xn--p1ai"]),
            TestCase(
                // Whitelist cosmetic rule.
                ruleText: "example.org#@#.banner",
                expectedContent: ".banner",
                expectedIsWhitelist: true,
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // CSS cosmetic rule.
                ruleText: "example.org#$#.textad { visibility: hidden; }",
                expectedContent: ".textad { visibility: hidden; }",
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // CSS injection cosmetic rule.
                ruleText: "example.org#$#div[id^=\"imAd_\"] { visibility: hidden!important; }",
                expectedContent: "div[id^=\"imAd_\"] { visibility: hidden!important; }",
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // CSS injection cosmetic whitelist rule.
                ruleText: "example.org#@$#.textad { visibility: hidden; }",
                expectedContent: ".textad { visibility: hidden; }",
                expectedIsWhitelist: true,
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // Extended CSS cosmetic rule.
                ruleText: "#?#.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true),
            TestCase(
                // Extended CSS whitelist cosmetic rule.
                ruleText: "example.org#@?#.banner",
                expectedContent: ".banner",
                expectedIsWhitelist: true,
                expectedIsElemhide: true,
                expectedIsExtendedCss: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // Extended CSS cosmetic rule (auto-detect).
                ruleText: "##.banner:contains(cookies)",
                expectedContent: ".banner:contains(cookies)",
                expectedIsElemhide: true,
                expectedIsExtendedCss: true),
            TestCase(
                // Extended CSS whitelist cosmetic rule (auto-detect).
                ruleText: "#@#.sponsored[-ext-contains=test]",
                expectedContent: ".sponsored[-ext-contains=test]",
                expectedIsWhitelist: true,
                expectedIsElemhide: true,
                expectedIsExtendedCss: true),
            TestCase(
                // Extended CSS whitelist cosmetic rule (auto-detect).
                ruleText: "example.org#@#.banner:contains(cookies)",
                expectedContent: ".banner:contains(cookies)",
                expectedIsWhitelist: true,
                expectedIsElemhide: true,
                expectedIsExtendedCss: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // Extended CSS injection cosmetic rule.
                ruleText: "#$?#.banner { display: none; }",
                expectedContent: ".banner { display: none; }",
                expectedIsExtendedCss: true,
                expectedIsInjectCss: true),
            TestCase(
                // Extended CSS injection whitelist cosmetic rule.
                ruleText: "example.org#@$?#.banner { display: none; }",
                expectedContent: ".banner { display: none; }",
                expectedIsWhitelist: true,
                expectedIsExtendedCss: true,
                expectedIsInjectCss: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // Script rule.
                ruleText: "#%#test = 1;",
                expectedContent: "test = 1;",
                expectedIsScript: true),
            TestCase(
                // Script whitelist rule.
                ruleText: "example.org#@%#test = 1;",
                expectedContent: "test = 1;",
                expectedIsWhitelist: true,
                expectedIsScript: true,
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // Scriptlet rule.
                ruleText: "#%#//scriptlet(\"set-constant\", \"test\", \"true\")",
                expectedContent: "//scriptlet(\"set-constant\", \"test\", \"true\")",
                expectedIsScript: true,
                expectedIsScriptlet: true,
                expectedScriptlet: "set-constant",
                expectedScriptletParam: "{\"name\":\"set-constant\",\"args\":[\"test\",\"true\"]}"),
            TestCase(
                // Scriptlet rule.
                ruleText: "#%#//scriptlet(\"noeval\")",
                expectedContent: "//scriptlet(\"noeval\")",
                expectedIsScript: true,
                expectedIsScriptlet: true,
                expectedScriptlet: "noeval",
                expectedScriptletParam: "{\"name\":\"noeval\",\"args\":[]}"),
            TestCase(
                // Scriptlet whitelist rule.
                ruleText: "example.org#@%#//scriptlet(\"noeval\")",
                expectedContent: "//scriptlet(\"noeval\")",
                expectedIsWhitelist: true,
                expectedIsScript: true,
                expectedIsScriptlet: true,
                expectedScriptlet: "noeval",
                expectedScriptletParam: "{\"name\":\"noeval\",\"args\":[]}",
                expectedPermittedDomains: ["example.org"]),
            TestCase(
                // Cosmetic rule with domain modifier options.
                ruleText: "[$domain=example.org|~example.com]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org"],
                expectedRestrictedDomains: ["example.com"]),
            TestCase(
                // Cosmetic rule with mixed domain options.
                ruleText: "[$domain=example.org|~example.com]example.net##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["example.org", "example.net"],
                expectedRestrictedDomains: ["example.com"]),
            TestCase(
                // Cosmetic rule with path modifier.
                ruleText: "[$path=/]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPathModifier: "/",
                expectedPathRegExpSource: "\\/"),
            TestCase(
                // Cosmetic rule with both options.
                ruleText: "[$domain=mail.ru,path=/^\\/$/]##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPathModifier: "/^\\/$/",
                expectedPathRegExpSource: "^\\/$",
                expectedPermittedDomains: ["mail.ru"]),
        ]

        for testCase in testCases {
            let result = try! CosmeticRule(ruleText: testCase.ruleText)
            
            let msg = "Rule (\(testCase.ruleText)) does not match expected"
            
            XCTAssertEqual(result.ruleText, testCase.ruleText, msg)
            XCTAssertEqual(result.content, testCase.expectedContent, msg)
            XCTAssertEqual(result.isWhiteList, testCase.expectedIsWhitelist, msg)
            XCTAssertEqual(result.isElemhide, testCase.expectedIsElemhide, msg)
            XCTAssertEqual(result.isExtendedCss, testCase.expectedIsExtendedCss, msg)
            XCTAssertEqual(result.isInjectCss, testCase.expectedIsInjectCss, msg)
            XCTAssertEqual(result.isScript, testCase.expectedIsScript, msg)
            XCTAssertEqual(result.isScriptlet, testCase.expectedIsScriptlet, msg)
            XCTAssertEqual(result.scriptlet, testCase.expectedScriptlet, msg)
            XCTAssertEqual(result.scriptletParam, testCase.expectedScriptletParam, msg)
            XCTAssertEqual(result.pathModifier, testCase.expectedPathModifier, msg)
            XCTAssertEqual(result.pathRegExpSource, testCase.expectedPathRegExpSource, msg)
            XCTAssertEqual(result.permittedDomains, testCase.expectedPermittedDomains, msg)
            XCTAssertEqual(result.restrictedDomains, testCase.expectedRestrictedDomains, msg)
        }

    }

    func testForbiddenCSSRules() {
        XCTAssertThrowsError(try CosmeticRule(ruleText: "#$#.banner { background: url(test.png) }"))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "#?$#.banner { background: url(test.png) }"))
    }

}
