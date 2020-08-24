import Foundation

import XCTest
@testable import ContentBlockerConverter

final class CompilerTests: XCTestCase {
    func testEmpty() {
        
        let compiler = Compiler(optimize: false, advancedBlocking: false);
        let result = compiler.compileRules(rules: [Rule]());
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.cssBlockingWide.count, 0);
        XCTAssertEqual(result.cssBlockingGenericDomainSensitive.count, 0);
        XCTAssertEqual(result.cssBlockingDomainSensitive.count, 0);
        XCTAssertEqual(result.cssBlockingGenericHideExceptions.count, 0);
        XCTAssertEqual(result.cssElemhide.count, 0);
        XCTAssertEqual(result.urlBlocking.count, 0);
        XCTAssertEqual(result.other.count, 0);
        XCTAssertEqual(result.important.count, 0);
        XCTAssertEqual(result.importantExceptions.count, 0);
        XCTAssertEqual(result.documentExceptions.count, 0);
        XCTAssertEqual(result.script.count, 0);
        XCTAssertEqual(result.scriptlets.count, 0);
        XCTAssertEqual(result.scriptJsInjectExceptions.count, 0);
        XCTAssertEqual(result.extendedCssBlockingWide.count, 0);
        XCTAssertEqual(result.extendedCssBlockingGenericDomainSensitive.count, 0);
        XCTAssertEqual(result.extendedCssBlockingDomainSensitive.count, 0);
    }
    
    // TODO: Test different rules
    // TODO: Test css compact
    
    func testApplyActionExceptions() {
        var blockingItems = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: ".*"),
                action: BlockerEntry.Action(type: "selector", selector: "test_selector"))
        ];
        
        let exceptions = [
            BlockerEntry(
                trigger: BlockerEntry.Trigger(ifDomain: ["whitelisted.com"]),
                action: BlockerEntry.Action(type: "ignore-previous-rules", selector: "test_selector"))
        ];
        
        let filtered = Compiler.applyActionExceptions(blockingItems: &blockingItems, exceptions: exceptions, actionValue: "selector");
        
        XCTAssertNotNil(filtered);
        XCTAssertEqual(filtered.count, 1);
        XCTAssertNotNil(filtered[0].trigger.unlessDomain);
        XCTAssertEqual(filtered[0].trigger.unlessDomain, ["whitelisted.com"]);
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testApplyActionExceptions", testApplyActionExceptions),
    ]
}
