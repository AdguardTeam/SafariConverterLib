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
            try! RuleFactory.createRule(ruleText: "||example.org^$image,badfilter") as! NetworkRule
        ]
        
        let filtered = RuleFactory.applyBadFilterExceptions(rules: rules as! [Rule], badfilterRules: badfilters);
        XCTAssertNotNil(filtered);
        XCTAssertEqual(filtered.count, 1);
        XCTAssertEqual(filtered[0].ruleText, "||test.org^");
    }
    
    func testApplyBadfilterDomainExceptions() {
        let rules = [
            try! RuleFactory.createRule(ruleText: "*$domain=google.com,third-party,important"),
            try! RuleFactory.createRule(ruleText: "*$domain=test1.com,third-party,important"),
            try! RuleFactory.createRule(ruleText: "*$domain=test2.com|google.com,third-party,important"),
            try! RuleFactory.createRule(ruleText: "*$domain=test3.com|google.com|lenta.ru,third-party,important"),
            try! RuleFactory.createRule(ruleText: "*$domain=test4.com|google.com|example.org|lenta.ru,third-party,important"),
            try! RuleFactory.createRule(ruleText: "*$domain=google.com,important"),
        ];
        
        let badfilters = [
            try! RuleFactory.createRule(ruleText: "*$domain=bad.com|google.com|example.org|lenta.ru,third-party,important,badfilter") as! NetworkRule
        ]
        
        let filtered = RuleFactory.applyBadFilterExceptions(rules: rules as! [Rule], badfilterRules: badfilters);
        XCTAssertNotNil(filtered);
        XCTAssertEqual(filtered.count, 5);
        XCTAssertEqual(filtered[0].ruleText, "*$domain=test1.com,empty,important");
        XCTAssertEqual(filtered[1].ruleText, "*$domain=test2.com,empty,important");
        XCTAssertEqual(filtered[2].ruleText, "*$domain=test3.com,empty,important");
        XCTAssertEqual(filtered[3].ruleText, "*$domain=test4.com,empty,important");
        XCTAssertEqual(filtered[4].ruleText, "*$domain=google.com,important");
    }

    static var allTests = [
        ("testInvalids", testInvalids),
        ("testNetworkRules", testNetworkRules),
        ("testCosmeticRules", testCosmeticRules),
        ("testApplyBadfilterExceptions", testApplyBadfilterExceptions),
        ("testApplyBadfilterDomainExceptions", testApplyBadfilterDomainExceptions)
    ]
}

