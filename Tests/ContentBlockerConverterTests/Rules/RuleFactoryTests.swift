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
        XCTAssertTrue(rule is NetworkRule);
        
        rule = RuleFactory.createRule(ruleText: "@@||test$image,font");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is NetworkRule);
    }
    
    func testCosmeticRules() {
        var rule = RuleFactory.createRule(ruleText: "##.banner");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is CosmeticRule);
        
        rule = RuleFactory.createRule(ruleText: "#%#//scriptlet(\"test\")");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is CosmeticRule);
        
        rule = RuleFactory.createRule(ruleText: "example.org##banner");
        XCTAssertNotNil(rule);
        XCTAssertTrue(rule is CosmeticRule);
    }
    
    func testApplyBadfilterExceptions() {
        let rules = [
            RuleFactory.createRule(ruleText: "||example.org^$image"),
            RuleFactory.createRule(ruleText: "||test.org^")
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

