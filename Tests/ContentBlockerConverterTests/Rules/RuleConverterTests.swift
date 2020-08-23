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
    
    // TODO: Add more tests
//    QUnit.test('Test converter scriptlet abp rule', (assert) => {
//        const rule = "example.org#$#hide-if-contains li.serp-item 'li.serp-item div.label'";
//        const exp = 'example.org#%#//scriptlet("abp-hide-if-contains", "li.serp-item", "li.serp-item div.label")';
//        const res = adguard.rules.ruleConverter.convertRule(rule);
//        assert.equal(res, exp);
//    });

//    QUnit.test('Test converter scriptlet multiple abp rule', (assert) => {
//        const rule = 'example.org#$#hide-if-has-and-matches-style \'d[id^="_"]\' \'div > s\' \'display: none\'; hide-if-contains /.*/ .p \'a[href^="/ad__c?"]\'';
//        const exp1 = 'example.org#%#//scriptlet("abp-hide-if-has-and-matches-style", "d[id^=\\"_\\"]", "div > s", "display: none")';
//        const exp2 = 'example.org#%#//scriptlet("abp-hide-if-contains", "/.*/", ".p", "a[href^=\\"/ad__c?\\"]")';
//        const res = adguard.rules.ruleConverter.convertRule(rule);
//
//        assert.equal(res.length, 2);
//        assert.equal(res[0], exp1);
//        assert.equal(res[1], exp2);
//    });

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testComment", testComment),
        ("testScriptletAGRule", testScriptletAGRule),
        ("testScriptletAGRuleException", testScriptletAGRuleException),
        ("testScriptletUboRule", testScriptletUboRule),
    ]
}
