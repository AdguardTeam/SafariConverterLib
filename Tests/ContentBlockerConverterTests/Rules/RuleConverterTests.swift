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
    
    func testEmptyAndMp4Modifiers() {
        var exp = "/(pagead2)/$domain=vsetv.com,redirect=nooptext,important";
        var res = ruleConverter.convertRule(rule: "/(pagead2)/$domain=vsetv.com,empty,important");
        XCTAssertEqual(res, [exp]);
        
        exp = "||fastmap33.com^$redirect=nooptext";
        res = ruleConverter.convertRule(rule: "||fastmap33.com^$empty");
        XCTAssertEqual(res, [exp]);
        
        exp = "||anyporn.com/xml^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(rule: "||anyporn.com/xml^$media,mp4");
        XCTAssertEqual(res, [exp]);
        
        exp = "||anyporn.com/xml^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(rule: "||anyporn.com/xml^$media,redirect=noopmp4-1s");
        XCTAssertEqual(res, [exp]);
    }
    
    func testMp4AndMediaModifiers() {
        var exp = "||video.example.org^$redirect=noopmp4-1s,media";
        var res = ruleConverter.convertRule(rule: "||video.example.org^$mp4");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(rule: "||video.example.org^$media,mp4");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$media,redirect=noopmp4-1s,domain=example.org";
        res = ruleConverter.convertRule(rule: "||video.example.org^$media,mp4,domain=example.org");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$redirect=noopmp4-1s,domain=example.org,media";
        res = ruleConverter.convertRule(rule: "||video.example.org^$mp4,domain=example.org,media");
        XCTAssertEqual(res, [exp]);
    }
    
    func testConvertUboScriptTags() {
        var exp = "example.com##^script:some-another-rule(test)";
        var res = ruleConverter.convertRule(rule: "example.com##^script:some-another-rule(test)");
        XCTAssertEqual(res, [exp]);
        
        exp = "example.com$$script[tag-content=\"12313\"]";
        res = ruleConverter.convertRule(rule: "example.com##^script:has-text(12313)");
        XCTAssertEqual(res, [exp]);
        
        res = ruleConverter.convertRule(rule: #"example.com##^script:has-text(===):has-text(/[wW]{16000}/)"#);
        XCTAssertEqual(res, [
            "example.com$$script[tag-content=\"===\"]",
            "example.com##^script:has-text(/[wW]{16000}/)"
        ]);
    }
    
    func testInlineScriptModifier() {
        var exp = "||vcrypt.net^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        var res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-script");
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$frame,domain=example.org,csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(rule: "||vcrypt.net^$frame,inline-script,domain=example.org");
        XCTAssertEqual(res, [exp]);
    }
    
    func testInlineFontModifier() {
        var exp = "||vcrypt.net^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        var res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-font");
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$domain=example.org,csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-font,domain=example.org");
        XCTAssertEqual(res, [exp]);
    }
    
    func testInlineFontAndInlineScriptModifier() {
        var exp = "||vcrypt.net^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:; script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        var res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-font,inline-script");
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$domain=example.org,csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:; script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(rule: "||vcrypt.net^$domain=example.org,inline-font,inline-script");
        XCTAssertEqual(res, [exp]);
    }
    
    func testAllModifierSimple() {
        // test simple rule;
        let rule = "||example.org^$all";
        let res = ruleConverter.convertRule(rule: rule);
        let exp1 = "||example.org^$document";
        let exp2 = "||example.org^$popup";
        let exp3 = "||example.org^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        let exp4 = "||example.org^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";

        XCTAssertEqual(res.count, 4);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
        XCTAssertEqual(res[2], exp3);
        XCTAssertEqual(res[3], exp4);
    }
    
    func testAllModifierComplicated() {
        let rule = "||example.org^$all,important";
        let res = ruleConverter.convertRule(rule: rule);
        let exp1 = "||example.org^$document,important";
        let exp2 = "||example.org^$popup,important";
        let exp3 = "||example.org^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:,important";
        let exp4 = "||example.org^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:,important";

        XCTAssertEqual(res.count, 4);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
        XCTAssertEqual(res[2], exp3);
        XCTAssertEqual(res[3], exp4);
    }
    
    func testBadFilterModifier() {
        let rule = "||example.org/favicon.ico$domain=example.org,empty,important,badfilter";
        let exp = #"||example.org/favicon.ico$domain=example.org,redirect=nooptext,important,badfilter"#;
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res, [exp]);
    }
    
    func testUboCssStyleRule() {
        var exp = "example.com#$#h1 { background-color: blue !important }";
        var res = ruleConverter.convertRule(rule: "example.com##h1:style(background-color: blue !important)");
        XCTAssertEqual(res, [exp]);
        
        exp = "example.com#@$#h1 { background-color: blue !important }";
        res = ruleConverter.convertRule(rule: "example.com#@#h1:style(background-color: blue !important)");
        XCTAssertEqual(res, [exp]);
    }
        
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
        ("testEmptyAndMp4Modifiers", testEmptyAndMp4Modifiers),
        ("testMp4AndMediaModifiers", testMp4AndMediaModifiers),
        ("testConvertUboScriptTags", testConvertUboScriptTags),
        ("testInlineScriptModifier", testInlineScriptModifier),
        ("testInlineFontModifier", testInlineFontModifier),
        ("testInlineFontAndInlineScriptModifier", testInlineFontAndInlineScriptModifier),
        ("testAllModifierSimple", testAllModifierSimple),
        ("testAllModifierComplicated", testAllModifierComplicated),
        ("testUboCssStyleRule", testUboCssStyleRule),
    ]
}
