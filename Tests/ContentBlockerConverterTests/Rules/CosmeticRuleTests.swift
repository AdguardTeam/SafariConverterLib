import Foundation

import XCTest
@testable import ContentBlockerConverter

final class CosmeticRuleTests: XCTestCase {
    func testElemhidingRules() {
        
        var result = try! CosmeticRule(ruleText: "##.banner");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.ruleText, "##.banner");
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, false);
        XCTAssertEqual(result.isScriptlet, false);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        
        
        XCTAssertEqual(result.content, ".banner");
        XCTAssertEqual(result.scriptlet, nil);
        XCTAssertEqual(result.scriptletParam, nil);
        
        XCTAssertEqual(result.isExtendedCss, false);
        XCTAssertEqual(result.isInjectCss, false);
        
        result = try! CosmeticRule(ruleText: "*##.banner");
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, false);
        XCTAssertEqual(result.isScriptlet, false);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        
        
        XCTAssertEqual(result.content, ".banner");
        XCTAssertEqual(result.scriptlet, nil);
        XCTAssertEqual(result.scriptletParam, nil);
        
        XCTAssertEqual(result.isExtendedCss, false);
        XCTAssertEqual(result.isInjectCss, false);
    }
    
    func testElemhidingRulesWhitelist() {
        
        var result = try! CosmeticRule(ruleText: "example.org#@#.banner");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        XCTAssertEqual(result.content, ".banner");
        
        result = try! CosmeticRule(ruleText: "example.org#@##banner");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        XCTAssertEqual(result.content, "#banner");
        
        result = try! CosmeticRule(ruleText: "*#@#.banner");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.content, ".banner");
    }
    
    func testCssRules() {
        
        var result = try! CosmeticRule(ruleText: "example.org#$#.textad { visibility: hidden; }");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, false);
        XCTAssertEqual(result.isScriptlet, false);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, ["example.org"]);
        XCTAssertEqual(result.restrictedDomains, []);
        
        
        XCTAssertEqual(result.content, ".textad { visibility: hidden; }");
        XCTAssertEqual(result.scriptlet, nil);
        XCTAssertEqual(result.scriptletParam, nil);
        
        XCTAssertEqual(result.isExtendedCss, false);
        XCTAssertEqual(result.isInjectCss, true);
        
        result = try! CosmeticRule(ruleText: "*#$#.textad { visibility: hidden; }");
        
        XCTAssertEqual(result.isInjectCss, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.content, ".textad { visibility: hidden; }");
    }
    
    func testCssRulesWhitelist() {
        
        var result = try! CosmeticRule(ruleText: "example.com#@$?#h3:contains(cookies) { display: none!important; }");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        
        result = try! CosmeticRule(ruleText: "*#@$?#h3:contains(cookies) { display: none!important; }");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.isInjectCss, true);
        XCTAssertEqual(result.content, "h3:contains(cookies) { display: none!important; }");
    }
    
    func testExtendedCssRules() {
        
        let result = try! CosmeticRule(ruleText: "example.org##.sponsored[-ext-contains=test]");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, false);
        XCTAssertEqual(result.isScriptlet, false);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, ["example.org"]);
        XCTAssertEqual(result.restrictedDomains, []);
        
        
        XCTAssertEqual(result.content, ".sponsored[-ext-contains=test]");
        XCTAssertEqual(result.scriptlet, nil);
        XCTAssertEqual(result.scriptletParam, nil);
        
        XCTAssertEqual(result.isExtendedCss, true);
        XCTAssertEqual(result.isInjectCss, false);
    }
    
    func testScriptRules() {
        
        var result = try! CosmeticRule(ruleText: "example.org#%#test");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, true);
        XCTAssertEqual(result.isScriptlet, false);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, ["example.org"]);
        XCTAssertEqual(result.restrictedDomains, []);
        
        
        XCTAssertEqual(result.content, "test");
        XCTAssertEqual(result.scriptlet, nil);
        XCTAssertEqual(result.scriptletParam, nil);
        
        XCTAssertEqual(result.isExtendedCss, false);
        XCTAssertEqual(result.isInjectCss, false);
        
        result = try! CosmeticRule(ruleText: "*#%#test");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isScript, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.content, "test");
    }
    
    func testScriptRulesWhitelist() {
        
        var result = try! CosmeticRule(ruleText: "example.org#@%#test");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        
        result = try! CosmeticRule(ruleText: "*#@%#test");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isScript, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.isWhiteList, true);
    }
    
    func testScriptletRules() {
        
        var result = try! CosmeticRule(ruleText: "example.org#%#//scriptlet(\"set-constant\", \"test\", \"true\")");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, false);
        XCTAssertEqual(result.isImportant, false);
        XCTAssertEqual(result.isScript, true);
        XCTAssertEqual(result.isScriptlet, true);
        XCTAssertEqual(result.isDocumentWhiteList, false);
        
        XCTAssertEqual(result.permittedDomains, ["example.org"]);
        XCTAssertEqual(result.restrictedDomains, []);
        
        XCTAssertEqual(result.content, "//scriptlet(\"set-constant\", \"test\", \"true\")");
        XCTAssertEqual(result.scriptlet, "set-constant");
        XCTAssertEqual(result.scriptletParam, "{\"name\":\"set-constant\",\"args\":[\"test\",\"true\"]}");
        
        XCTAssertEqual(result.isExtendedCss, false);
        XCTAssertEqual(result.isInjectCss, false);
        
        result = try! CosmeticRule(ruleText: "*#%#//scriptlet(\"set-constant\", \"test\", \"true\")");
        
        XCTAssertEqual(result.isScriptlet, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.content, "//scriptlet(\"set-constant\", \"test\", \"true\")");
    }
    
    func testScriptletRulesWhitelist() {
        
        var result = try! CosmeticRule(ruleText: "example.org#@%#//scriptlet(\"set-constant\", \"test\", \"true\")");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isWhiteList, true);
        
        result = try! CosmeticRule(ruleText: "*#@%#//scriptlet(\"set-constant\", \"test\", \"true\")");
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.isScriptlet, true);
        XCTAssertEqual(result.permittedDomains, []);
        XCTAssertEqual(result.restrictedDomains, []);
        XCTAssertEqual(result.isWhiteList, true);
    }
    
    func testDomains() {
        
        let result = try! CosmeticRule(ruleText: "example.org,~sub.example.org##banner");
        
        XCTAssertNotNil(result);
        
        XCTAssertEqual(result.permittedDomains, ["example.org"]);
        XCTAssertEqual(result.restrictedDomains, ["sub.example.org"]);
    }
    
    static var allTests = [
        ("testElemhidingRules", testElemhidingRules),
        ("testElemhidingRulesWhitelist", testElemhidingRulesWhitelist),
        ("testCssRules", testCssRules),
        ("testCssRulesWhitelist", testCssRulesWhitelist),
        ("testExtendedCssRules", testExtendedCssRules),
        ("testScriptRules", testScriptRules),
        ("testScriptRulesWhitelist", testScriptRulesWhitelist),
        ("testScriptletRules", testScriptletRules),
        ("testScriptletRulesWhitelist", testScriptletRulesWhitelist),
        ("testDomains", testDomains),
    ]
}

