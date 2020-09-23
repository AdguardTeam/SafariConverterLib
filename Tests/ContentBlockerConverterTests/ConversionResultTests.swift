import XCTest
@testable import ContentBlockerConverter

final class ConversionResultTests: XCTestCase {
    let testTrigger = BlockerEntry.Trigger(
        ifDomain: ["test_if_domain"],
        urlFilter: "test_url_filter",
        unlessDomain: ["test_unless_domain"],
        shortcut: "test_shorcut",
        regex: nil
    );
    
    let testAction = BlockerEntry.Action(
        type: "test_type",
        selector: nil,
        css: "test_css",
        script: nil,
        scriptlet: nil,
        scriptletParam: nil
    );
    
    let correctEntryJSON = """
    [
      {
        "trigger" : {
          "unless-domain" : [
            "test_unless_domain"
          ],
          "url-filter" : "test_url_filter",
          "if-domain" : [
            "test_if_domain"
          ],
          "url-shortcut" : "test_shorcut"
        },
        "action" : {
          "type" : "test_type",
          "css" : "test_css"
        }
      }
    ]
    """;
    
    func testEmpty() {
        
        let result = try! ConversionResult(entries: [], limit: 0, errorsCount: 0, message: "");
        
        XCTAssertEqual(result.totalConvertedCount, 0);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.converted, "[\n\n]");
    }
    
    func testSimple() {
        
        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];
        
        let result = try! ConversionResult(entries: entries, limit: 0, errorsCount: 0, message: "test");
        
        XCTAssertEqual(result.totalConvertedCount, 1);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.message, "test");
        XCTAssertEqual(result.converted, correctEntryJSON);
    }
    
    func testOverlimit() {
        
        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction),
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];
        
        let result = try! ConversionResult(entries: entries, limit: 1, errorsCount: 0, message: "test");
        
        XCTAssertEqual(result.totalConvertedCount, 2);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 1);
        XCTAssertEqual(result.overLimit, true);
        XCTAssertEqual(result.message, "test");
        XCTAssertEqual(result.converted, correctEntryJSON);
    }
    
    func testAdvancedBlocking() {
        
        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];
        
        let result = try! ConversionResult(entries: entries, advBlockingEntries: entries, limit: 1, errorsCount: 0, message: "test");
        
        XCTAssertEqual(result.totalConvertedCount, 1);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.message, "test");
        XCTAssertEqual(result.converted, correctEntryJSON);
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);
        XCTAssertEqual(result.advancedBlocking, correctEntryJSON);
    
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testSimple", testSimple),
        ("testOverlimit", testOverlimit),
        ("testAdvancedBlocking", testAdvancedBlocking),
    ]
}
