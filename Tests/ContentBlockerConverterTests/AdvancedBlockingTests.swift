import XCTest
@testable import ContentBlockerConverter

// TODO(ameshkov): !!! Rename
final class AdvancedBlockingTests: XCTestCase {
    let URL_FILTER_ANY_URL = "^[htpsw]+:\\/\\/";
    let URL_FILTER_REGEXP_START_URL = "^[htpsw]+:\\\\/\\\\/([a-z0-9-]+\\\\.)?";

    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?";
    let URL_FILTER_WS_ANY_URL_UNESCAPED = "^wss?:\\/\\/";
    let URL_FILTER_REGEXP_SEPARATOR = "([\\/:&\\?].*)?$";
    let URL_FILTER_CSS_RULES = ".*";
    let URL_FILTER_URL_RULES_EXCEPTIONS = ".*";

    let converter = ContentBlockerConverter();

    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let decoder = JSONDecoder();
        let parsedData = try decoder.decode([BlockerEntry].self, from: data);

        return parsedData;
    }

    func testAdvancedBlockingText() {
        let networkRule = "||example.org^"
        let cssRule = "example.com##div.textad";
        let injectCssRule = "example.org#$#.div { background:none!important; }";
        let extendedCssRule = "example.org#?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedInjectCssRule = "example.com#$?#h3:contains(cookies) { display: none!important; }"
        let scriptRule = "example.org#%#window.__gaq = undefined;"
        let scriptletRule = "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")"

        let simpleRules = [
            cssRule,
            networkRule,
        ]

        let advancedRules = [
            injectCssRule,
            extendedCssRule,
            extendedInjectCssRule,
            scriptRule,
            scriptletRule
        ]

        let rules = simpleRules + advancedRules

        let result = converter.convertArray(
                rules: rules,
                advancedBlocking: true
        )

        XCTAssertEqual(result.convertedCount, simpleRules.count)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0)
        XCTAssertEqual(result.advancedBlockingText, advancedRules.joined(separator: "\n"))
    }

    func testAdvancedBlockingParamFalse() {
        var result = converter.convertArray(
                rules: ["example.org#$#.content { margin-top: 0!important; }"],
                advancedBlocking: false
        )
        XCTAssertEqual(result.convertedCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0)
        XCTAssertEqual(result.advancedBlockingText, nil)
    }

    func testAdvancedBlockingTextWithAllowlistRules() {
        let allowlistRule = "@@||example.org^$document"
        let injectCssRule = "example.org#$#.div { background:none!important; }";
        let injectCssRuleAllowlist = "example.org#@$#.div { background:none!important; }";
        let extendedCssRule = "example.org#?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedCssRuleAllowlist = "example.org#@?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedInjectCssRule = "example.com#$?#h3:contains(cookies) { display: none!important; }"
        let extendedInjectCssRuleAllowlist = "example.com#@$?#h3:contains(cookies) { display: none!important; }"
        let scriptRule = "example.org#%#window.__gaq = undefined;"
        let scriptRuleAllowlist = "example.org#@%#window.__gaq = undefined;"
        let scriptletRule = "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")"

        let rules = [
            injectCssRule,
            injectCssRuleAllowlist,
            extendedCssRule,
            extendedCssRuleAllowlist,
            extendedInjectCssRule,
            extendedInjectCssRuleAllowlist,
            scriptRule,
            scriptRuleAllowlist,
            scriptletRule
        ]

        let result = converter.convertArray(
            // conjunct arrays in this way,
            // because createRules method adds allowlist rules to the end of the list
            rules: rules + [allowlistRule],
            advancedBlocking: true
        )

        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.convertedCount, 1)
        XCTAssertEqual(result.totalConvertedCount, 1)
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0)
        // conjunct arrays in this way,
        // because createRules method adds allowlist rules to the end of the list
        XCTAssertEqual(result.advancedBlockingText, (rules + [allowlistRule]).joined(separator: "\n"))
    }

    func testAdvancedBlockingTextWithExceptionModifiers() {
        let injectCssRule = "example.org#$#.div { background:none!important; }"
        let extendedCssRule = "example.org#?#div:has(> a[target=\"_blank\"][rel=\"nofollow\"])"
        let extendedInjectCssRule = "example.com#$?#h3:contains(cookies) { display: none!important; }"
        let scriptRule = "example.org#%#window.__gaq = undefined;"
        let scriptletRule = "example.org#%#//scriptlet(\"abort-on-property-read\", \"alert\")"
        // Rules with exception modifiers
        let elemhideAllowlistRule = "@@||example.org^$elemhide"
        let generichideAllowlistRule = "@@||example.org^$generichide"
        let jsinjectAllowlistRule = "@@||example.org^$jsinject"

        let rules = [
            injectCssRule,
            extendedCssRule,
            extendedInjectCssRule,
            scriptRule,
            scriptletRule,
            elemhideAllowlistRule,
            generichideAllowlistRule,
            jsinjectAllowlistRule,
        ]

        let result = converter.convertArray(
            // conjunct arrays in this way,
            // because createRules method adds allowlist rules to the end of the list
            rules: rules,
            advancedBlocking: true
        )

        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.advancedBlockingConvertedCount, 0)
        // conjunct arrays in this way,
        // because createRules method adds allowlist rules to the end of the list
        XCTAssertEqual(result.advancedBlockingText, (rules).joined(separator: "\n"))
    }
}
