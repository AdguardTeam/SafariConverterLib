import Foundation

import XCTest
@testable import ContentBlockerConverter

final class BlockerEntryEncoderTests: XCTestCase {
    private let encoder = BlockerEntryEncoder();
    
    func testEmpty() {
        let (result, _) = encoder.encode(entries: [BlockerEntry]());
        XCTAssertEqual(result, "[]");
    }
    
    func testSimpleEntry() throws {
        let converter = BlockerEntryFactory(advancedBlockingEnabled: false, errorsCounter: ErrorsCounter())
        let rule = try NetworkRule(ruleText: "||example.com/path$domain=test.com")
        
        let entry = converter.createBlockerEntry(rule: rule)
        let (result, _) = encoder.encode(entries: [entry!])
        XCTAssertEqual(result, "[{\"trigger\":{\"url-filter\":\"^[htpsw]+:\\\\/\\\\/([a-z0-9-]+\\\\.)?example\\\\.com\\\\/path\",\"if-domain\":[\"*test.com\"]},\"action\":{\"type\":\"block\"}}]");
    }
    
    // TODO(ameshkov): !!! Remove allTests, not needed in newer Swift.
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testSimpleEntry", testSimpleEntry),
    ]
}
