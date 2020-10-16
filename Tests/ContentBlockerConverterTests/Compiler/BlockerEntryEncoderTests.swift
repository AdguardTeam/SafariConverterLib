import Foundation

import XCTest
@testable import ContentBlockerConverter

final class BlockerEntryEncoderTests: XCTestCase {
    private let encoder = BlockerEntryEncoder();
    
    func testEmpty() {
        let result = encoder.encode(entries: [BlockerEntry]());
        XCTAssertEqual(result, "[]");
    }
    
    func testEscapeString() {
        var result = "";
        
        result = encoder.escapeString(value: "test");
        XCTAssertEqual(result, "test");
        
        result = encoder.escapeString(value: #"test \ test"#);
        XCTAssertEqual(result, #"test \\ test"#);
        
        result = encoder.escapeString(value: #"test " test"#);
        XCTAssertEqual(result, #"test \" test"#);
        
        result = encoder.escapeString(value: "test \n test");
        XCTAssertEqual(result, "test \\n test");
        
        result = encoder.escapeString(value: "test \r test");
        XCTAssertEqual(result, "test \\r test");
        
        result = encoder.escapeString(value: "test \t test");
        XCTAssertEqual(result, "test \\t test");
    }
    
    static var allTests = [
        ("testEmpty", testEmpty),
        ("testEscapeString", testEscapeString),
    ]
}
