import XCTest
@testable import ContentBlockerConverter

final class ConversionResultTests: XCTestCase {
    let testTrigger = BlockerEntry.Trigger(
        ifDomain: ["test_if_domain"],
        urlFilter: "test_url_filter",
        unlessDomain: ["test_unless_domain"],
        shortcut: "test_shortcut",
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
    
    func assertEntry(actual: String?) -> Void {
        XCTAssertNotNil(actual);
        
        XCTAssertTrue(actual!.contains("\"url-filter\":\"test_url_filter\""));
        XCTAssertTrue(actual!.contains("test_unless_domain"));
        XCTAssertTrue(actual!.contains("test_if_domain"));
        XCTAssertTrue(actual!.contains("\"url-shortcut\":\"test_shortcut\""));
        
        XCTAssertTrue(actual!.contains("\"type\":\"test_type\""));
        XCTAssertTrue(actual!.contains("\"css\":\"test_css\""));
    }
    
    func testEmpty() {
        
        let result = try! ConversionResult(entries: [], limit: 0, errorsCount: 0, message: "");
        
        XCTAssertEqual(result.totalConvertedCount, 0);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.converted, "[]");
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
        
        assertEntry(actual: result.converted);
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
        assertEntry(actual: result.converted);
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
        assertEntry(actual: result.converted);
        
        XCTAssertEqual(result.advancedBlockingConvertedCount, 1);
        assertEntry(actual: result.advancedBlocking);
    
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testSimple", testSimple),
        ("testOverlimit", testOverlimit),
        ("testAdvancedBlocking", testAdvancedBlocking),
    ]
}
