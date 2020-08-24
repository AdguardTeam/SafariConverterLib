import Foundation

import XCTest
@testable import ContentBlockerConverter

final class ScriptletParserTests: XCTestCase {
    func testParse() {
        
        var result = try? ScriptletParser.parse(data: "");
        XCTAssertNil(result);
        
        result = try? ScriptletParser.parse(data: "//scriptlet(\"test-name\")");
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.name, "test-name");
        XCTAssertEqual(result?.json, "[]");
        
        result = try? ScriptletParser.parse(data: "//scriptlet(\"test-name\", \"test-arg\")");
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.name, "test-name");
        XCTAssertEqual(result?.json, "[\"test-arg\"]");
        
        result = try? ScriptletParser.parse(data: "//scriptlet(\"test-name\", 'test-arg')");
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.name, "test-name");
        XCTAssertEqual(result?.json, "[\"test-arg\"]");
        
        result = try? ScriptletParser.parse(data: "//scriptlet('remove-class', 'branding', 'div[class^=\"inner\"]')");
        XCTAssertNotNil(result);
        XCTAssertEqual(result?.name, "remove-class");
        XCTAssertEqual(result?.json, "[\"branding\",\"div[class^=\\\"inner\\\"]\"]");
    }

    static var allTests = [
        ("testParse", testParse),
    ]
}
