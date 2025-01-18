import Foundation
import XCTest
@testable import ContentBlockerConverter

final class ScriptletParserTests: XCTestCase {
    func testParse() {
        var result = try? ScriptletParser.parse(data: "")
        XCTAssertNil(result)

        result = try? ScriptletParser.parse(data: "//scriptlet(\"test-name\")")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-name")
        XCTAssertEqual(result?.json, "{\"name\":\"test-name\",\"args\":[]}")

        result = try? ScriptletParser.parse(data: "//scriptlet(\"test-name\", \"test-arg\")")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-name")
        XCTAssertEqual(result?.json, "{\"name\":\"test-name\",\"args\":[\"test-arg\"]}")

        result = try? ScriptletParser.parse(data: "//scriptlet(\"test-name\", 'test-arg')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-name")
        XCTAssertEqual(result?.json, "{\"name\":\"test-name\",\"args\":[\"test-arg\"]}")

        result = try? ScriptletParser.parse(data: "//scriptlet('remove-class', 'branding', 'div[class^=\"inner\"]')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "remove-class")
        XCTAssertEqual(result?.json, "{\"name\":\"remove-class\",\"args\":[\"branding\",\"div[class^=\\\"inner\\\"]\"]}")

        result = try? ScriptletParser.parse(data: "//scriptlet('remove-class', 'test,comma')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "remove-class")
        XCTAssertEqual(result?.json, "{\"name\":\"remove-class\",\"args\":[\"test,comma\"]}")

        result = try? ScriptletParser.parse(data: "//scriptlet('ubo-rc.js', 'cookie--not-set', ', stay')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "ubo-rc.js")
        XCTAssertEqual(result?.json, "{\"name\":\"ubo-rc.js\",\"args\":[\"cookie--not-set\",\", stay\"]}")
    }
}
