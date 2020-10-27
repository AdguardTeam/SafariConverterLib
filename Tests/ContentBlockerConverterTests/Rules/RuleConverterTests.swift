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
        let rule: NSString = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')";
        let exp: NSString = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAGRuleException() {
        let rule: NSString = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')";
        let exp: NSString = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRule() {
        let rule: NSString = "example.org##+js(setTimeout-defuser.js, [native code], 8000)";
        let exp: NSString = "example.org#%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRuleCommas() {
        var rule: NSString = "si.com##+js(aeld, scroll, function(e){u(n(e,1,a))})";
        var exp: NSString = #"si.com#%#//scriptlet("ubo-aeld", "scroll", "function(e){u(n(e,1,a))}")"#;
        
        var res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
        
        rule = "example.org##+js(aopr,__cad.cpm_popunder)";
        exp = #"example.org#%#//scriptlet("ubo-aopr", "__cad.cpm_popunder")"#;
        
        res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
        
        rule = "example.org##+js(acis,setTimeout,testad)";
        exp = #"example.org#%#//scriptlet("ubo-acis", "setTimeout", "testad")"#;
        
        res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRuleException() {
        let rule: NSString = "example.org#@#+js(setTimeout-defuser.js, [native code], 8000)";
        let exp: NSString = "example.org#@%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")";
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAbpRule() {
        let rule: NSString = "example.org#$#hide-if-contains li.serp-item 'li.serp-item div.label'";
        let exp: NSString = #"example.org#%#//scriptlet("abp-hide-if-contains", "li.serp-item", "li.serp-item div.label")"#;
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAbpRuleMultiple() {
        let rule: NSString = #"example.org#$#hide-if-has-and-matches-style 'd[id^="_"]' 'div > s' 'display: none'; hide-if-contains /.*/ .p 'a[href^="/ad__c?"]'"#;
        let exp1: NSString = #"example.org#%#//scriptlet("abp-hide-if-has-and-matches-style", "d[id^=\"_\"]", "div > s", "display: none")"#;
        let exp2: NSString = #"example.org#%#//scriptlet("abp-hide-if-contains", "/.*/", ".p", "a[href^=\"/ad__c?\"]")"#;
        
        let res = ruleConverter.convertRule(rule: rule);

        XCTAssertEqual(res.count, 2);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
    }
    
    func testConvertCssAGRules() {
        let rule: NSString = "firmgoogle.com#$#.pub_300x250 {display:block!important;}";
        let exp: NSString = "firmgoogle.com#$#.pub_300x250 {display:block!important;}";
        let res = ruleConverter.convertRule(rule: rule);

        XCTAssertEqual(res, [exp]);

        let whitelistCssRule: NSString = "example.com#@$#h1 { display: none!important; }";
        let expected: NSString = "example.com#@$#h1 { display: none!important; }";
        let actual = ruleConverter.convertRule(rule: whitelistCssRule);
        
        XCTAssertEqual(actual, [expected]);
    }
    
    func testConvertAbpRewrite() {
        var exp: NSString = "||e9377f.com^$redirect=blank-mp3,domain=eastday.com";
        var res = ruleConverter.convertRule(rule: "||e9377f.com^$rewrite=abp-resource:blank-mp3,domain=eastday.com" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||lcok.net/2019/ad/$domain=huaren.tv,redirect=blank-mp3";
        res = ruleConverter.convertRule(rule: "||lcok.net/2019/ad/$domain=huaren.tv,rewrite=abp-resource:blank-mp3"  as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||lcok.net/2019/ad/$domain=huaren.tv";
        res = ruleConverter.convertRule(rule: "||lcok.net/2019/ad/$domain=huaren.tv"  as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testEmptyAndMp4Modifiers() {
        var exp: NSString = "/(pagead2)/$domain=vsetv.com,redirect=nooptext,important";
        var res = ruleConverter.convertRule(rule: "/(pagead2)/$domain=vsetv.com,empty,important" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||fastmap33.com^$redirect=nooptext";
        res = ruleConverter.convertRule(rule: "||fastmap33.com^$empty" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||anyporn.com/xml^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(rule: "||anyporn.com/xml^$media,mp4" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||anyporn.com/xml^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(rule: "||anyporn.com/xml^$media,redirect=noopmp4-1s" as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testMp4AndMediaModifiers() {
        var exp = "||video.example.org^$redirect=noopmp4-1s,media"  as NSString;
        var res = ruleConverter.convertRule(rule: "||video.example.org^$mp4" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(rule: "||video.example.org^$media,mp4" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$media,redirect=noopmp4-1s,domain=example.org";
        res = ruleConverter.convertRule(rule: "||video.example.org^$media,mp4,domain=example.org" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$redirect=noopmp4-1s,domain=example.org,media";
        res = ruleConverter.convertRule(rule: "||video.example.org^$mp4,domain=example.org,media" as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testUboThirdPartyModifiers() {
        var exp = "||video.example.org^$third-party,match-case"  as NSString;
        var res = ruleConverter.convertRule(rule: "||video.example.org^$3p,match-case" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$match-case,third-party";
        res = ruleConverter.convertRule(rule: "||video.example.org^$match-case,3p" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$first-party";
        res = ruleConverter.convertRule(rule: "||video.example.org^$1p" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$first-party";
        res = ruleConverter.convertRule(rule: "||video.example.org^$first-party" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$match-case,third-party,redirect=noopmp4-1s,media";
        res = ruleConverter.convertRule(rule: "||video.example.org^$match-case,3p,mp4" as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testConvertUboScriptTags() {
        var exp = "example.com##^script:some-another-rule(test)" as NSString;
        var res = ruleConverter.convertRule(rule: "example.com##^script:some-another-rule(test)" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "example.com$$script[tag-content=\"12313\"]";
        res = ruleConverter.convertRule(rule: "example.com##^script:has-text(12313)" as NSString);
        XCTAssertEqual(res, [exp]);
        
        res = ruleConverter.convertRule(rule: #"example.com##^script:has-text(===):has-text(/[wW]{16000}/)"# as NSString);
        XCTAssertEqual(res, [
            "example.com$$script[tag-content=\"===\"]",
            "example.com##^script:has-text(/[wW]{16000}/)"
        ]);
    }
    
    func testInlineScriptModifier() {
        var exp = "||vcrypt.net^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:" as NSString;
        var res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-script" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$frame,domain=example.org,csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(rule: "||vcrypt.net^$frame,inline-script,domain=example.org" as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testInlineFontModifier() {
        var exp = "||vcrypt.net^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:"  as NSString;
        var res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-font"  as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$domain=example.org,csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-font,domain=example.org" as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testInlineFontAndInlineScriptModifier() {
        var exp = "||vcrypt.net^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:; script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:" as NSString;
        var res = ruleConverter.convertRule(rule: "||vcrypt.net^$inline-font,inline-script" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$domain=example.org,csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:; script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(rule: "||vcrypt.net^$domain=example.org,inline-font,inline-script" as NSString);
        XCTAssertEqual(res, [exp]);
    }
    
    func testAllModifierSimple() {
        // test simple rule;
        let rule = "||example.org^$all" as NSString;
        let res = ruleConverter.convertRule(rule: rule);
        let exp1 = "||example.org^$document" as NSString;
        let exp2 = "||example.org^$popup" as NSString;
        let exp3 = "||example.org^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:" as NSString;
        let exp4 = "||example.org^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:" as NSString;

        XCTAssertEqual(res.count, 4);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
        XCTAssertEqual(res[2], exp3);
        XCTAssertEqual(res[3], exp4);
    }
    
    func testAllModifierComplicated() {
        let rule = "||example.org^$all,important" as NSString;
        let res = ruleConverter.convertRule(rule: rule);
        let exp1 = "||example.org^$document,important" as NSString;
        let exp2 = "||example.org^$popup,important" as NSString;
        let exp3 = "||example.org^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:,important" as NSString;
        let exp4 = "||example.org^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:,important" as NSString;

        XCTAssertEqual(res.count, 4);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
        XCTAssertEqual(res[2], exp3);
        XCTAssertEqual(res[3], exp4);
    }
    
    func testBadFilterModifier() {
        let rule = "||example.org/favicon.ico$domain=example.org,empty,important,badfilter" as NSString;
        let exp = #"||example.org/favicon.ico$domain=example.org,redirect=nooptext,important,badfilter"# as NSString;
        
        let res = ruleConverter.convertRule(rule: rule);
        XCTAssertEqual(res, [exp]);
    }
    
    func testUboCssStyleRule() {
        var exp = "example.com#$#h1 { background-color: blue !important }" as NSString;
        var res = ruleConverter.convertRule(rule: "example.com##h1:style(background-color: blue !important)" as NSString);
        XCTAssertEqual(res, [exp]);
        
        exp = "example.com#@$#h1 { background-color: blue !important }";
        res = ruleConverter.convertRule(rule: "example.com#@#h1:style(background-color: blue !important)" as NSString);
        XCTAssertEqual(res, [exp]);
    }
        
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testComment", testComment),
        ("testScriptletAGRule", testScriptletAGRule),
        ("testScriptletAGRuleException", testScriptletAGRuleException),
        ("testScriptletUboRule", testScriptletUboRule),
        ("testScriptletUboRuleCommas", testScriptletUboRuleCommas),
        ("testScriptletUboRuleException", testScriptletUboRuleException),
        ("testScriptletAbpRule", testScriptletAbpRule),
        ("testScriptletAbpRuleMultiple", testScriptletAbpRuleMultiple),
        ("testConvertCssAGRules", testConvertCssAGRules),
        ("testEmptyAndMp4Modifiers", testEmptyAndMp4Modifiers),
        ("testMp4AndMediaModifiers", testMp4AndMediaModifiers),
        ("testUboThirdPartyModifiers", testUboThirdPartyModifiers),
        ("testConvertUboScriptTags", testConvertUboScriptTags),
        ("testInlineScriptModifier", testInlineScriptModifier),
        ("testInlineFontModifier", testInlineFontModifier),
        ("testInlineFontAndInlineScriptModifier", testInlineFontAndInlineScriptModifier),
        ("testAllModifierSimple", testAllModifierSimple),
        ("testAllModifierComplicated", testAllModifierComplicated),
        ("testUboCssStyleRule", testUboCssStyleRule),
    ]
}
