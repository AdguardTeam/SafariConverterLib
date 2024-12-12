import Foundation

import XCTest
@testable import ContentBlockerConverter

final class NetworkRuleTests: XCTestCase {
    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?"
    let URL_FILTER_REGEXP_END_SEPARATOR = "([\\/:&\\?].*)?$"

    func testSimpleRules() {
        var result = try! NetworkRule(ruleText: "||example.org^")

        XCTAssertEqual(result.ruleText, "||example.org^")
        XCTAssertEqual(result.isWhiteList, false)
        XCTAssertEqual(result.isImportant, false)
        XCTAssertEqual(result.isScript, false)
        XCTAssertEqual(result.isScriptlet, false)
        XCTAssertEqual(result.isDocumentWhiteList, false)

        XCTAssertEqual(result.permittedDomains, [])
        XCTAssertEqual(result.restrictedDomains, [])

        XCTAssertEqual(result.isWebSocket, false)
        XCTAssertEqual(result.isUrlBlock, false)
        XCTAssertEqual(result.isCssExceptionRule, false)
        XCTAssertEqual(result.urlRuleText, "||example.org^")
        XCTAssertEqual(result.isThirdParty, false)
        XCTAssertEqual(result.isMatchCase, false)
        XCTAssertEqual(result.isBlockPopups, false)
        XCTAssertEqual(result.urlRegExpSource, "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\\/:&\\?].*)?$")

        XCTAssertEqual(result.permittedContentType, [NetworkRule.ContentType.ALL])
        XCTAssertEqual(result.restrictedContentType, [])

        result = try! NetworkRule(ruleText: "||example.org^$third-party")
        XCTAssertEqual(result.urlRuleText, "||example.org^")
        XCTAssertEqual(result.isCheckThirdParty, true)
        XCTAssertEqual(result.isThirdParty, true)

        result = try! NetworkRule(ruleText: "@@||example.org^$third-party")
        XCTAssertEqual(result.isWhiteList, true)

        result = try! NetworkRule(ruleText: "||example.org/this$is$path$image,font,media")
        XCTAssertEqual(result.urlRuleText, "||example.org/this$is$path")

        XCTAssertEqual(result.permittedContentType, [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.FONT, NetworkRule.ContentType.MEDIA])
        XCTAssertEqual(result.restrictedContentType, [])

        result = try! NetworkRule(ruleText: "||example.org\\$smth")
        XCTAssertEqual(result.urlRuleText, "||example.org\\$smth")
    }

    func testDomains() {
        let result = try! NetworkRule(ruleText: "||example.org^$domain=example.org|~sub.example.org")

        XCTAssertNotNil(result);
        XCTAssertEqual(result.permittedDomains, ["example.org"])
        XCTAssertEqual(result.restrictedDomains, ["sub.example.org"])
    }

