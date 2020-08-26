import XCTest
@testable import ContentBlockerConverter

final class ContentBlockerConverterTests: XCTestCase {
    let URL_FILTER_ANY_URL = "^[htpsw]+:\\/\\/";
    let URL_FILTER_REGEXP_START_URL = "^[htpsw]+:\\\\/\\\\/([a-z0-9-]+\\\\.)?";
    
    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?";
    let URL_FILTER_WS_ANY_URL_UNESCAPED = "^wss?:\\/\\/";
    let URL_FILTER_REGEXP_SEPARATOR = "[/:&?]?";
    let URL_FILTER_CSS_RULES = ".*";
    let URL_FILTER_URL_RULES_EXCEPTIONS = ".*";
    
    let converter = ContentBlockerConverter();
    
    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        
        let decoder = JSONDecoder();
        let parsedData = try decoder.decode([BlockerEntry].self, from: data);
        
        return parsedData;
    }
    
    func testEmpty() {
        let result = converter.convertArray(rules: [""]);
        
        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[\n\n]");
    }
    
    func testConvertComment() {
        let result = converter.convertArray(rules: ["! this is a comment"]);
        
        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[\n\n]");
    }
    
    func testConvertNetworkRule() {
        let result = converter.convertArray(rules: ["127.0.0.1$network"]);
        
        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        // XCTAssertEqual(result?.errorsCount, 1);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[\n\n]");
    }
    
    func testPopupRules() {
        var ruleText = [
            "||example1.com$document",
            "||example2.com$document,popup",
            "||example5.com$popup,document",
        ];
        
        var result = converter.convertArray(rules: ruleText);
        
        XCTAssertEqual(result?.totalConvertedCount, 3);
        XCTAssertEqual(result?.convertedCount, 3);
        XCTAssertEqual(result?.errorsCount, 0);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 3);

        XCTAssertEqual(decoded[0].trigger.urlFilter, START_URL_UNESCAPED + "example1\\.com");
        XCTAssertEqual(decoded[0].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[0].action.type, "block");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "example2\\.com");
        XCTAssertEqual(decoded[1].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[1].action.type, "block");
        
        XCTAssertEqual(decoded[2].trigger.urlFilter, START_URL_UNESCAPED + "example5\\.com");
        XCTAssertEqual(decoded[2].trigger.resourceType, ["document"]);
        XCTAssertEqual(decoded[2].action.type, "block");
        
        // conversion of $document rule
        ruleText = ["||example.com$document"];
        result = converter.convertArray(rules: ruleText);
        var expected = """
        [
          {
            "trigger" : {
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)example\\\\.com",
              "resource-type" : [
                "document"
              ]
            },
            "action" : {
              "type" : "block"
            }
          }
        ]
        """
        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.converted, expected);
        
        // conversion of $document and $popup rule
        ruleText = ["||test.com$document,popup"];
        result = converter.convertArray(rules: ruleText);
        expected = """
        [
          {
            "trigger" : {
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)test\\\\.com",
              "resource-type" : [
                "document"
              ]
            },
            "action" : {
              "type" : "block"
            }
          }
        ]
        """
        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.converted, expected);
        
        // conversion of $popup rule
        ruleText = ["||example.com^$popup"];
        result = converter.convertArray(rules: ruleText);
        expected = """
        [
          {
            "trigger" : {
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)example\\\\.com[/:&?]?",
              "resource-type" : [
                "document"
              ]
            },
            "action" : {
              "type" : "block"
            }
          }
        ]
        """
        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.converted, expected);

        // conversion of $popup and third-party rule
        ruleText = ["||getsecuredfiles.com^$popup,third-party"];
        result = converter.convertArray(rules: ruleText);
        expected = """
        [
          {
            "trigger" : {
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)getsecuredfiles\\\\.com[/:&?]?",
              "load-type" : [
                "third-party"
              ],
              "resource-type" : [
                "document"
              ]
            },
            "action" : {
              "type" : "block"
            }
          }
        ]
        """
        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.converted, expected);
    }
    
    func testConvertFirstPartyRule() {
        let result = converter.convertArray(rules: ["@@||adriver.ru^$~third-party"]);
        
        let expected = """
        [
          {
            "trigger" : {
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)adriver\\\\.ru[/:&?]?",
              "load-type" : [
                "first-party"
              ]
            },
            "action" : {
              "type" : "ignore-previous-rules"
            }
          }
        ]
        """
        // print("\(result?.converted)")
        XCTAssertEqual(result?.converted, expected);
        XCTAssertEqual(result?.totalConvertedCount, 1);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
    }
    
    func testConvertWebsocketRules() {
        var result = converter.convertArray(rules: ["||test.com^$websocket"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        var decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        var entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com[/:&?]?");
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, nil);
        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);
        
        result = converter.convertArray(rules: ["$websocket,domain=123movies.is"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_WS_ANY_URL_UNESCAPED);
        XCTAssertEqual(entry.trigger.ifDomain, ["*123movies.is"]);
        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);
        
        result = converter.convertArray(rules: [".rocks^$third-party,websocket"]);
        XCTAssertEqual(result?.convertedCount, 1);

        decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_WS_ANY_URL_UNESCAPED + ".*\\.rocks" + URL_FILTER_REGEXP_SEPARATOR);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);
        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);
    }
    
    func testConvertScriptRestrictRules() {
        let result = converter.convertArray(rules: ["||test.com^$~script,third-party"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com[/:&?]?");
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);
        XCTAssertEqual(entry.trigger.resourceType, ["image", "style-sheet", "media", "raw", "font", "document"]);
        // TODO: Fix
        //        assert.ok(convertedRule.trigger["resource-type"]);
        //        assert.equal(-1, convertedRule.trigger["resource-type"].indexOf("script"));
    }
    
    func testConvertSubdocumentFirstParty() {
        let result = converter.convertArray(rules: ["||test.com^$subdocument,~third-party"]);
        XCTAssertEqual(result?.convertedCount, 0);
    }
    
    func testConvertSubdocumentThirdParty() {
        let result = converter.convertArray(rules: ["||test.com^$subdocument,third-party"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "test\\.com[/:&?]?");
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.loadType, ["third-party"]);
        XCTAssertEqual(entry.trigger.resourceType, ["document"]);
        XCTAssertEqual(entry.action.type, "block");
    }
    
    func testConvertEmptyRegex() {
        let result = converter.convertArray(rules: ["@@$image,domain=moonwalk.cc"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_ANY_URL);
        XCTAssertEqual(entry.trigger.ifDomain, ["*moonwalk.cc"]);
        XCTAssertEqual(entry.trigger.unlessDomain, nil);
        XCTAssertEqual(entry.trigger.resourceType, ["image"]);
        XCTAssertEqual(entry.action.type, "ignore-previous-rules");
    }
    
    func testConvertInvertedWhitelistRule() {
        let result = converter.convertArray(rules: ["@@||*$domain=~whitelisted.domain.com|~whitelisted.domain2.com"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_ANY_URL);
        XCTAssertEqual(entry.trigger.ifDomain, nil);
        XCTAssertEqual(entry.trigger.unlessDomain, ["*whitelisted.domain.com", "*whitelisted.domain2.com"]);
        XCTAssertEqual(entry.action.type, "ignore-previous-rules");
    }
    
    func testConvertGenerichide() {
        let result = converter.convertArray(rules: ["@@||hulu.com/page$generichide"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, START_URL_UNESCAPED + "hulu\\.com\\/page");
        XCTAssertEqual(entry.action.type, "ignore-previous-rules");
    }
    
    func testConvertGenericDomainSensitive() {
        let result = converter.convertArray(rules: ["~google.com##banner"]);
        XCTAssertEqual(result?.convertedCount, 1);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 1);
        let entry = decoded[0];
        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(entry.action.type, "css-display-none");
        XCTAssertEqual(entry.trigger.unlessDomain, ["*google.com"]);
    }
    
    func testConvertGenericDomainSensitiveSortingOrder() {
        let result = converter.convertArray(rules: ["~example.org##generic", "##wide1", "##specific", "@@||example.org^$generichide"]);
        XCTAssertEqual(result?.convertedCount, 3);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 3);
        
        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "wide1, specific");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[1].action.type, "css-display-none");
        XCTAssertEqual(decoded[1].action.selector, "generic");
        XCTAssertEqual(decoded[1].trigger.unlessDomain, ["*example.org"]);
        
        XCTAssertEqual(decoded[2].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[2].trigger.ifDomain, ["*example.org"]);
    }
    
    func testConvertGenericDomainSensitiveSortingOrderGenerichide() {
        let result = converter.convertArray(rules: ["###generic", "@@||example.org^$generichide"]);
        XCTAssertEqual(result?.convertedCount, 2);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);
        
        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#generic");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
    }
    
    func testConvertGenericDomainSensitiveSortingOrderElemhide() {
        let result = converter.convertArray(rules: ["example.org###generic", "@@||example.org^$elemhide"]);
        XCTAssertEqual(result?.convertedCount, 2);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);
        
        XCTAssertEqual(decoded[0].trigger.urlFilter, URL_FILTER_CSS_RULES);
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, "#generic");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, URL_FILTER_URL_RULES_EXCEPTIONS);
        XCTAssertEqual(decoded[1].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");
    }
    
    func testCyrillicRules() {
        let result = converter.convertArray(rules: ["меил.рф", "||меил.рф"]);
        XCTAssertEqual(result?.convertedCount, 2);
        
        let decoded = try! parseJsonString(json: result!.converted);
        XCTAssertEqual(decoded.count, 2);
        
//        XCTAssertEqual(decoded[0].trigger.urlFilter, "xn--e1agjb\\.xn--p1ai");
//        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "xn--e1agjb\\.xn--p1ai");
    }
    
    func testRegexRules() {
        var ruleText = "/^https?://(?!static\\.)([^.]+\\.)+?fastpic\\.ru[:/]/$script,domain=fastpic.ru";
        var result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 1);
        
        ruleText = "^https?://(?!static)([^.]+)+?fastpicru[:/]$script,domain=fastpic.ru";
        result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 1);
        XCTAssertEqual(result?.errorsCount, 0);
        
        ruleText = "@@/:\\/\\/.*[.]wp[.]pl\\/[a-z0-9_]{30,50}[.][a-z]{2,5}[/:&?]?/";
        result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 1);
        
        ruleText = "@@/://.*[.]wp[.]pl\\/[a-z0-9_]+[.][a-z]+\\b/";
        result = converter.convertArray(rules: [ruleText]);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 1);
    }
    
    func testCssPseudoClasses() {
        let result = converter.convertArray(rules: [
                "w3schools.com###main > table.w3-table-all.notranslate:first-child > tbody > tr:nth-child(17) > td.notranslate:nth-child(2)",
                "w3schools.com###:root div.ads",
                "w3schools.com###body div[attr='test']:first-child  div",
                "w3schools.com##.todaystripe::after"
            ]
        );
        XCTAssertEqual(result?.convertedCount, 4);
        XCTAssertEqual(result?.errorsCount, 0);
    }
                
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testConvertComment", testConvertComment),
        ("testConvertNetworkRule", testConvertNetworkRule),
        ("testPopupRules", testPopupRules),
        ("testConvertFirstPartyRule", testConvertFirstPartyRule),
        ("testConvertWebsocketRules", testConvertWebsocketRules),
        ("testConvertScriptRestrictRules", testConvertScriptRestrictRules),
        ("testConvertSubdocumentFirstParty", testConvertSubdocumentFirstParty),
        ("testConvertSubdocumentThirdParty", testConvertSubdocumentThirdParty),
        ("testConvertEmptyRegex", testConvertEmptyRegex),
        ("testConvertInvertedWhitelistRule", testConvertInvertedWhitelistRule),
        ("testConvertGenerichide", testConvertGenerichide),
        ("testConvertGenericDomainSensitive", testConvertGenericDomainSensitive),
        ("testConvertGenericDomainSensitiveSortingOrder", testConvertGenericDomainSensitiveSortingOrder),
        ("testConvertGenericDomainSensitiveSortingOrderGenerichide", testConvertGenericDomainSensitiveSortingOrderGenerichide),
        ("testConvertGenericDomainSensitiveSortingOrderElemhide", testConvertGenericDomainSensitiveSortingOrderElemhide),
        ("testCyrillicRules", testCyrillicRules),
        ("testRegexRules", testRegexRules),
        ("testCssPseudoClasses", testCssPseudoClasses),
    ]
}
