import Foundation
import XCTest

@testable import ContentBlockerConverter

final class ScriptletParserTests: XCTestCase {
    func testParse() throws {
        var result = try? ScriptletParser.parse(cosmeticRuleContent: "")
        XCTAssertNil(result)

        result = try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet(\"test-name\")")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-name")
        XCTAssertEqual(result?.args, [])

        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet(\"test-name\", \"test-arg\")"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-name")
        XCTAssertEqual(result?.args, ["test-arg"])

        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet(\"test-name\", 'test-arg')"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-name")
        XCTAssertEqual(result?.args, ["test-arg"])

        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet('remove-class', 'branding', 'div[class^=\"inner\"]')"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "remove-class")
        XCTAssertEqual(result?.args, ["branding", "div[class^=\"inner\"]"])

        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet('remove-class', 'test,comma')"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "remove-class")
        XCTAssertEqual(result?.args, ["test,comma"])

        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet('ubo-rc.js', 'cookie--not-set', ', stay')"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "ubo-rc.js")
        XCTAssertEqual(result?.args, ["cookie--not-set", ", stay"])
    }
}
