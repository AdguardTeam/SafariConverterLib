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
        XCTAssertEqual(result.urlRegExpSource, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$");
        
        XCTAssertEqual(result.permittedContentType, [NetworkRule.ContentType.ALL]);
        XCTAssertEqual(result.restrictedContentType, []);
        
        result = try! NetworkRule(ruleText: "||example.org^$third-party");
        XCTAssertEqual(result.urlRuleText, "||example.org^");
        XCTAssertEqual(result.isCheckThirdParty, true);
        XCTAssertEqual(result.isThirdParty, true);
        
        result = try! NetworkRule(ruleText: "@@||example.org^$third-party");
        XCTAssertEqual(result.isWhiteList, true);
        
        result = try! NetworkRule(ruleText: "||example.org/this$is$path$image,font,media");
        XCTAssertEqual(result.urlRuleText, "||example.org/this$is$path");
        
        XCTAssertEqual(result.permittedContentType, [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.FONT, NetworkRule.ContentType.MEDIA]);
        XCTAssertEqual(result.restrictedContentType, []);
        
        result = try! NetworkRule(ruleText: "||example.org\\$smth");
        XCTAssertEqual(result.urlRuleText, "||example.org\\$smth");
    }
    
    func testDomains() {
        let result = try! NetworkRule(ruleText: "||example.org^$domain=example.org|~sub.example.org");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.permittedDomains, ["example.org"]);
        XCTAssertEqual(result.restrictedDomains, ["sub.example.org"]);
    }
    
    func testRegexRules() {
        var result = try! NetworkRule(ruleText: "/regex/");
        XCTAssertEqual(result.urlRuleText, "/regex/");
        XCTAssertEqual(result.urlRegExpSource, "regex");
        
        result = try! NetworkRule(ruleText: "@@/regex/");
        XCTAssertEqual(result.urlRuleText, "/regex/");
        XCTAssertEqual(result.urlRegExpSource, "regex");
        
        result = try! NetworkRule(ruleText: "@@/regex/$third-party");
        XCTAssertEqual(result.urlRuleText, "/regex/");
        XCTAssertEqual(result.urlRegExpSource, "regex");
        
        result = try! NetworkRule(ruleText: "/regex/$replace=/test/test2/");
        XCTAssertEqual(result.urlRuleText, "/regex/");
        XCTAssertEqual(result.urlRegExpSource, "regex");
        XCTAssertEqual(result.isReplace, true);
        
        result = try! NetworkRule(ruleText: "/regex/$replace=/test\\$/test2/");
        XCTAssertEqual(result.urlRuleText, "/regex/");
        XCTAssertEqual(result.urlRegExpSource, "regex");
        
        result = try! NetworkRule(ruleText: "/example{/");
        XCTAssertEqual(result.urlRuleText, "/example{/");
        XCTAssertEqual(result.urlRegExpSource, "example{");
        
        result = try! NetworkRule(ruleText: #"/^http:\/\/example\.org\/$/"#);
        XCTAssertEqual(result.urlRuleText, #"/^http:\/\/example\.org\/$/"#);
        XCTAssertEqual(result.urlRegExpSource, #"^http:\/\/example\.org\/$"#);
    }
    
    func testUrlSlashRules() {
        let result = try! NetworkRule(ruleText: "/addyn|*|adtech");
        XCTAssertEqual(result.urlRuleText, "/addyn|*|adtech");
        XCTAssertEqual(result.urlRegExpSource, #"\/addyn\|.*\|adtech"#);
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
        ("testSimpleRules", testSimpleRules),
        ("testDomains", testDomains),
        ("testRegexRules", testRegexRules),
        ("testUrlSlashRules", testUrlSlashRules),
        ("testParseDomainInfo", testParseDomainInfo),
    ]
}
