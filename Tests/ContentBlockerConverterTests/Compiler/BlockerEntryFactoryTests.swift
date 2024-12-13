import Foundation

import XCTest
@testable import ContentBlockerConverter

final class BlockerEntryFactoryTests: XCTestCase {
    func testConvertNetworkRule() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter());

        let rule = try NetworkRule(ruleText: "||example.com/path$domain=test.com")

        let result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.trigger.urlFilter, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.com\\/path")
        XCTAssertEqual(result!.trigger.ifDomain![0], "*test.com")
        XCTAssertEqual(result!.trigger.unlessDomain, nil)
        XCTAssertEqual(result!.trigger.shortcut, nil)
        XCTAssertEqual(result!.trigger.regex, nil)

        XCTAssertEqual(result!.action.type, "block")
        XCTAssertEqual(result!.action.selector, nil)
        XCTAssertEqual(result!.action.css, nil)
        XCTAssertEqual(result!.action.script, nil)
        XCTAssertEqual(result!.action.scriptlet, nil)
        XCTAssertEqual(result!.action.scriptletParam, nil)
    }

    func testConvertNetworkRuleRegExp() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter());

        let rule = try NetworkRule(ruleText: "/regex/$script")
        rule.urlRuleText = "/regex/$script"

        let result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.trigger.urlFilter, "regex")
        XCTAssertEqual(result!.trigger.ifDomain, nil)
        XCTAssertEqual(result!.trigger.unlessDomain, nil)
        XCTAssertEqual(result!.trigger.shortcut, nil)
        XCTAssertEqual(result!.trigger.regex, nil)

        XCTAssertEqual(result!.action.type, "block")
        XCTAssertEqual(result!.action.selector, nil)
        XCTAssertEqual(result!.action.css, nil)
        XCTAssertEqual(result!.action.script, nil)
        XCTAssertEqual(result!.action.scriptlet, nil)
        XCTAssertEqual(result!.action.scriptletParam, nil)
    }

    func testConvertNetworkRulePath() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter())

        let rule = try NetworkRule(ruleText: "/addyn|*|adtech")

        let result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.trigger.urlFilter, #"\/addyn\|.*\|adtech"#)
    }

    func testConvertNetworkRuleWhitelist() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter())

        var rule = try! NetworkRule(ruleText: "@@||example.com^$document")

        var result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.trigger.urlFilter, ".*")
        XCTAssertEqual(result!.trigger.ifDomain![0], "*example.com")
        XCTAssertEqual(result!.trigger.unlessDomain, nil)

        rule = try! NetworkRule(ruleText: "@@||example.com$document")

        result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.trigger.urlFilter, ".*")
        XCTAssertEqual(result!.trigger.ifDomain![0], "*example.com")
        XCTAssertEqual(result!.trigger.unlessDomain, nil)
    }

    func testConvertScriptRule() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "example.org,test.com#%#test");

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain!.count, 2);
        XCTAssertEqual(result!.trigger.unlessDomain, nil);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "script");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, "test");
        XCTAssertEqual(result!.action.scriptlet, nil);
        XCTAssertEqual(result!.action.scriptletParam, nil);
    }

    func testConvertScriptRulesForNonAdvancedBlocking() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter());

        var rule = try! CosmeticRule(ruleText: "example.org#%#test");
        var result = converter.createBlockerEntry(rule: rule);
        XCTAssertNil(result);

        rule = try! CosmeticRule(ruleText: "#%#test");
        result = converter.createBlockerEntry(rule: rule);
        XCTAssertNil(result);

        rule = try! CosmeticRule(ruleText: "example.org#@%#test");
        result = converter.createBlockerEntry(rule: rule);
        XCTAssertNil(result);
    }

    func testConvertScriptRuleWhitelist() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "example.org#@%#test");
        rule.permittedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain!.count, 2);
        XCTAssertEqual(result!.trigger.unlessDomain, nil);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "ignore-previous-rules");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, "test");
        XCTAssertEqual(result!.action.scriptlet, nil);
        XCTAssertEqual(result!.action.scriptletParam, nil);
    }

    func testConvertScriptletRule() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "~example.org#%#//scriptlet(\"test-name\")");

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 1);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "scriptlet");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, nil);
        XCTAssertEqual(result!.action.scriptlet, "test-name");
        XCTAssertEqual(result!.action.scriptletParam, "{\"name\":\"test-name\",\"args\":[]}");
    }

    func testConvertScriptletRuleWhitelist() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "##test");
        rule.isScript = false;
        rule.isScriptlet = true;
        rule.scriptlet = "test scriptlet";
        rule.scriptletParam = "test scriptlet param";
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];
        rule.isWhiteList = true;

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 2);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "ignore-previous-rules");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, nil);
        XCTAssertEqual(result!.action.scriptlet, "test scriptlet");
        XCTAssertEqual(result!.action.scriptletParam, "test scriptlet param");
    }

    func testConvertCssRule() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "##.test_css_selector");
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 2);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "css-display-none");
        XCTAssertEqual(result!.action.selector, ".test_css_selector");
        XCTAssertEqual(result!.action.css, nil);
    }

    func testConvertCssExceptionRule() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "example.com#@##social");

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(result!.trigger.unlessDomain, nil);

        XCTAssertEqual(result!.action.type, "ignore-previous-rules");
        XCTAssertEqual(result!.action.selector, "#social");
        XCTAssertEqual(result!.action.css, nil);
    }

    func testConvertCssRuleExtendedCss() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "##.test_css_selector:has(> .test_selector)");
        rule.isExtendedCss = true;
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 2);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "css-extended");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, ".test_css_selector:has(> .test_selector)");
    }

    func testConvertCssRuleCssInject() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());

        let rule = try! CosmeticRule(ruleText: "example.com#$#.body { overflow: visible!important; }");

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain!, ["*example.com"]);
        XCTAssertNil(result!.trigger.unlessDomain);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "css-inject");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, ".body { overflow: visible!important; }");
    }

    func testConvertInvalidRegexNetworkRule() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter())

        let rule = try NetworkRule(ruleText: "/regex/")

        rule.urlRegExpSource = "regex{0,9}"
        var result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result)

        rule.urlRegExpSource = "regex|test"
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result)

        rule.urlRegExpSource = "test(?!test)"
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result)

        rule.urlRegExpSource = "test\\b"
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result)
    }

    func testConvertInvalidNetworkRule() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter())

        let rule = try NetworkRule(ruleText: "||example.org^$subdocument")

        rule.permittedContentType = [NetworkRule.ContentType.SUBDOCUMENT]
        rule.isCheckThirdParty = true
        rule.isThirdParty = false
        let result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result)
    }

    func testTldDomains() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());
        let rule = createTestRule();

        rule.permittedDomains = ["example.*"];

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertTrue(result!.trigger.ifDomain!.count >= 100);
        XCTAssertTrue(result!.trigger.ifDomain!.contains("*example.com"))
        XCTAssertTrue(result!.trigger.ifDomain!.contains("*example.com.tr"))
    }

    func testDomainsRestrictions() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: true, errorsCounter: ErrorsCounter());
        let rule = createTestRule();

        rule.permittedDomains = ["permitted"];
        rule.restrictedDomains = ["restricted"];

        let result = converter.createBlockerEntry(rule: rule);
        XCTAssertNil(result);
    }

    func testThirdParty() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter())
        let rule = try NetworkRule(ruleText: "||example.org^$third-party")

        rule.isCheckThirdParty = false
        rule.isThirdParty = true

        var result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result!.trigger.loadType)

        rule.isCheckThirdParty = true
        rule.isThirdParty = true
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertEqual(result!.trigger.loadType!.count, 1)
        XCTAssertEqual(result!.trigger.loadType![0], "third-party")

        rule.isCheckThirdParty = true
        rule.isThirdParty = false
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertEqual(result!.trigger.loadType!.count, 1)
        XCTAssertEqual(result!.trigger.loadType![0], "first-party")
    }

    func testMatchCase() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter());
        var rule = try NetworkRule(ruleText: "||example.org^$match-case")
        XCTAssertEqual(rule.isMatchCase, true)

        var result = converter.createBlockerEntry(rule: rule)
        XCTAssertNotNil(result!.trigger.caseSensitive)
        if result!.trigger.caseSensitive != nil {
            XCTAssertTrue(result!.trigger.caseSensitive!)
        }

        rule = try NetworkRule(ruleText: "||example.org^")
        XCTAssertEqual(rule.isMatchCase, false)

        result = converter.createBlockerEntry(rule: rule)
        XCTAssertNil(result!.trigger.caseSensitive)
    }

    func testResourceTypes() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter())
        var rule = try NetworkRule(ruleText: "||example.org^")

        var result = converter.createBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.resourceType);

        rule = try NetworkRule(ruleText: "||example.org^$all")
        XCTAssertEqual(rule.permittedContentType, [NetworkRule.ContentType.ALL])
        XCTAssertEqual(rule.restrictedContentType, [])
        result = converter.createBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.resourceType)

        rule = try NetworkRule(ruleText: "||example.org^$image")
        XCTAssertEqual(rule.permittedContentType, [NetworkRule.ContentType.IMAGE])
        XCTAssertEqual(rule.restrictedContentType, [])
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertEqual(result!.trigger.resourceType, ["image"])

        rule = try NetworkRule(ruleText: "||example.org^$image,font")
        XCTAssertEqual(rule.permittedContentType, [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.FONT])
        XCTAssertEqual(rule.restrictedContentType, [])
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertEqual(result!.trigger.resourceType, ["image", "font"])

        rule = try NetworkRule(ruleText: "||example.org^$image,font,~font")
        XCTAssertEqual(rule.permittedContentType, [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.FONT])
        XCTAssertEqual(rule.restrictedContentType, [NetworkRule.ContentType.FONT])
        result = converter.createBlockerEntry(rule: rule)
        XCTAssertEqual(result!.trigger.resourceType, ["image"])
    }

    private func createTestRule() -> Rule {
        let rule = try! CosmeticRule(ruleText: "example.org#%#test");
        return rule;
    }
}
