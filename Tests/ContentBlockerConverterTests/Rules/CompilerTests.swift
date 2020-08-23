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
    
    func testApplyBadfilterExceptions() {
        let filtered = Compiler.applyBadFilterExceptions(rules: []);
        // TODO: Test
        XCTAssertNotNil(filtered);
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testApplyBadfilterExceptions", testApplyBadfilterExceptions),
    ]
}
