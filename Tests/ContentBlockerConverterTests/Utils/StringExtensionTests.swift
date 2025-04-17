import Foundation
import XCTest

@testable import ContentBlockerConverter

final class StringExtensionTests: XCTestCase {
    func testEscapeForJSON() {
        XCTAssertEqual("test".escapeForJSON(), "test")
        XCTAssertEqual(#"test \ test"#.escapeForJSON(), #"test \\ test"#)
        XCTAssertEqual(#"test " test"#.escapeForJSON(), #"test \" test"#)
        XCTAssertEqual("test \n test".escapeForJSON(), "test \\n test")
        XCTAssertEqual("test \r test".escapeForJSON(), "test \\r test")
        XCTAssertEqual("test \t test".escapeForJSON(), "test \\t test")
        XCTAssertEqual("test \u{8} test".escapeForJSON(), "test \\b test")
        XCTAssertEqual("test \u{C} test".escapeForJSON(), "test \\f test")
        XCTAssertEqual("test \0 test".escapeForJSON(), "test \\u0000 test")
        XCTAssertEqual("test \u{1} test".escapeForJSON(), "test \\u0001 test")
        XCTAssertEqual("test \u{7} test".escapeForJSON(), "test \\u0007 test")
        XCTAssertEqual("test \u{11} test".escapeForJSON(), "test \\u0011 test")
        XCTAssertEqual("test \u{15} test".escapeForJSON(), "test \\u0015 test")
    }

    func testSplit() {
        let testCases: [(input: String, expected: [String])] = [
            ("apple,banana,grape", ["apple", "banana", "grape"]),
            ("apple,banana\\,grape", ["apple", "banana,grape"]),
            ("apple,,banana", ["apple", "banana"]),
            ("apple,banana,", ["apple", "banana"]),
            ("apple,banana\\\\,grape", ["apple", "banana\\", "grape"]),
            ("", []),
            ("apple", ["apple"]),
            (",", []),
            ("apple\\,banana\\,grape", ["apple,banana,grape"]),
            ("apple,banana\\,grape\\\\,pear,peach", ["apple", "banana,grape\\", "pear", "peach"]),
        ]

        for (input, expected) in testCases {
            let result = input.split(delimiter: UInt8(ascii: ","), escapeChar: UInt8(ascii: "\\"))
            XCTAssertEqual(result, expected, "Failed for input: \(input)")
        }
    }
}