    func testRegexRules() {
        var result = try! NetworkRule(ruleText: "/regex/")
        XCTAssertEqual(result.urlRuleText, "/regex/")
        XCTAssertEqual(result.urlRegExpSource, "regex")

        result = try! NetworkRule(ruleText: "@@/regex/")
        XCTAssertEqual(result.urlRuleText, "/regex/")
        XCTAssertEqual(result.urlRegExpSource, "regex")

        result = try! NetworkRule(ruleText: "@@/regex/$third-party")
        XCTAssertEqual(result.urlRuleText, "/regex/")
        XCTAssertEqual(result.urlRegExpSource, "regex")

        result = try! NetworkRule(ruleText: "/example{/")
        XCTAssertEqual(result.urlRuleText, "/example{/")
        XCTAssertEqual(result.urlRegExpSource, "example{")

        result = try! NetworkRule(ruleText: #"/^http:\/\/example\.org\/$/"#)
        XCTAssertEqual(result.urlRuleText, #"/^http:\/\/example\.org\/$/"#)
        XCTAssertEqual(result.urlRegExpSource, #"^http:\/\/example\.org\/$"#)
    }

    func testUrlSlashRules() {
        let result = try! NetworkRule(ruleText: "/addyn|*|adtech")
        XCTAssertEqual(result.urlRuleText, "/addyn|*|adtech")
        XCTAssertEqual(result.urlRegExpSource, #"\/addyn\|.*\|adtech"#)
    }
    
    func testMatchAllUrlsPattern() {
        let result = try! NetworkRule(ruleText: "$image,frame,domain=a.com")

        XCTAssertEqual(result.urlRuleText, "")
        XCTAssertEqual(result.urlRegExpSource, nil)
        XCTAssertEqual(result.permittedDomains, ["a.com"])
        XCTAssertEqual(result.restrictedDomains, [])
        XCTAssertEqual(result.permittedContentType, [NetworkRule.ContentType.IMAGE, NetworkRule.ContentType.SUBDOCUMENT])
        XCTAssertEqual(result.restrictedContentType, [])
    }
    
    func testReplaceModifier() {
        let result = try? NetworkRule(ruleText: "/example/$replace=/test/test2/")
        XCTAssertNil(result)
    }
    
    func testUnexpectedOptionValue() {
        let result = try? NetworkRule(ruleText: "||example.org^$doc=test")
        XCTAssertNil(result)
    }
    
    func testRuleWithModifierThatLooksLikeRegex() {
        let result = try! NetworkRule(ruleText: "/example/$domain=test.com/")

        XCTAssertEqual(result.urlRuleText, "/example/")
        XCTAssertEqual(result.urlRegExpSource, "example")
        XCTAssertEqual(result.permittedDomains, ["test.com/"]) // It's invalid, but it doesn't break Safari.
        XCTAssertEqual(result.restrictedDomains, [])
    }
    
    func testDomainWithRegexModifier() {
        let result = try? NetworkRule(ruleText: "/example/$domain=/test.com/")
        XCTAssertNil(result)
    }

    func testPunycodeDomain() {
        let result = try! NetworkRule(ruleText: "||почта.рф^")
        XCTAssertEqual(result.urlRuleText, "||xn--80a1acny.xn--p1ai^")
    }
    
    func testExtractDomain() {
        let testPatterns: [(pattern: String, expectedDomain: String, expectedPatternMatchesPath: Bool)] = [
            ("", "", false),
            ("/", "", false),
            ("@@", "", false),
            ("@@^", "", false),
            ("@@/", "", false),
            ("example", "example", false),
            ("example.com", "example.com", false),
            ("||example.com", "example.com", false),
            ("||example.com/path", "example.com", true),
            ("||invalid/path", "invalid", true),
            ("http://example.org$", "example.org", false),
            ("https://example.org^someother", "example.org", true),
        ]
        
        for testPattern in testPatterns {
            let result = NetworkRuleParser.extractDomain(pattern: testPattern.pattern)
            XCTAssertEqual(result.domain, testPattern.expectedDomain, "Pattern \(testPattern.pattern): expected domain \(testPattern.expectedDomain), but got \(result.domain)")
            XCTAssertEqual(result.patternMatchesPath, testPattern.expectedPatternMatchesPath, "Pattern \(testPattern.pattern): expected patternMatchesPath \(testPattern.expectedPatternMatchesPath), but got \(result.patternMatchesPath)")
        }
    }
    
    func testExtractDomainAndValidate() {
        let testPatterns: [(pattern: String, expectedDomain: String, expectedPatternMatchesPath: Bool)] = [
            ("", "", false),
            ("/", "", false),
            ("@@", "", false),
            ("@@^", "", false),
            ("@@/", "", false),
            ("example", "", false),
            ("example.com", "example.com", false),
            ("||example.com", "example.com", false),
            ("||example.com/path", "example.com", true),
            ("||invalid/path", "", false),
            ("http://example.org$", "example.org", false),
            ("https://example.org^someother", "example.org", true),
        ]

        for testPattern in testPatterns {
            let result = NetworkRuleParser.extractDomainAndValidate(pattern: testPattern.pattern)
            XCTAssertEqual(result.domain, testPattern.expectedDomain, "Pattern \(testPattern.pattern): expected domain \(testPattern.expectedDomain), but got \(result.domain)")
            XCTAssertEqual(result.patternMatchesPath, testPattern.expectedPatternMatchesPath, "Pattern \(testPattern.pattern): expected patternMatchesPath \(testPattern.expectedPatternMatchesPath), but got \(result.patternMatchesPath)")
        }
    }

    func testDomainWithSeparator() {
        let result = try! NetworkRule(ruleText: "||a.a^");

        let urlRegExpSource = result.urlRegExpSource;
        XCTAssertEqual(urlRegExpSource as String?, START_URL_UNESCAPED + "a\\.a" + URL_FILTER_REGEXP_END_SEPARATOR);

        let regex = try! NSRegularExpression(pattern: urlRegExpSource! as String);
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://a.a/test"));
        XCTAssertFalse(SimpleRegex.isMatch(regex: regex, target: "https://a.allegroimg.com"));
    }

    func testVariousUrlRegex() {
        var result = try! NetworkRule(ruleText: "||example.com")
        XCTAssertEqual(result.urlRegExpSource as String?, START_URL_UNESCAPED + "example\\.com")
        var regex = try! NSRegularExpression(pattern: result.urlRegExpSource! as String)
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com/path"))
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com"))
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com/"))
        XCTAssertFalse(SimpleRegex.isMatch(regex: regex, target: "https://example.org"))

        result = try! NetworkRule(ruleText: "||example.com^")
        XCTAssertEqual(result.urlRegExpSource as String?, START_URL_UNESCAPED + "example\\.com" + URL_FILTER_REGEXP_END_SEPARATOR)
        regex = try! NSRegularExpression(pattern: result.urlRegExpSource! as String)
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com/path"))
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com"))
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com/"))
        XCTAssertFalse(SimpleRegex.isMatch(regex: regex, target: "https://example.org"))

        result = try! NetworkRule(ruleText: "||example.com/path")
        XCTAssertEqual(result.urlRegExpSource as String?, START_URL_UNESCAPED + "example\\.com\\/path")
        regex = try! NSRegularExpression(pattern: result.urlRegExpSource! as String)
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com/path"))
        XCTAssertFalse(SimpleRegex.isMatch(regex: regex, target: "https://example.com"))

        result = try! NetworkRule(ruleText: "||example.com^path")
        XCTAssertEqual(result.urlRegExpSource as String?, START_URL_UNESCAPED + "example\\.com[/:&?]?path")
        regex = try! NSRegularExpression(pattern: result.urlRegExpSource! as String)
        XCTAssertTrue(SimpleRegex.isMatch(regex: regex, target: "https://example.com/path"))
        XCTAssertFalse(SimpleRegex.isMatch(regex: regex, target: "https://example.com"))
    }

    func testNoopModifier() {
        var rule = "||example.com^$domain=example.org,image,script,______,important"

        var result = try! NetworkRule(ruleText: rule)
        XCTAssertEqual(result.ruleText, rule)
        XCTAssertEqual(result.isWhiteList, false)
        XCTAssertEqual(result.isImportant, true)
        XCTAssertEqual(result.isScript, false)
        XCTAssertEqual(result.isScriptlet, false)
        XCTAssertEqual(result.isDocumentWhiteList, false)
        XCTAssertEqual(result.permittedDomains, ["example.org"])
        XCTAssertEqual(result.restrictedDomains, [])
        XCTAssertEqual(result.isWebSocket, false)
        XCTAssertEqual(result.isUrlBlock, false)
        XCTAssertEqual(result.isCssExceptionRule, false)
        XCTAssertEqual(result.urlRuleText, "||example.com^")
        XCTAssertEqual(result.isThirdParty, false)
        XCTAssertEqual(result.isMatchCase, false)
        XCTAssertEqual(result.isBlockPopups, false)

        rule = "@@||example.com^$domain=example.org,__,_,image,__________,script,_,___,_,_,_,_,__,important"

        result = try! NetworkRule(ruleText: rule)
        XCTAssertEqual(result.ruleText, rule)
        XCTAssertEqual(result.isWhiteList, true)
        XCTAssertEqual(result.isImportant, true)
        XCTAssertEqual(result.permittedDomains, ["example.org"])
        XCTAssertEqual(result.restrictedDomains, [])
        XCTAssertEqual(result.urlRuleText, "||example.com^")

        let invalidNoopRule = "@@||example.com^$domain=example.org,__,_,image,________z__,script,important"

        XCTAssertThrowsError(try NetworkRule(ruleText: invalidNoopRule))
    }

    func testPingModifier() {
        var rule = "||example.com^$ping"
        XCTAssertThrowsError(try NetworkRule(ruleText: rule))

        rule = "||example.com^$~ping"
        XCTAssertThrowsError(try NetworkRule(ruleText: rule))
    }

    func testSpecifichide() {
        var rule = "@@||example.org^$specifichide"

        let result = try! NetworkRule(ruleText: rule)

        XCTAssertNotNil(result)
        XCTAssertEqual(result.ruleText, "@@||example.org^$specifichide")
        XCTAssertEqual(result.isCssExceptionRule, false)
        XCTAssertEqual(result.urlRuleText, "||example.org^")
        XCTAssertEqual(result.enabledOptions, [NetworkRule.NetworkRuleOption.Specifichide])

        rule = "||example.org^$specifichide"
        XCTAssertThrowsError(try NetworkRule(ruleText: rule))
    }
}
