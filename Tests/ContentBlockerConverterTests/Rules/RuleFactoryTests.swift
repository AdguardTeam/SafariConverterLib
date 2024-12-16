import Foundation

import XCTest
@testable import ContentBlockerConverter

final class RuleFactoryTests: XCTestCase {
    func testInvalids() {

        XCTAssertNil(try! RuleFactory.createRule(ruleText: "", for: DEFAULT_SAFARI_VERSION))
        XCTAssertNil(try! RuleFactory.createRule(ruleText: "! test", for: DEFAULT_SAFARI_VERSION))

        XCTAssertNil(try? RuleFactory.createRule(ruleText: "test$domain=", for: DEFAULT_SAFARI_VERSION))
    }

    func testNetworkRules() {
        var rule = try! RuleFactory.createRule(ruleText: "test", for: DEFAULT_SAFARI_VERSION)
        XCTAssertNotNil(rule)
        XCTAssertTrue(rule is NetworkRule)

        rule = try! RuleFactory.createRule(ruleText: "@@||test$image,font", for: DEFAULT_SAFARI_VERSION)
        XCTAssertNotNil(rule)
        XCTAssertTrue(rule is NetworkRule)
    }

    func testCosmeticRules() {
        var rule = try! RuleFactory.createRule(ruleText: "##.banner", for: DEFAULT_SAFARI_VERSION)
        XCTAssertNotNil(rule)
        XCTAssertTrue(rule is CosmeticRule)

        rule = try! RuleFactory.createRule(ruleText: "#%#//scriptlet(\"test\")", for: DEFAULT_SAFARI_VERSION)
        XCTAssertNotNil(rule)
        XCTAssertTrue(rule is CosmeticRule)

        rule = try! RuleFactory.createRule(ruleText: "example.org##banner", for: DEFAULT_SAFARI_VERSION)
        XCTAssertNotNil(rule)
        XCTAssertTrue(rule is CosmeticRule)
    }
}

