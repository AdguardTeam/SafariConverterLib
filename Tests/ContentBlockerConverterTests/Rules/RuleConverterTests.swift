import XCTest
@testable import ContentBlockerConverter

final class RuleConverterTests: XCTestCase {
    let ruleConverter = RuleConverter();
    
    func testEmpty() {
        let result = ruleConverter.convertRule(ruleText: "");
        XCTAssertEqual(result[0], "");
    }
    
    func testComment() {
        let result = ruleConverter.convertRule(ruleText: "! comment");
        XCTAssertEqual(result[0], "! comment");
    }
    
    func testScriptletAGRule() {
        let rule = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')";
        let exp = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')";
        
        let res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAGRuleException() {
        let rule = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')";
        let exp = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')";
        
        let res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRule() {
        let rule = "example.org##+js(setTimeout-defuser.js, [native code], 8000)";
        let exp = "example.org#%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")";
        
        let res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRuleCommas() {
        var rule = "si.com##+js(aeld, scroll, function(e){u(n(e,1,a))})";
        var exp = #"si.com#%#//scriptlet("ubo-aeld", "scroll", "function(e){u(n(e,1,a))}")"#;
        
        var res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
        
        rule = "example.org##+js(aopr,__cad.cpm_popunder)";
        exp = #"example.org#%#//scriptlet("ubo-aopr", "__cad.cpm_popunder")"#;
        
        res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
        
        rule = "example.org##+js(acis,setTimeout,testad)";
        exp = #"example.org#%#//scriptlet("ubo-acis", "setTimeout", "testad")"#;
        
        res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletUboRuleException() {
        let rule = "example.org#@#+js(setTimeout-defuser.js, [native code], 8000)";
        let exp = "example.org#@%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")";
        
        let res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAbpRule() {
        let rule = "example.org#$#hide-if-contains li.serp-item 'li.serp-item div.label'";
        let exp = #"example.org#%#//scriptlet("abp-hide-if-contains", "li.serp-item", "li.serp-item div.label")"#;
        
        let res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res[0], exp);
    }
    
    func testScriptletAbpRuleMultiple() {
        let rule = #"example.org#$#hide-if-has-and-matches-style 'd[id^="_"]' 'div > s' 'display: none'; hide-if-contains /.*/ .p 'a[href^="/ad__c?"]'"#;
        let exp1 = #"example.org#%#//scriptlet("abp-hide-if-has-and-matches-style", "d[id^=\"_\"]", "div > s", "display: none")"#;
        let exp2 = #"example.org#%#//scriptlet("abp-hide-if-contains", "/.*/", ".p", "a[href^=\"/ad__c?\"]")"#;
        
        let res = ruleConverter.convertRule(ruleText: rule);
        
        XCTAssertEqual(res.count, 2);
        XCTAssertEqual(res[0], exp1);
        XCTAssertEqual(res[1], exp2);
    }
    
    func testConvertCssAGRules() {
        let rule = "firmgoogle.com#$#.pub_300x250 {display:block!important;}";
        let exp = "firmgoogle.com#$#.pub_300x250 {display:block!important;}";
        let res = ruleConverter.convertRule(ruleText: rule);
        
        XCTAssertEqual(res, [exp]);
        
        let whitelistCssRule = "example.com#@$#h1 { display: none!important; }";
        let expected = "example.com#@$#h1 { display: none!important; }";
        let actual = ruleConverter.convertRule(ruleText: whitelistCssRule);
        
        XCTAssertEqual(actual, [expected]);
    }
    
    func testConvertAbpRewrite() {
        var exp = "||e9377f.com^$redirect=blank-mp3,domain=eastday.com";
        var res = ruleConverter.convertRule(ruleText: "||e9377f.com^$rewrite=abp-resource:blank-mp3,domain=eastday.com");
        XCTAssertEqual(res, [exp]);
        
        exp = "||lcok.net/2019/ad/$domain=huaren.tv,redirect=blank-mp3";
        res = ruleConverter.convertRule(ruleText: "||lcok.net/2019/ad/$domain=huaren.tv,rewrite=abp-resource:blank-mp3");
        XCTAssertEqual(res, [exp]);
        
        exp = "||lcok.net/2019/ad/$domain=huaren.tv";
        res = ruleConverter.convertRule(ruleText: "||lcok.net/2019/ad/$domain=huaren.tv");
        XCTAssertEqual(res, [exp]);
    }
    
    func testEmptyAndMp4Modifiers() {
        var exp = "/(pagead2)/$domain=vsetv.com,redirect=nooptext,important";
        var res = ruleConverter.convertRule(ruleText: "/(pagead2)/$domain=vsetv.com,empty,important");
        XCTAssertEqual(res, [exp]);
        
        exp = "||fastmap33.com^$redirect=nooptext";
        res = ruleConverter.convertRule(ruleText: "||fastmap33.com^$empty");
        XCTAssertEqual(res, [exp]);
        
        exp = "||anyporn.com/xml^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(ruleText: "||anyporn.com/xml^$media,mp4");
        XCTAssertEqual(res, [exp]);
        
        exp = "||anyporn.com/xml^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(ruleText: "||anyporn.com/xml^$media,redirect=noopmp4-1s");
        XCTAssertEqual(res, [exp]);
    }
    
    func testMp4AndMediaModifiers() {
        var exp = "||video.example.org^$redirect=noopmp4-1s,media";
        var res = ruleConverter.convertRule(ruleText: "||video.example.org^$mp4");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$media,redirect=noopmp4-1s";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$media,mp4");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$media,redirect=noopmp4-1s,domain=example.org";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$media,mp4,domain=example.org");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$redirect=noopmp4-1s,domain=example.org,media";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$mp4,domain=example.org,media");
        XCTAssertEqual(res, [exp]);
    }
    
    func testUboThirdPartyModifiers() {
        var exp = "||video.example.org^$third-party,match-case";
        var res = ruleConverter.convertRule(ruleText: "||video.example.org^$3p,match-case");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$match-case,third-party";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$match-case,3p");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$~third-party";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$1p");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$~third-party";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$~third-party");
        XCTAssertEqual(res, [exp]);
        
        exp = "||video.example.org^$match-case,third-party,redirect=noopmp4-1s,media";
        res = ruleConverter.convertRule(ruleText: "||video.example.org^$match-case,3p,mp4");
        XCTAssertEqual(res, [exp]);
    }
    
    func testConvertUboScriptTags() {
        var exp = "example.com##^script:some-another-rule(test)";
        var res = ruleConverter.convertRule(ruleText: "example.com##^script:some-another-rule(test)");
        XCTAssertEqual(res, [exp]);
        
        exp = "example.com$$script[tag-content=\"12313\"]";
        res = ruleConverter.convertRule(ruleText: "example.com##^script:has-text(12313)");
        XCTAssertEqual(res, [exp]);
        
        res = ruleConverter.convertRule(ruleText: #"example.com##^script:has-text(===):has-text(/[wW]{16000}/)"#);
        XCTAssertEqual(res, [
            "example.com$$script[tag-content=\"===\"]",
            "example.com##^script:has-text(/[wW]{16000}/)"
        ]);
    }
    
    func testInlineScriptModifier() {
        var exp = "||vcrypt.net^$csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        var res = ruleConverter.convertRule(ruleText: "||vcrypt.net^$inline-script");
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$frame,domain=example.org,csp=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(ruleText: "||vcrypt.net^$frame,inline-script,domain=example.org");
        XCTAssertEqual(res, [exp]);
    }
    
    func testInlineFontModifier() {
        var exp = "||vcrypt.net^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        var res = ruleConverter.convertRule(ruleText: "||vcrypt.net^$inline-font");
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$domain=example.org,csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(ruleText: "||vcrypt.net^$inline-font,domain=example.org");
        XCTAssertEqual(res, [exp]);
    }
    
    func testInlineFontAndInlineScriptModifier() {
        var exp = "||vcrypt.net^$csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:; script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        var res = ruleConverter.convertRule(ruleText: "||vcrypt.net^$inline-font,inline-script");
        XCTAssertEqual(res, [exp]);
        
        exp = "||vcrypt.net^$domain=example.org,csp=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:; script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:";
        res = ruleConverter.convertRule(ruleText: "||vcrypt.net^$domain=example.org,inline-font,inline-script");
        XCTAssertEqual(res, [exp]);
    }
    
    func testAllModifierSimple() {
        // test simple rule;
        let rule = "||example.org^$all";
        let res = ruleConverter.convertRule(ruleText: rule);
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
        let res = ruleConverter.convertRule(ruleText: rule);
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
        
        let res = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(res, [exp]);
    }
    
    func testUboCssStyleRule() {
        var exp = "example.com#$#h1 { background-color: blue !important }";
        var res = ruleConverter.convertRule(ruleText: "example.com##h1:style(background-color: blue !important)");
        XCTAssertEqual(res, [exp]);
        
        exp = "example.com#@$#h1 { background-color: blue !important }";
        res = ruleConverter.convertRule(ruleText: "example.com#@#h1:style(background-color: blue !important)");
        XCTAssertEqual(res, [exp]);
    }
    
    func testDenyallowModifierForGenericRules() {
        var ruleText = "*$image,denyallow=x.com,domain=a.com|~b.com";
        var exp: [String] = [
            "*$image,domain=a.com|~b.com",
            "@@||x.com$image,domain=a.com|~b.com"
        ];
        var res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "*$script,domain=a.com|~b.com,denyallow=x.com|y.com";
        exp = ["*$script,domain=a.com|~b.com",
               "@@||x.com$script,domain=a.com|~b.com",
               "@@||y.com$script,domain=a.com|~b.com"];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "$image,frame,denyallow=x.com|y.com|z.com,domain=a.com";
        exp = ["$image,frame,domain=a.com",
               "@@||x.com$image,frame,domain=a.com",
               "@@||y.com$image,frame,domain=a.com",
               "@@||z.com$image,frame,domain=a.com"];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "*$denyallow=x.com,image,frame,domain=a.com";
        exp = ["*$image,frame,domain=a.com",
               "@@||x.com$image,frame,domain=a.com"];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "*$script,denyallow=x.com|y.com";
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, [ruleText]);
        
        ruleText = "*$denyallow=test.com,script,image,frame";
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, [ruleText]);
        
        ruleText = "*$script,domain=a.com|b.com,denyallow=x.com|~y.com";
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, [ruleText]);
        
        ruleText = "*$script,domain=a.com|b.com,denyallow=x.com|*.y.com";
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, [ruleText]);
        
        ruleText = "||test.com$script,domain=a.com|b.com,denyallow=x.com|y.com";
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, [ruleText]);
    }
    
    func testDenyallowModifier() {
        var ruleText = "/banner.png$image,denyallow=test.com,domain=example.org";
        var exp: [String] = [
            "/banner.png$image,domain=example.org",
            "@@||test.com/banner.png$image,domain=example.org",
            "@@||test.com/*/banner.png$image,domain=example.org",
        ];
        var res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "banner.png$image,denyallow=test.com,domain=example.org";
        exp = [
            "banner.png$image,domain=example.org",
            "@@||test.com/banner.png$image,domain=example.org",
            "@@||test.com/*/banner.png$image,domain=example.org",
        ];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "/banner.png$image,denyallow=test1.com|test2.com,domain=example.org";
        exp = [
            "/banner.png$image,domain=example.org",
            "@@||test1.com/banner.png$image,domain=example.org",
            "@@||test1.com/*/banner.png$image,domain=example.org",
            "@@||test2.com/banner.png$image,domain=example.org",
            "@@||test2.com/*/banner.png$image,domain=example.org",
        ];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "@@/banner.png$image,denyallow=test.com,domain=example.org";
        exp = [
            "@@/banner.png$image,domain=example.org",
            "||test.com/banner.png$image,domain=example.org,important",
            "||test.com/*/banner.png$image,domain=example.org,important",
        ];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "@@/banner.png$image,denyallow=test1.com|test2.com,domain=example.org";
        exp = [
            "@@/banner.png$image,domain=example.org",
            "||test1.com/banner.png$image,domain=example.org,important",
            "||test1.com/*/banner.png$image,domain=example.org,important",
            "||test2.com/banner.png$image,domain=example.org,important",
            "||test2.com/*/banner.png$image,domain=example.org,important",
        ];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "/adguard_dns_map.png$image,denyallow=cdn.adguard.com,domain=testcases.adguard.com|surge.sh";
        exp = [
            "/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
            "@@||cdn.adguard.com/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
            "@@||cdn.adguard.com/*/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh"
        ];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
        
        ruleText = "@@/adguard_dns_map.png$image,denyallow=cdn.adguard.com,domain=testcases.adguard.com|surge.sh";
        exp = [
            "@@/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
            "||cdn.adguard.com/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh,important",
            "||cdn.adguard.com/*/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh,important"
        ];
        res = ruleConverter.convertRule(ruleText: ruleText);
        XCTAssertEqual(res, exp);
    }
    
    func testWrapInDoubleQuotesSpecialCases() {
        var rule = "example.org#$#hide-if-contains '"
        var result = ruleConverter.convertRule(ruleText: rule)
        var expect: [String] = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"\'\")"]
        XCTAssertEqual(result, expect)
        
        rule = "example.org#$#hide-if-contains 't"
        result = ruleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"'t\")"]
        XCTAssertEqual(result, expect)
        
        rule = "example.org##+js(cookie-remover.js, 3')"
        result = ruleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"ubo-cookie-remover.js\", \"3'\")"]
        XCTAssertEqual(result, expect)
        
        rule = #"example.org#$#hide-if-contains ""#
        result = ruleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"\\\"\")"]
        XCTAssertEqual(result, expect)
        
        rule = "example.org#$#hide-if-contains \""
        result = ruleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"\\\"\")"]
        XCTAssertEqual(result, expect)
        
        rule = "www.linkedin.com#$#simulate-event-poc click 'xpath(//*[text()=\"Promoted\" or text()=\"Sponsored\" or text()=\"Dipromosikan\" or text()=\"Propagováno\" or text()=\"Promoveret\" or text()=\"Anzeige\" or text()=\"Promocionado\" or text()=\"促銷內容\" or text()=\"Post sponsorisé\" or text()=\"프로모션\" or text()=\"Post sponsorizzato\" or text()=\"广告\" or text()=\"プロモーション\" or text()=\"Treść promowana\" or text()=\"Patrocinado\" or text()=\"Promovat\" or text()=\"Продвигается\" or text()=\"Marknadsfört\" or text()=\"Nai-promote\" or text()=\"ได้รับการโปรโมท\" or text()=\"Öne çıkarılan içerik\" or text()=\"الترويج\"]/ancestor::div[@data-id]//video[@autoplay=\"autoplay\"])' 10"
        result = ruleConverter.convertRule(ruleText: rule)
        expect = ["www.linkedin.com#%#//scriptlet(\"abp-simulate-event-poc\", \"click\", \"xpath(//*[text()=\\\"Promoted\\\" or text()=\\\"Sponsored\\\" or text()=\\\"Dipromosikan\\\" or text()=\\\"Propagováno\\\" or text()=\\\"Promoveret\\\" or text()=\\\"Anzeige\\\" or text()=\\\"Promocionado\\\" or text()=\\\"促銷內容\\\" or text()=\\\"Post sponsorisé\\\" or text()=\\\"프로모션\\\" or text()=\\\"Post sponsorizzato\\\" or text()=\\\"广告\\\" or text()=\\\"プロモーション\\\" or text()=\\\"Treść promowana\\\" or text()=\\\"Patrocinado\\\" or text()=\\\"Promovat\\\" or text()=\\\"Продвигается\\\" or text()=\\\"Marknadsfört\\\" or text()=\\\"Nai-promote\\\" or text()=\\\"ได้รับการโปรโมท\\\" or text()=\\\"Öne çıkarılan içerik\\\" or text()=\\\"الترويج\\\"]/ancestor::div[@data-id]//video[@autoplay=\\\"autoplay\\\"])\", \"10\")"]
        XCTAssertEqual(result, expect)
    }
    
    func testGetStringInBracesSpecialCases() {
        var rule = "test.com##+js(aeld,";
        var result = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(result, [nil]);
        
        rule = "example.org#@#+js(setTimeout-defuser.js";
        result = ruleConverter.convertRule(ruleText: rule);
        XCTAssertEqual(result, [nil]);
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
        ("testDenyallowModifierForGenericRules", testDenyallowModifierForGenericRules),
        ("testDenyallowModifier", testDenyallowModifier),
        ("testWrapInDoubleQuotesSpecialCases", testWrapInDoubleQuotesSpecialCases),
        ("testGetStringInBracesSpecialCases", testGetStringInBracesSpecialCases),
    ]
}
