import Foundation

import XCTest
@testable import ContentBlockerConverter

final class StringExtensionTests: XCTestCase {

    func testEscapeForJSON() {
        XCTAssertEqual("test".escapeForJSON(), "test");
        XCTAssertEqual(#"test \ test"#.escapeForJSON(), #"test \\ test"#);
        XCTAssertEqual(#"test " test"#.escapeForJSON(), #"test \" test"#);
        XCTAssertEqual("test \n test".escapeForJSON(), "test \\n test");
        XCTAssertEqual("test \r test".escapeForJSON(), "test \\r test");
        XCTAssertEqual("test \t test".escapeForJSON(), "test \\t test");
    }
    
    static var allTests = [
        ("testEscapeForJSON", testEscapeForJSON),
    ]
}
