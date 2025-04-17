import XCTest

@testable import ContentBlockerConverter

final class RuleConverterTests: XCTestCase {
    func testEmpty() {
        let result = RuleConverter.convertRule(ruleText: "")
        XCTAssertEqual(result[0], "")
    }

    func testComment() {
        let result = RuleConverter.convertRule(ruleText: "! comment")
        XCTAssertEqual(result[0], "! comment")
    }

    func testScriptletAGRule() {
        let rule = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')"
        let exp = "example.org#%#//scriptlet('abort-on-property-read', 'I10C')"

        let res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletAGRuleException() {
        let rule = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')"
        let exp = "example.org#@%#//scriptlet('abort-on-property-read', 'I10C')"

        let res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletUboRule() {
        let rule = "example.org##+js(setTimeout-defuser.js, [native code], 8000)"
        let exp =
            "example.org#%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")"

        let res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletUboRuleCommas() {
        var rule = "si.com##+js(aeld, scroll, function(e){u(n(e,1,a))})"
        var exp = #"si.com#%#//scriptlet("ubo-aeld", "scroll", "function(e){u(n(e,1,a))}")"#

        var res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)

        rule = "example.org##+js(aopr,__cad.cpm_popunder)"
        exp = #"example.org#%#//scriptlet("ubo-aopr", "__cad.cpm_popunder")"#

        res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)

        rule = "example.org##+js(acis,setTimeout,testad)"
        exp = #"example.org#%#//scriptlet("ubo-acis", "setTimeout", "testad")"#

        res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletUboRuleException() {
        let rule = "example.org#@#+js(setTimeout-defuser.js, [native code], 8000)"
        let exp =
            "example.org#@%#//scriptlet(\"ubo-setTimeout-defuser.js\", \"[native code]\", \"8000\")"

        let res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletAbpRule() {
        let rule = "example.org#$#hide-if-contains li.serp-item 'li.serp-item div.label'"
        let exp =
            #"example.org#%#//scriptlet("abp-hide-if-contains", "li.serp-item", "li.serp-item div.label")"#

        let res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletAbpExceptionRule() {
        let rule = "example.org#@$#hide-if-contains li.serp-item 'li.serp-item div.label'"
        let exp =
            #"example.org#@%#//scriptlet("abp-hide-if-contains", "li.serp-item", "li.serp-item div.label")"#

        let res = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(res[0], exp)
    }

    func testScriptletAbpRuleMultiple() {
        let rule =
            #"example.org#$#hide-if-has-and-matches-style 'd[id^="_"]' 'div > s' 'display: none'; hide-if-contains /.*/ .p 'a[href^="/ad__c?"]'"#
        let exp1 =
            #"example.org#%#//scriptlet("abp-hide-if-has-and-matches-style", "d[id^=\"_\"]", "div > s", "display: none")"#
        let exp2 =
            #"example.org#%#//scriptlet("abp-hide-if-contains", "/.*/", ".p", "a[href^=\"/ad__c?\"]")"#

        let res = RuleConverter.convertRule(ruleText: rule)

        XCTAssertEqual(res.count, 2)
        XCTAssertEqual(res[0], exp1)
        XCTAssertEqual(res[1], exp2)
    }

    func testConvertCssAGRules() {
        let rule = "firmgoogle.com#$#.pub_300x250 {display:block!important;}"
        let exp = "firmgoogle.com#$#.pub_300x250 {display:block!important;}"
        let res = RuleConverter.convertRule(ruleText: rule)

        XCTAssertEqual(res, [exp])

        let whitelistCssRule = "example.com#@$#h1 { display: none!important; }"
        let expected = "example.com#@$#h1 { display: none!important; }"
        let actual = RuleConverter.convertRule(ruleText: whitelistCssRule)

        XCTAssertEqual(actual, [expected])
    }

    func testUboCssStyleRule() {
        var exp = "example.com#$#h1 { background-color: blue !important }"
        var res = RuleConverter.convertRule(
            ruleText: "example.com##h1:style(background-color: blue !important)"
        )
        XCTAssertEqual(res, [exp])

        exp = "example.com#@$#h1 { background-color: blue !important }"
        res = RuleConverter.convertRule(
            ruleText: "example.com#@#h1:style(background-color: blue !important)"
        )
        XCTAssertEqual(res, [exp])
    }

    func testDenyallowModifierForGenericRules() {
        var ruleText = "*$image,denyallow=x.com,domain=a.com|~b.com"
        var exp: [String] = [
            "*$image,domain=a.com|~b.com",
            "@@||x.com$image,domain=a.com|~b.com",
        ]
        var res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "*$script,domain=a.com|~b.com,denyallow=x.com|y.com"
        exp = [
            "*$script,domain=a.com|~b.com",
            "@@||x.com$script,domain=a.com|~b.com",
            "@@||y.com$script,domain=a.com|~b.com",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "$image,frame,denyallow=x.com|y.com|z.com,domain=a.com"
        exp = [
            "$image,frame,domain=a.com",
            "@@||x.com$image,frame,domain=a.com",
            "@@||y.com$image,frame,domain=a.com",
            "@@||z.com$image,frame,domain=a.com",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "*$denyallow=x.com,image,frame,domain=a.com"
        exp = [
            "*$image,frame,domain=a.com",
            "@@||x.com$image,frame,domain=a.com",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "*$script,denyallow=x.com|y.com"
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, [ruleText])

        ruleText = "*$denyallow=test.com,script,image,frame"
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, [ruleText])

        ruleText = "*$script,domain=a.com|b.com,denyallow=x.com|~y.com"
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, [ruleText])

        ruleText = "*$script,domain=a.com|b.com,denyallow=x.com|*.y.com"
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, [ruleText])

        ruleText = "||test.com$script,domain=a.com|b.com,denyallow=x.com|y.com"
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, [ruleText])
    }

    func testDenyallowModifier() {
        var ruleText = "/banner.png$image,denyallow=test.com,domain=example.org"
        var exp: [String] = [
            "/banner.png$image,domain=example.org",
            "@@||test.com/banner.png$image,domain=example.org",
            "@@||test.com/*/banner.png$image,domain=example.org",
        ]
        var res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "banner.png$image,denyallow=test.com,domain=example.org"
        exp = [
            "banner.png$image,domain=example.org",
            "@@||test.com/banner.png$image,domain=example.org",
            "@@||test.com/*/banner.png$image,domain=example.org",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "/banner.png$image,denyallow=test1.com|test2.com,domain=example.org"
        exp = [
            "/banner.png$image,domain=example.org",
            "@@||test1.com/banner.png$image,domain=example.org",
            "@@||test1.com/*/banner.png$image,domain=example.org",
            "@@||test2.com/banner.png$image,domain=example.org",
            "@@||test2.com/*/banner.png$image,domain=example.org",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "@@/banner.png$image,denyallow=test.com,domain=example.org"
        exp = [
            "@@/banner.png$image,domain=example.org",
            "||test.com/banner.png$image,domain=example.org,important",
            "||test.com/*/banner.png$image,domain=example.org,important",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText = "@@/banner.png$image,denyallow=test1.com|test2.com,domain=example.org"
        exp = [
            "@@/banner.png$image,domain=example.org",
            "||test1.com/banner.png$image,domain=example.org,important",
            "||test1.com/*/banner.png$image,domain=example.org,important",
            "||test2.com/banner.png$image,domain=example.org,important",
            "||test2.com/*/banner.png$image,domain=example.org,important",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText =
            "/adguard_dns_map.png$image,denyallow=cdn.adguard.com,domain=testcases.adguard.com|surge.sh"
        exp = [
            "/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
            "@@||cdn.adguard.com/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
            "@@||cdn.adguard.com/*/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)

        ruleText =
            "@@/adguard_dns_map.png$image,denyallow=cdn.adguard.com,domain=testcases.adguard.com|surge.sh"
        exp = [
            "@@/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh",
            "||cdn.adguard.com/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh,important",
            "||cdn.adguard.com/*/adguard_dns_map.png$image,domain=testcases.adguard.com|surge.sh,important",
        ]
        res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)
    }

    func testDenyallowModifierWithBadfilter() {
        let ruleText = "*$image,denyallow=x.com,domain=a.com|~b.com,badfilter"
        let exp: [String] = [
            "*$image,domain=a.com|~b.com,badfilter",
            "@@||x.com$image,domain=a.com|~b.com,badfilter",
        ]
        let res = RuleConverter.convertRule(ruleText: ruleText)
        XCTAssertEqual(res, exp)
    }

    func testWrapInDoubleQuotesSpecialCases() {
        var rule = "example.org#$#hide-if-contains '"
        var result = RuleConverter.convertRule(ruleText: rule)
        var expect: [String] = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"\'\")"]
        XCTAssertEqual(result, expect)

        rule = "example.org#$#hide-if-contains 't"
        result = RuleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"'t\")"]
        XCTAssertEqual(result, expect)

        rule = "example.org##+js(cookie-remover.js, 3')"
        result = RuleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"ubo-cookie-remover.js\", \"3'\")"]
        XCTAssertEqual(result, expect)

        rule = #"example.org#$#hide-if-contains ""#
        result = RuleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"\\\"\")"]
        XCTAssertEqual(result, expect)

        rule = "example.org#$#hide-if-contains \""
        result = RuleConverter.convertRule(ruleText: rule)
        expect = ["example.org#%#//scriptlet(\"abp-hide-if-contains\", \"\\\"\")"]
        XCTAssertEqual(result, expect)

        rule =
            "www.linkedin.com#$#simulate-event-poc click 'xpath(//*[text()=\"Promoted\" or text()=\"Sponsored\" or text()=\"Dipromosikan\" or text()=\"Propagováno\" or text()=\"Promoveret\" or text()=\"Anzeige\" or text()=\"Promocionado\" or text()=\"促銷內容\" or text()=\"Post sponsorisé\" or text()=\"프로모션\" or text()=\"Post sponsorizzato\" or text()=\"广告\" or text()=\"プロモーション\" or text()=\"Treść promowana\" or text()=\"Patrocinado\" or text()=\"Promovat\" or text()=\"Продвигается\" or text()=\"Marknadsfört\" or text()=\"Nai-promote\" or text()=\"ได้รับการโปรโมท\" or text()=\"Öne çıkarılan içerik\" or text()=\"الترويج\"]/ancestor::div[@data-id]//video[@autoplay=\"autoplay\"])' 10"
        result = RuleConverter.convertRule(ruleText: rule)
        expect = [
            "www.linkedin.com#%#//scriptlet(\"abp-simulate-event-poc\", \"click\", \"xpath(//*[text()=\\\"Promoted\\\" or text()=\\\"Sponsored\\\" or text()=\\\"Dipromosikan\\\" or text()=\\\"Propagováno\\\" or text()=\\\"Promoveret\\\" or text()=\\\"Anzeige\\\" or text()=\\\"Promocionado\\\" or text()=\\\"促銷內容\\\" or text()=\\\"Post sponsorisé\\\" or text()=\\\"프로모션\\\" or text()=\\\"Post sponsorizzato\\\" or text()=\\\"广告\\\" or text()=\\\"プロモーション\\\" or text()=\\\"Treść promowana\\\" or text()=\\\"Patrocinado\\\" or text()=\\\"Promovat\\\" or text()=\\\"Продвигается\\\" or text()=\\\"Marknadsfört\\\" or text()=\\\"Nai-promote\\\" or text()=\\\"ได้รับการโปรโมท\\\" or text()=\\\"Öne çıkarılan içerik\\\" or text()=\\\"الترويج\\\"]/ancestor::div[@data-id]//video[@autoplay=\\\"autoplay\\\"])\", \"10\")"
        ]
        XCTAssertEqual(result, expect)
    }

    func testGetStringInBracesSpecialCases() {
        var rule = "test.com##+js(aeld,"
        var result = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(result, [nil])

        rule = "example.org#@#+js(setTimeout-defuser.js"
        result = RuleConverter.convertRule(ruleText: rule)
        XCTAssertEqual(result, [nil])
    }
}
