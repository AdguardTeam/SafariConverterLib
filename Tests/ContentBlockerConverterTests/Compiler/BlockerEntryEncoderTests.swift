import Foundation

import XCTest
@testable import ContentBlockerConverter

final class BlockerEntryEncoderTests: XCTestCase {
    private let encoder = BlockerEntryEncoder();
    
    func testEmpty() {
        let (result, _) = encoder.encode(entries: [BlockerEntry]());
        XCTAssertEqual(result, "[]");
    }
    
    func testSimpleEntry() {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter());
        let rule = NetworkRule();
        rule.ruleText = "||example.com/path$domain=test.com";
        rule.permittedDomains = ["test.com"];
        
        let entry = converter.createBlockerEntry(rule: rule);
        let (result, _) = encoder.encode(entries: [entry!]);
        XCTAssertEqual(result, "[{\"trigger\":{\"url-filter\":\"^[htpsw]+:\\\\/\\\\/\",\"if-domain\":[\"test.com\"]},\"action\":{\"type\":\"block\"}}]");
    }
    
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testSimpleEntry", testSimpleEntry),
    ]
}
