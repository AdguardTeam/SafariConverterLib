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
                // TLD domain.
                ruleText: "jp##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["jp"]
            ),
            TestCase(
                // Several domains.
                ruleText: "jp,com##.banner",
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: ["jp", "com"]
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
                // Regex domain containing \| (escaped pipe) must be treated as a single
                // domain, not split on |.
                ruleText: #"[$domain=/foo\.(com\|net)/]##.banner"#,
                version: .safari26,
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedPermittedDomains: [#"/foo\.(com\|net)/"#]
            ),
            TestCase(
                // Restricted regex domain containing \| must also parse as single domain.
                ruleText: #"[$domain=~/foo\.(com\|net)/]##.banner"#,
                version: .safari26,
                expectedContent: ".banner",
                expectedIsElemhide: true,
                expectedRestrictedDomains: [#"/foo\.(com\|net)/"#]
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

    func testInvalidCSSRules() {
        XCTAssertThrowsError(try CosmeticRule(ruleText: "a##.banner"))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "jp,##.banner"))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "jp,b##.banner"))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "jp,~b##.banner"))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "com,/example/##.banner", for: .safari16_4))
        XCTAssertNoThrow(try CosmeticRule(ruleText: "com,/example/##.banner", for: .safari26))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "~/example/##.banner", for: .safari16_4))
        XCTAssertNoThrow(try CosmeticRule(ruleText: "~/example/##.banner", for: .safari26))
        XCTAssertThrowsError(try CosmeticRule(ruleText: "[$path=/path]#@#.banner"))
    }

    func testForbiddenCSSRules() {
        XCTAssertThrowsError(try CosmeticRule(ruleText: "#$#.banner { background: url(test.png) }"))
        XCTAssertThrowsError(
            try CosmeticRule(ruleText: "#$?#.banner { background: url(test.png) }")
        )

        // Rules that must be rejected.
        let forbiddenRules = [
            // Different case.
            "#$#.banner { background: URL(test.png) }",
            "#$#.banner { background: Url(test.png) }",
            "#$#.banner { background: uRl(test.png) }",
            // CSS escapes.
            #"#$#.banner { background: \75 rl(https://example.org) }"#,
            #"#$#.banner { background: \000075rl(https://example.org) }"#,
            #"#$#.banner { background: \75rl(https://example.org) }"#,
            #"#$#.banner { background: u\72 l(https://example.org) }"#,
            #"#$#.banner { background: ur\6c(https://example.org) }"#,
            #"#$#.banner { background: \75\52\4C(https://example.org) }"#,
            // image-set in different spellings.
            #"#$#.banner { background: image-set("https://example.org" 1x) }"#,
            #"#$#.banner { background: IMAGE-SET("https://example.org" 1x) }"#,
            #"#$#.banner { background: image-\73 et("https://example.org" 1x) }"#,
            #"#$#.banner { background: -webkit-image-set("https://example.org" 1x) }"#,
            // Nested url in a function that is not forbidden on its own.
            "#$#.banner { background: -webkit-cross-fade(URL(a), URL(b), 50%) }",
            // Different CSS properties.
            "#$#.banner { cursor: URL(test.png) }",
            "#$#.banner { list-style-image: URL(test.png) }",
            "#$#.banner { border-image: URL(test.png) }",
            // String form with spaces.
            #"#$#.banner { background: URL( "https://example.org" ) }"#,
            // Via a CSS variable.
            "#$#.banner { --u: URL(https://example.org); background: var(--u) }",
            // Conditional beacon.
            #"#$#input[value^="a"] { background: URL(https://example.org/a) }"#,
            // Generic rule without domains.
            "#$#body { background: URL(https://example.org) }",
            // @font-face.
            "#$#@font-face { font-family: t; src: URL(https://example.org/font.woff2) }",
            // CSS injection markers that reach the engine.
            "#$?#.banner:has(.child) { background: URL(test.png) }",
            // @import.
            #"#$#@import "https://example.org/x.css"; body { color: red }"#,
            #"#$#@\69 mport "https://example.org/x.css"; body { color: red }"#,
            // Other url forms.
            "#$#.banner { background: URL(data:image/png;base64,iVBORw0KGgo=) }",
            "#$#.banner { background: URL() }",
            // An unescaped newline terminates the string, but the rest
            // of the rule is still scanned.
            "#$#p::before { content: \"abc\nurl(https://example.org) }",
            // CRLF after a hex escape counts as a single whitespace.
            "#$#.banner { background: ur\\6c\r\n(https://example.org) }",
            // At-rule at the very end of the content.
            "#$?#@import",
            // Extended element hiding rules with style blocks.
            "#?##div { background: URL(https://example.org) }",
            "##div:has-text(x) { background: url(https://example.org) }",
            // @import followed by a string or a comment, no whitespace.
            "#$#@import\"https://example.org/x.css\";a{}",
            "#$#@import'https://example.org/x.css';a{}",
            "#$#@import/*b*/\"https://example.org/x.css\";a{}",
            #"#$#@im\70 ort"https://example.org/x.css";a{}"#,
            // Form feed terminates the string as a bad string, so the
            // rest of the rule is still scanned. The #$?# marker is
            // used because the ABP mask of the #$# one turns rules
            // with form feeds into scriptlets before the guard.
            "#$?#.banner { content: \"a\u{0C}; background: url(https://example.org) }",
            // Over-block: the :has-text argument does not load anything,
            // but the whole rule content is scanned by design.
            "#$?#.banner:has-text(@import) { color: red }",
            // Known over-block: @namespace never loads anything, but it
            // is cut by the url( in it.
            "#$?##@namespace url(http://www.w3.org/2000/svg)",
            // A string opened in the selector can swallow the style
            // block for the whole-content scan, so the style block is
            // scanned separately.
            "#?#div:has-text(\"), * { background: url(\"https://example.org\") }",
            "#$?#div:has-text(\"), * { background: url(\"https://example.org\") }",
            "##div:has-text(\"), * { background: url(\"https://example.org\") }",
            "#$?#div:has-text('), * { background: url('https://example.org') }",
            // A quote between the first `{` and the one ExtendedCss
            // picks at shifts the string pairing, so a scan starts at
            // every `{`.
            "#?#div:has-text({\"), * { background: url(\"https://example.org\") }",
            "#$?#div:has-text({\"), * { background: url(\"https://example.org\") }",
            "##div:has-text({\"), * { background: url(\"https://example.org\") }",
            "example.org#$?#div:has-text(x{y'z), #b1 { background: url(\"https://example.org/v6\") }",
            // Protocol-relative URL.
            "#$?#div:has-text({\"), * { background: url(//example.org/x) }",
            // ExtendedCss pairs the value quotes by its own rule, so a
            // `\\` before a quote makes it pair for the CSS lexer and
            // not for the ExtendedCss tokenizer: the style block scan
            // does not track literals at all.
            #"#?#div { color: "a\\" x"; background: url("https://example.org/x") }"#,
            #"#$?#div { color: "a\\" x"; background: url("https://example.org/x") }"#,
            #"#?#div { color: "a\\" x"; background: url(//example.org/x) }"#,
            // Over-block: url() inside a quoted style value never loads
            // anything, but it is cut by the literal-free style block
            // scan.
            #"#?#div { content: "url(https://example.org)"; color: red }"#,
            // Known over-block: the scan does not track strings and
            // comments, so url( inside them is rejected too.
            #"#$#.banner::before { content: "url(https://example.org)" }"#,
            #"#$#p::before { content: "\" url("; color: red }"#,
            #"#$#.banner { background: /* url(https://example.org) */ red }"#,
            // Over-block since the literal-free scan: the join
            // composition is dead because a rule with the url( text is
            // rejected regardless of strings and comments.
            #"#$#p { content: "*/background: URL(https://example.org); } /*" }"#,
            // Known over-block: an at-rule name inside a string.
            "#$#p::before { content: \"@import url(\" }",
            // Known over-block: url( inside a selector string.
            "#?#a[href*=\"url(\"] { color: red }",
        ]

        for ruleText in forbiddenRules {
            XCTAssertThrowsError(
                try CosmeticRule(ruleText: ruleText),
                "Rule must be rejected: \(ruleText)"
            )
        }

        // Rules that must not be rejected.
        let allowedRules = [
            // Escaped parentheses do not call anything.
            #"#$#.banner { background: url\28 https://example.org\29 }"#,
            // A space before the parenthesis.
            "#$#.banner { background: url (https://example.org) }",
            // A comment breaks the name.
            #"#$#.banner { background: ur/*c*/l(https://example.org) }"#,
            // No literal tracking: unclosed comments are not rejected
            // anymore, and the join composition is dead because a rule
            // with the url( text is rejected outright.
            "#$#body { background: red; /* }",
            // Regular functions and names.
            "#$#.banner { color: rgb(1, 2, 3) }",
            "#$#.banner { width: calc(100% - 10px) }",
            "#$#.banner { color: var(--color) }",
            "#$#.banner { background: linear-gradient(red, blue) }",
            "#$#.banner { content: attr(data-label) }",
            "#$#.banner { background: my-url(test.png) }",
            "#$#.banner { --url: red }",
            "#$#.banner { background: -webkit-cross-fade(linear-gradient(red, blue), linear-gradient(green, yellow), 50%) }",
            // Escaped code points do not break the name.
            #"#$#.banner { background: ur\fffdl(https://example.org) }"#,
            // An escaped `@` does not start an at-rule.
            #"#$#.banner.email\@import { color: red }"#,
            // An escaped newline does not close the string.
            "#$#p::before { content: \"a\\\nurl(https://example.org)\" }",
            // url( inside a string in the selector.
            #"##a[href*="url("] { display: none }"#,
            // @import inside an attribute selector string.
            #"##a[href^="@import"]"#,
            // Form feed outside strings is just a whitespace.
            "#$?#.banner { color: red;\u{0C}border: none }",
            // `{` inside a string argument of the selector does not
            // reject the rule by the style block scan.
            "#$?#div:has-text(\"{x}\") { color: red }",
            // Script rules are not applied by ExtendedCss and must not
            // hit the style block scan.
            "example.org#%#document.querySelectorAll('a:has(img)').forEach(a => { a.href = new URL(a.href).href })",
            // Multiple style blocks, all clean.
            "#$?#a { color: red } b { background: blue }",
            // Plain element hiding rules end up as css-display-none
            // selectors that WebKit discards.
            "##div { background: url(https://example.org) }",
            // Whitelist rules never reach the engine, `FilterRule.init(from:)`
            // throws on them.
            "#@$#.banner { background: URL(test.png) }",
            "#@$?#.banner:has(.child) { background: URL(test.png) }",
            "#@?##div { background: URL(https://example.org) }",
            // Extended rules without a style block get only the fixed
            // display:none!important appended.
            "##div:matches-css(background-image: url(https://example.org))",
            // At-rules are not supported by ExtendedCss, the selector
            // is invalid and the rule is skipped.
            "#?#@import\"https://example.org/x.css\"",
        ]

        for ruleText in allowedRules {
            XCTAssertNoThrow(
                try CosmeticRule(ruleText: ruleText),
                "Rule must not be rejected: \(ruleText)"
            )
        }

        // uBO :style() rules are converted to CSS injection rules, so they
        // must be checked by the conversion result and not by createRule.
        let forbiddenUboRules = RuleFactory.createRules(
            lines: ["example.com##h1:style(background: URL(https://example.org))"],
            for: DEFAULT_SAFARI_VERSION
        )
        XCTAssertTrue(forbiddenUboRules.isEmpty)

        let allowedUboRules = RuleFactory.createRules(
            lines: ["example.com##h1:style(background-color: blue !important)"],
            for: DEFAULT_SAFARI_VERSION
        )
        XCTAssertEqual(allowedUboRules.count, 1)
    }
}
