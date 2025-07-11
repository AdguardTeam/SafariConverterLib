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

        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet(\"prevent-window-open\", \"1\", \"window1\")"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "prevent-window-open")
        XCTAssertEqual(result?.args, ["1", "window1"])
    }

    func testParseEdgeCases() throws {
        // Malformed: missing closing parenthesis
        XCTAssertThrowsError(
            try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet('name', 'arg'")
        )

        // Malformed: missing quotes around name
        XCTAssertThrowsError(
            try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet(name, 'arg')")
        )

        // Only whitespace after prefix
        XCTAssertThrowsError(try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet(   )"))

        // Escaped quotes inside argument
        var result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet('name', 'arg\\'s test')"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["arg's test"])

        // Different type of quotes inside argument
        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet('name', 'arg \" test')"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["arg \" test"])

        // Backslash in the argument
        result = try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet('name', '\\test')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["\\test"])

        // Empty arguments
        result = try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet('name', '', '')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["", ""])

        // Mixed single and double quotes
        result = try ScriptletParser.parse(
            cosmeticRuleContent: "//scriptlet(\"name\", 'arg1', \"arg2\")"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["arg1", "arg2"])

        // Extra commas (trailing)
        result = try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet('name', 'arg1',)")
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["arg1"])

        // Invalid prefix
        XCTAssertThrowsError(try ScriptletParser.parse(cosmeticRuleContent: "/scriptlet('name')"))

        // Nested parentheses in argument
        result = try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet('name', 'a(b)c')")
        XCTAssertNotNil(result)
        XCTAssertEqual(result.name, "name")
        XCTAssertEqual(result.args, ["a(b)c"])

        // No arguments
        XCTAssertThrowsError(try ScriptletParser.parse(cosmeticRuleContent: "//scriptlet()"))
    }
}
