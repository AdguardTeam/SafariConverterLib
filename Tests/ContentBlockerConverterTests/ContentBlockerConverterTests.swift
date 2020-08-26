import XCTest
@testable import ContentBlockerConverter

final class ContentBlockerConverterTests: XCTestCase {
    let URL_FILTER_ANY_URL = "^[htpsw]+:\\/\\/";
    let URL_FILTER_REGEXP_START_URL = "^[htpsw]+:\\\\/\\\\/([a-z0-9-]+\\\\.)?";
    
    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?";
    let URL_FILTER_WS_ANY_URL_UNESCAPED = "^wss?:\\/\\/";
    let URL_FILTER_REGEXP_SEPARATOR = "[/:&?]?";
    
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
        XCTAssertEqual(result?.converted, "[\n\n]");
        
//        assert.equal(converted[0].trigger["resource-type"], 'document');
//        assert.equal(converted[0].action["type"], 'block');
//        assert.equal(Object.keys(converted[0]).length, 2);
//        assert.equal(converted[0].trigger["url-filter"], URL_START + "example1\\.com");
//        assert.equal(converted[1].trigger["resource-type"], 'document');
//        assert.equal(converted[1].action["type"], 'block');
//        assert.equal(Object.keys(converted[1]).length, 2);
//        assert.equal(converted[1].trigger["url-filter"], URL_START + "example2\\.com");
//        assert.equal(converted[2].trigger["resource-type"], 'document');
//        assert.equal(converted[2].action["type"], 'block');
//        assert.equal(Object.keys(converted[2]).length, 2);
//        assert.equal(converted[2].trigger["url-filter"], URL_START + "example5\\.com");
        
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
        
//        print("\(result!.converted)");
//        print("\(expected)");
        
        // conversion of $document and $popup rule
        ruleText = ["||test.com$document,popup"];
        result = converter.convertArray(rules: ruleText);
        expected = """
        [
          {
            "trigger" : {
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)test\\.com",
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
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)example\\.com[/:&?]?",
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
              "url-filter" : "\(URL_FILTER_REGEXP_START_URL)getsecuredfiles\\.com[/:&?]?",
              "resource-type" : [
                "document"
              ],
              "load-type" : [
                "third-party"
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
        
        //TODO: FIx empty url
//        result = converter.convertArray(rules: ["$websocket,domain=123movies.is"]);
//        XCTAssertEqual(result?.convertedCount, 1);
//
//        decoded = try! parseJsonString(json: result!.converted);
//        XCTAssertEqual(decoded.count, 1);
//        entry = decoded[0];
//        XCTAssertEqual(entry.trigger.urlFilter, URL_FILTER_WS_ANY_URL_UNESCAPED);
//        XCTAssertEqual(entry.trigger.ifDomain, ["*123movies.is"]);
//        XCTAssertEqual(entry.trigger.resourceType, ["raw"]);
        
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
        
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testConvertComment", testConvertComment),
        ("testConvertNetworkRule", testConvertNetworkRule),
        ("testPopupRules", testPopupRules),
        ("testConvertFirstPartyRule", testConvertFirstPartyRule),
        ("testConvertWebsocketRules", testConvertWebsocketRules),
        ("testConvertScriptRestrictRules", testConvertScriptRestrictRules),
        ("testConvertSubdocumentFirstParty", testConvertSubdocumentFirstParty),
    ]
}
