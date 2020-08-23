import Foundation

import XCTest
@testable import ContentBlockerConverter

final class BuilderTests: XCTestCase {
    func testEmpty() {
        let builder = Distributor(limit: 0, advancedBlocking: true);
        
        let result = try! builder.createConversionResult(data: CompilationResult());
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.totalConvertedCount, 0);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.converted, "[\n\n]");
    }
    
    func testApplyWildcards() {
        
        let builder = Distributor(limit: 0, advancedBlocking: true);
        
        let testTrigger = BlockerEntry.Trigger(
            ifDomain: ["test_if_domain", "*wildcarded_if_domain"],
            urlFilter: "test_url_filter",
            unlessDomain: ["*test_unless_domain"],
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
        
        var entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];
        
        entries = builder.applyDomainWildcards(entries: entries);
        
        XCTAssertEqual(entries[0].trigger.ifDomain![0], "*test_if_domain");
        XCTAssertEqual(entries[0].trigger.ifDomain![1], "*wildcarded_if_domain");
        
        XCTAssertEqual(entries[0].trigger.unlessDomain![0], "*test_unless_domain");
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testApplyWildcards", testApplyWildcards),
    ]
}

