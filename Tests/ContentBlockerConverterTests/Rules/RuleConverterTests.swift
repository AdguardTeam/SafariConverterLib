import XCTest
@testable import ContentBlockerConverter

final class RuleConverterTests: XCTestCase {
    let ruleConverter = RuleConverter();
    
    func testEmpty() {
        let result = ruleConverter.convertRule(rule: "");
        XCTAssertEqual(result[0], "");
    }
    
    func testComment() {
        let result = ruleConverter.convertRule(rule: "! comment");
        XCTAssertEqual(result[0], "! comment");
    }
    
    func testScriptletAGRule() {
        let rule = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')";
        let exp = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAGRuleException() {
        let rule = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')";
        let exp = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRule() {
        let rule = "example.org##+js(setTimeout-defuser.js, [native code], 8000)";
        let exp = "example.org#%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRuleException() {
        let rule = "example.org#@#+js(setTimeout-defuser.js, [native code], 8000)";
        let exp = "example.org#@%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAbpRule() {
        let rule = "example.org#$#hide-if-contains li.serp-item 'li.serp-item div.label'";
        let exp = #"example.org#%#//scriptlet("abp-hide-if-contains", "li.serp-item", "li.serp-item div.label")"#;
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAbpRuleMultiple() {
        let rule = #"example.org#$#hide-if-has-and-matches-style 'd[id^="_"]' 'div > s' 'display: none'; hide-if-contains /.*/ .p 'a[href^="/ad__c?"]'"#;
        let exp1 = #"example.org#%#//scriptlet("abp-hide-if-has-and-matches-style", "d[id^=\"_\"]", "div > s", "display: none")"#;
        let exp2 = #"example.org#%#//scriptlet("abp-hide-if-contains", "/.*/", ".p", "a[href^=\"/ad__c?\"]")"#;
        
        let res = ruleConverter.convertRule(rule: rule);

        XCTAssertEqual(res.count, 2);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
    }
    
    func testConvertCssAGRules() {
        let rule = "firmgoogle.com#$#.pub_300x250 {display:block!important;}";
        let exp = "firmgoogle.com#$#.pub_300x250 {display:block!important;}";
        let res = ruleConverter.convertRule(rule: rule);

        XCTAssertEqual(res, [exp]);

        let whitelistCssRule = "example.com#@$#h1 { display: none!important; }";
        let expected = "example.com#@$#h1 { display: none!important; }";
        let actual = ruleConverter.convertRule(rule: whitelistCssRule);
        
        XCTAssertEqual(actual, [expected]);
    }
    
    func testConvertAbpRewrite() {
        var exp = "||e9377f.com^$redirect=blank-mp3,domain=eastday.com";
        var res = ruleConverter.convertRule(rule: "||e9377f.com^$rewrite=abp-resource:blank-mp3,domain=eastday.com");
        XCTAssertEqual(res, [exp]);
        
        exp = "||lcok.net/2019/ad/$domain=huaren.tv,redirect=blank-mp3";
        res = ruleConverter.convertRule(rule: "||lcok.net/2019/ad/$domain=huaren.tv,rewrite=abp-resource:blank-mp3");
        XCTAssertEqual(res, [exp]);
        
        exp = "||lcok.net/2019/ad/$domain=huaren.tv";
        res = ruleConverter.convertRule(rule: "||lcok.net/2019/ad/$domain=huaren.tv");
        XCTAssertEqual(res, [exp]);
    }
    
    // TODO: More tests
    
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testComment", testComment),
        ("testScriptletAGRule", testScriptletAGRule),
        ("testScriptletAGRuleException", testScriptletAGRuleException),
        ("testScriptletUboRule", testScriptletUboRule),
        ("testScriptletUboRuleException", testScriptletUboRuleException),
        ("testScriptletAbpRule", testScriptletAbpRule),
        ("testScriptletAbpRuleMultiple", testScriptletAbpRuleMultiple),
        ("testConvertCssAGRules", testConvertCssAGRules),
        
    ]
}
