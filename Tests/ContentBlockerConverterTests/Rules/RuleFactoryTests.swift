import Foundation

import XCTest
@testable import ContentBlockerConverter

final class RuleFactoryTests: XCTestCase {
    func testInvalids() {
        
        XCTAssertNil(try! RuleFactory.createRule(ruleText: nil));
        XCTAssertNil(try! RuleFactory.createRule(ruleText: ""));
        XCTAssertNil(try! RuleFactory.createRule(ruleText: "! test"));
        
        XCTAssertNil(try? RuleFactory.createRule(ruleText: "test$domain="));
    }
    
    func testNetworkRules() {
        var rule = try! RuleFactory.createRule(ruleText: "test");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is NetworkRule);
        
        rule = try! RuleFactory.createRule(ruleText: "@@||test$image,font");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is NetworkRule);
    }
    
    func testCosmeticRules() {
        var rule = try! RuleFactory.createRule(ruleText: "##.banner");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is CosmeticRule);
        
        rule = try! RuleFactory.createRule(ruleText: "#%#//scriptlet(\"test\")");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is CosmeticRule);
        
        rule = try! RuleFactory.createRule(ruleText: "example.org##banner");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is CosmeticRule);
    }
    
    static var allTests = [
        ("testInvalids", testInvalids),
        ("testNetworkRules", testNetworkRules),
        ("testCosmeticRules", testCosmeticRules),
    ]
}

