import Foundation

import XCTest
@testable import ContentBlockerConverter

final class RuleFactoryTests: XCTestCase {
    func testInvalids() {
        
        XCTAssertNil(RuleFactory.createRule(ruleText: nil));
        XCTAssertNil(RuleFactory.createRule(ruleText: ""));
        XCTAssertNil(RuleFactory.createRule(ruleText: " test"));
        XCTAssertNil(RuleFactory.createRule(ruleText: "! test"));
        XCTAssertNil(RuleFactory.createRule(ruleText: "test - test"));
    }
    
    func testNetworkRules() {
        var rule = RuleFactory.createRule(ruleText: "test");
        XCTAssertNotNil(rule);
    }
    
    //TODO: More tests

    static var allTests = [
        ("testInvalids", testInvalids),
        ("testNetworkRules", testNetworkRules),
    ]
}

