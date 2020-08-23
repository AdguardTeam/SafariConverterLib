import Foundation

import XCTest
@testable import ContentBlockerConverter

final class NetworkRuleTests: XCTestCase {
    func testParseDomainInfo() {
        
        let rule = NetworkRule();
        
        rule.urlRuleText = "";
        var result = rule.parseRuleDomain();
        XCTAssertNil(result);
        
        rule.urlRuleText = "example.com";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, nil);
        
        rule.urlRuleText = "||example.com";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, nil);
        
        rule.urlRuleText = "||example.com/path";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, "/path");
        
        rule.urlRuleText = "||invalid/path";
        result = rule.parseRuleDomain();
        XCTAssertNil(result);
        
        rule.urlRuleText = "$third-party,domain=example.com";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, nil);
        
        rule.urlRuleText = "||example.com^$document";
        result = rule.parseRuleDomain();
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.domain, "example.com");
        XCTAssertEqual(result?.path, "^");
    }

    static var allTests = [
        ("testParseDomainInfo", testParseDomainInfo),
    ]
}
