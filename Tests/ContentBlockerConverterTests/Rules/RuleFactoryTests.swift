import Foundation

import XCTest
@testable import ContentBlockerConverter

final class RuleFactoryTests: XCTestCase {
    func testInvalids() {
        
        XCTAssertNil(try! RuleFactory.createRule(ruleText: nil));
        XCTAssertNil(try! RuleFactory.createRule(ruleText: ""));
        XCTAssertNil(try! RuleFactory.createRule(ruleText: " test"));
        XCTAssertNil(try! RuleFactory.createRule(ruleText: "! test"));
        XCTAssertNil(try! RuleFactory.createRule(ruleText: "test - test"));
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
    
    func testApplyBadfilterExceptions() {
        let rules = [
            try! RuleFactory.createRule(ruleText: "||example.org^$image"),
            try! RuleFactory.createRule(ruleText: "||test.org^")
        ];
        
        let badfilters = [
            "||example.org^$image"
        ]
        
        let filtered = RuleFactory.applyBadFilterExceptions(rules: rules as! [Rule], badfilterRules: badfilters);
        XCTAssertNotNil(filtered);
        XCTAssertEqual(filtered.count, 1);
        XCTAssertEqual(filtered[0].ruleText, "||test.org^");
    }

    static var allTests = [
        ("testInvalids", testInvalids),
        ("testNetworkRules", testNetworkRules),
        ("testCosmeticRules", testCosmeticRules),
        ("testApplyBadfilterExceptions", testApplyBadfilterExceptions),
    ]
}

