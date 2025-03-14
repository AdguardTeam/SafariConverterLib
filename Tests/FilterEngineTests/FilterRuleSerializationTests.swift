import ContentBlockerConverter
import XCTest

@testable import FilterEngine

final class FilterRuleSerializationTests: XCTestCase {
    // Helper method to compare two FilterRule instances
    // because FilterRule is not Equatable by default.
    private func assertEqualRules(
        _ lhs: FilterRule,
        _ rhs: FilterRule,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            lhs.action.rawValue,
            rhs.action.rawValue,
            "action mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(
            lhs.urlPattern,
            rhs.urlPattern,
            "urlPattern mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(lhs.urlRegex, rhs.urlRegex, "urlRegex mismatch", file: file, line: line)
        XCTAssertEqual(
            lhs.thirdParty,
            rhs.thirdParty,
            "thirdParty mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(
            lhs.subdocument,
            rhs.subdocument,
            "subdocument mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(lhs.pathRegex, rhs.pathRegex, "pathRegex mismatch", file: file, line: line)
        XCTAssertEqual(lhs.priority, rhs.priority, "priority mismatch", file: file, line: line)
        XCTAssertEqual(
            lhs.permittedDomains,
            rhs.permittedDomains,
            "permittedDomains mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(
            lhs.restrictedDomains,
            rhs.restrictedDomains,
            "restrictedDomains mismatch",
            file: file,
            line: line
        )
        XCTAssertEqual(
            lhs.cosmeticContent,
            rhs.cosmeticContent,
            "cosmeticContent mismatch",
            file: file,
            line: line
        )
    }

    func testSerializeDeserializeBasicRule() throws {
        // Arrange: create a basic rule
        let networkRule = try NetworkRule(ruleText: "@@||example.com^$elemhide,domain=example.org")
        let originalRule = try FilterRule(from: networkRule)

        // Act: serialize toData() then deserialize
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert: ensure all fields match
        assertEqualRules(originalRule, decodedRule)
    }

    func testSerializeDeserializeMultipleActions() throws {
        // Arrange: create a rule with multiple actions and some optional fields
        let networkRule = try NetworkRule(ruleText: "@@||example.com^$elemhide,jsinject")
        let originalRule = try FilterRule(from: networkRule)

        // Act: serialize toData() then deserialize
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert: ensure we get the same rule after round-trip
        assertEqualRules(originalRule, decodedRule)
    }

    func testSerializeDeserializeEmptyFields() throws {
        // Arrange: create a rule with empty domains and no cosmetic content
        let cosmeticRule = try CosmeticRule(ruleText: "##.banner")
        let originalRule = try FilterRule(from: cosmeticRule)

        // Act
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert
        assertEqualRules(originalRule, decodedRule)
    }

    func testSerializeDeserializeThirdPartyModifier() throws {
        // Arrange: create a rule with third-party modifier
        let networkRule = try NetworkRule(ruleText: "@@||example.com^$elemhide,third-party")
        let originalRule = try FilterRule(from: networkRule)

        // Act
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert
        assertEqualRules(originalRule, decodedRule)
        XCTAssertEqual(decodedRule.thirdParty, true)
    }

    func testSerializeDeserializeFirstPartyModifier() throws {
        // Arrange: create a rule with first-party modifier
        let networkRule = try NetworkRule(ruleText: "@@||example.com^$elemhide,~third-party")
        let originalRule = try FilterRule(from: networkRule)

        // Act
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert
        assertEqualRules(originalRule, decodedRule)
        XCTAssertEqual(decodedRule.thirdParty, false)
    }

    func testSerializeDeserializeSubdocumentModifier() throws {
        // Arrange: create a rule with subdocument modifier
        let networkRule = try NetworkRule(ruleText: "@@||example.com^$elemhide,subdocument")
        let originalRule = try FilterRule(from: networkRule)

        // Act
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert
        assertEqualRules(originalRule, decodedRule)
        XCTAssertEqual(decodedRule.subdocument, true)
    }

    func testSerializeDeserializeRestrictSubdocumentModifier() throws {
        // Arrange: create a rule that restricts subdocuments
        let networkRule = try NetworkRule(ruleText: "@@||example.com^$elemhide,~subdocument")
        let originalRule = try FilterRule(from: networkRule)

        // Act
        let data = try originalRule.toData()
        let decodedRule = try FilterRule.fromData(data)

        // Assert
        assertEqualRules(originalRule, decodedRule)
        XCTAssertEqual(decodedRule.subdocument, false)
    }
}
