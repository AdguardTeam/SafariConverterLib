import Foundation

import XCTest
@testable import ContentBlockerConverter

final class NetworkRuleTests: XCTestCase {
    func testSimpleRules() {
        var result = try! NetworkRule(ruleText: "||example.org^");
        
        XCTAssertEqual(result.ruleText, "||example.org^");
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, false);
        XCTAssertEqual(result.isScriptlet, false);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        
        XCTAssertEqual(result.isCspRule, false);
        XCTAssertEqual(result.isWebSocket, false);
        XCTAssertEqual(result.isUrlBlock, false);
        XCTAssertEqual(result.isCssExceptionRule, false);
        XCTAssertEqual(result.urlRuleText, "||example.org^");
        XCTAssertEqual(result.isThirdParty, false);
        XCTAssertEqual(result.isMatchCase, false);
        XCTAssertEqual(result.isBlockPopups, false);
        XCTAssertEqual(result.isReplace, false);
        XCTAssertEqual(result.urlRegExpSource, nil);
        
        XCTAssertEqual(result.permittedContentType, []);
        XCTAssertEqual(result.restrictedContentType, []);
        
        result = try! NetworkRule(ruleText: "||example.org^$third-party");
        XCTAssertEqual(result.isCspRule, false);
        XCTAssertEqual(result.isWebSocket, false);
        XCTAssertEqual(result.isUrlBlock, false);
        XCTAssertEqual(result.isCssExceptionRule, false);
        XCTAssertEqual(result.urlRuleText, "||example.org^$third-party");
        XCTAssertEqual(result.isThirdParty, false);
        XCTAssertEqual(result.isMatchCase, false);
        XCTAssertEqual(result.isBlockPopups, false);
        XCTAssertEqual(result.isReplace, false);
        XCTAssertEqual(result.urlRegExpSource, nil);
        
        XCTAssertEqual(result.permittedContentType, []);
        XCTAssertEqual(result.restrictedContentType, []);
        
        result = try! NetworkRule(ruleText: "@@||example.org^$third-party");
        XCTAssertEqual(result.isWhiteList, true);
        
        result = try! NetworkRule(ruleText: "||example.org/this$is$path$third-party");
        XCTAssertEqual(result.isCspRule, false);
        XCTAssertEqual(result.isWebSocket, false);
        XCTAssertEqual(result.isUrlBlock, false);
        XCTAssertEqual(result.isCssExceptionRule, false);
        XCTAssertEqual(result.urlRuleText, "||example.org/this$is$path$third-party");
        XCTAssertEqual(result.isThirdParty, false);
        XCTAssertEqual(result.isMatchCase, false);
        XCTAssertEqual(result.isBlockPopups, false);
        XCTAssertEqual(result.isReplace, false);
        XCTAssertEqual(result.urlRegExpSource, nil);
        
        XCTAssertEqual(result.permittedContentType, []);
        XCTAssertEqual(result.restrictedContentType, []);
        
        result = try! NetworkRule(ruleText: "||example.org\\$smth");
        XCTAssertEqual(result.isCspRule, false);
        XCTAssertEqual(result.isWebSocket, false);
        XCTAssertEqual(result.isUrlBlock, false);
        XCTAssertEqual(result.isCssExceptionRule, false);
        XCTAssertEqual(result.urlRuleText, "||example.org\\$smth");
        XCTAssertEqual(result.isThirdParty, false);
        XCTAssertEqual(result.isMatchCase, false);
        XCTAssertEqual(result.isBlockPopups, false);
        XCTAssertEqual(result.isReplace, false);
        XCTAssertEqual(result.urlRegExpSource, nil);
        
        XCTAssertEqual(result.permittedContentType, []);
        XCTAssertEqual(result.restrictedContentType, []);
    }
    
    func testRegexRules() {
        var result = try! NetworkRule(ruleText: "/regex/");
        result = try! NetworkRule(ruleText: "@@/regex/");
        result = try! NetworkRule(ruleText: "@@/regex/$third-party");
        result = try! NetworkRule(ruleText: "/regex/$replace=/test/test2/");
        result = try! NetworkRule(ruleText: "/regex/$replace=/test\\$/test2/");
    }
    
    func testParseDomainInfo() {
        
        let rule = NetworkRule();
        
        rule.urlRuleText = "";
        var result = rule.parseRuleDomain();
        XCTAssertNil(result);
        
        rule.urlRuleText = "example.com";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, nil);
        
        rule.urlRuleText = "||example.com";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, nil);
        
        rule.urlRuleText = "||example.com/path";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, "/path");
        
        rule.urlRuleText = "||invalid/path";
        result = rule.parseRuleDomain();
        XCTAssertNil(result);
        
        rule.urlRuleText = "$third-party,domain=example.com";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, nil);
        
        rule.urlRuleText = "||example.com^$document";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, "^");
    }

    static var allTests = [
        ("testParseDomainInfo", testParseDomainInfo),
    ]
}
