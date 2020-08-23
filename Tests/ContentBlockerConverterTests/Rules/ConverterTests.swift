import Foundation

import XCTest
@testable import ContentBlockerConverter

final class ConverterTests: XCTestCase {
    func testConvertScriptRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isScript = true;
        rule.script = "test script";
        rule.permittedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain!.count, 2);
        XCTAssertEqual(result!.trigger.unlessDomain, nil);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "script");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, "test script");
        XCTAssertEqual(result!.action.scriptlet, nil);
        XCTAssertEqual(result!.action.scriptletParam, nil);
    }
    
    func testConvertScriptRuleWhitelist() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isScript = true;
        rule.script = "test script";
        rule.permittedDomains = ["test_domain_one", "test_domain_two"];
        rule.isWhiteList = true;

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain!.count, 2);
        XCTAssertEqual(result!.trigger.unlessDomain, nil);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "ignore-previous-rules");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, "test script");
        XCTAssertEqual(result!.action.scriptlet, nil);
        XCTAssertEqual(result!.action.scriptletParam, nil);
    }
    
    func testConvertScriptletRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isScriptlet = true;
        rule.scriptlet = "test scriptlet";
        rule.scriptletParam = "test scriptlet param";
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 2);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "scriptlet");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, nil);
        XCTAssertEqual(result!.action.scriptlet, "test scriptlet");
        XCTAssertEqual(result!.action.scriptletParam, "test scriptlet param");
    }
    
    func testConvertScriptletRuleWhitelist() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isScriptlet = true;
        rule.scriptlet = "test scriptlet";
        rule.scriptletParam = "test scriptlet param";
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];
        rule.isWhiteList = true;

        let result = converter.convertRuleToBlockerEntry(rule: rule);
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
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.cssSelector = "test_css_selector";
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 2);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "css-display-none");
        XCTAssertEqual(result!.action.selector, "test_css_selector");
        XCTAssertEqual(result!.action.css, nil);
    }
    
    func testConvertCssRuleExtendedCss() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isExtendedCss = true;
        rule.cssSelector = "test_css_selector";
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
        XCTAssertEqual(result!.trigger.ifDomain, nil);
        XCTAssertEqual(result!.trigger.unlessDomain!.count, 2);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "css");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, "test_css_selector");
    }
    
    func testConvertInvalidCssRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isExtendedCss = true;
        rule.cssSelector = "some url(test)";
        rule.restrictedDomains = ["test_domain_one", "test_domain_two"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
    }
    
    func testConvertInvalidRegexNetworkRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = createTestNetworkRule();
        
        // TODO: check invalid regex

//        let result = converter.convertRuleToBlockerEntry(rule: rule);
//        XCTAssertNil(result);
    }
    
    func testConvertInvalidNetworkRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = createTestNetworkRule();
        
        rule.permittedContentType = [NetworkRule.ContentType.SUBDOCUMENT]
        rule.isCheckThirdParty = true;
        rule.isThirdParty = true;
        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
    }
    
    func testTldDomains() {
        let converter = Converter(advancedBlockingEnabled: true);
        let rule = createTestRule();
        
        rule.permittedDomains = [".*"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        XCTAssertTrue(result!.trigger.ifDomain!.count >= 100);
    }
    
    func testDomainsRestrictions() {
        let converter = Converter(advancedBlockingEnabled: true);
        let rule = createTestRule();
        
        rule.permittedDomains = ["permitted"];
        rule.restrictedDomains = ["restricted"];

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
    }
    
    func testThirdParty() {
        let converter = Converter(advancedBlockingEnabled: false);
        let rule = createTestNetworkRule();
        
        rule.isCheckThirdParty = false;
        rule.isThirdParty = true;

        var result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.loadType);
        
        rule.isCheckThirdParty = true;
        rule.isThirdParty = true;
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertEqual(result!.trigger.loadType!.count, 1);
        XCTAssertEqual(result!.trigger.loadType![0], "third-party");
        
        rule.isCheckThirdParty = true;
        rule.isThirdParty = false;
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertEqual(result!.trigger.loadType!.count, 1);
        XCTAssertEqual(result!.trigger.loadType![0], "first-party");
    }
    
    func testMatchCase() {
        let converter = Converter(advancedBlockingEnabled: false);
        let rule = createTestNetworkRule();

        var result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.caseSensitive);
        
        rule.isMatchCase = false;
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.caseSensitive);
        
        rule.isMatchCase = true;
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertEqual(result!.trigger.caseSensitive, true);
    }

    func testResourceTypes() {
        let converter = Converter(advancedBlockingEnabled: false);
        let rule = createTestNetworkRule();

        var result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.resourceType);

        rule.permittedContentType = [NetworkRule.ContentType.ALL];
        rule.restrictedContentType = [];
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result!.trigger.resourceType);

        rule.permittedContentType = [NetworkRule.ContentType.IMAGE];
        rule.restrictedContentType = [];
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertEqual(result!.trigger.resourceType, ["image"]);
        
        rule.permittedContentType = [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.FONT];
        rule.restrictedContentType = [];
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertEqual(result!.trigger.resourceType, ["image", "font"]);
        
        rule.permittedContentType = [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.FONT];
        rule.restrictedContentType = [NetworkRule.ContentType.FONT];
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertEqual(result!.trigger.resourceType, ["image"]);
    }
    
    func testInvalidResourceTypes() {
        let converter = Converter(advancedBlockingEnabled: false);
        let rule = createTestNetworkRule();

        rule.permittedContentType = [NetworkRule.ContentType.OBJECT];
        var result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
        
        rule.permittedContentType = [NetworkRule.ContentType.OBJECT_SUBREQUEST];
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
        
        rule.permittedContentType = [NetworkRule.ContentType.WEBRTC];
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
        
        rule.permittedContentType = [NetworkRule.ContentType.IMAGE];
        rule.isReplace = true;
        result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNil(result);
    }
    
    // TODO: Add whitelist proper test
    
    private func createTestRule() -> Rule {
        let rule = CosmeticRule();
        
        rule.isScript = true;
        rule.script = "test script";
        
        return rule;
    }
    
    private func createTestNetworkRule() -> NetworkRule {
        let rule = NetworkRule();
        
        return rule;
    }
    
    static var allTests = [
        ("testConvertScriptRule", testConvertScriptRule),
        ("testConvertScriptRuleWhitelist", testConvertScriptRuleWhitelist),
        ("testConvertScriptletRule", testConvertScriptletRule),
        ("testConvertScriptletRuleWhitelist", testConvertScriptletRuleWhitelist),
        ("testConvertCssRule", testConvertCssRule),
        ("testConvertCssRuleExtendedCss", testConvertCssRuleExtendedCss),
        ("testConvertInvalidCssRule", testConvertInvalidCssRule),
        ("testConvertInvalidNetworkRule", testConvertInvalidNetworkRule),
        ("testConvertInvalidRegexNetworkRule", testConvertInvalidRegexNetworkRule),
        ("testTldDomains", testTldDomains),
        ("testDomainsRestrictions", testDomainsRestrictions),
        ("testThirdParty", testThirdParty),
        ("testMatchCase", testMatchCase),
        ("testResourceTypes", testResourceTypes),
    ]
}
