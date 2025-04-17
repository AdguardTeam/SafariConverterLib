import XCTest

@testable import ContentBlockerConverter

final class WebExtensionHelpersTests: XCTestCase {
    func testUserRuleIsAssociated() {
        var result = WebExtensionHelpers().userRuleIsAssociated(
            with: "test.com",
            "test.com##.logos"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(with: "test.co", "test.co.th##.logos")
        XCTAssertFalse(result)

        result = WebExtensionHelpers().userRuleIsAssociated(with: "test.com", "||test.com^$script")
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(with: "test.com", "||freetest.com")
        XCTAssertFalse(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "test.com",
            "||example.org^$script,domain=test.com"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "||example.org^$script,domain=test.com"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(with: "test.com", "!||test.com^$script")
        XCTAssertFalse(result)

        result = WebExtensionHelpers().userRuleIsAssociated(with: "test.com", "@@||test.com^")
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "test1.com",
            "||example.org^$script,domain=test1.com|test2.com"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "||1example.com^$image,domain=example.co|example.com.ru"
        )
        XCTAssertFalse(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "||example.org/js/*$script,domain=test1.com|test2.com"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "example.org#$#body{overflow:hidden !important}"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "example.org#$?#body:{overflow:hidden !important}"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "example.org#%#//scriptlet('abort-on-property-read', 'test')"
        )
        XCTAssertTrue(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "test.com",
            "example.org#%#//scriptlet('abort-on-property-read', 'test.com')"
        )
        XCTAssertFalse(result)

        result = WebExtensionHelpers().userRuleIsAssociated(
            with: "example.org",
            "example.org#%#window.__gaq = undefined;"
        )
        XCTAssertTrue(result)
    }

    func testConvertDomainToAllowlistRule() {
        let expected = "@@||example.org^$document"
        var result = WebExtensionHelpers().convertDomainToAllowlistRule("example.org")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertDomainToAllowlistRule("@@||example.org^$document")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertDomainToAllowlistRule("@@||example.org")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertDomainToAllowlistRule("example.org^$document")
        XCTAssertEqual(expected, result)
    }

    func testConvertAllowlistRuleToDomain() {
        let expected = "example.org"
        var result = WebExtensionHelpers().convertAllowlistRuleToDomain("@@||example.org^$document")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertAllowlistRuleToDomain("@@||example.org")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertAllowlistRuleToDomain("example.org^$document")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertAllowlistRuleToDomain("example.org")
        XCTAssertEqual(expected, result)
    }

    func testConvertDomainToInvertedAllowlistRule() {
        let expected = "@@||*$document,domain=~example.org"
        var result = WebExtensionHelpers().convertDomainToInvertedAllowlistRule("example.org")
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertDomainToInvertedAllowlistRule(
            "@@||*$document,domain=~example.org"
        )
        XCTAssertEqual(expected, result)
    }

    func testConvertInvertedAllowlistRuleToDomain() {
        let expected = "example.org"
        var result = WebExtensionHelpers().convertInvertedAllowlistRuleToDomain(
            "@@||*$document,domain=~example.org"
        )
        XCTAssertEqual(expected, result)

        result = WebExtensionHelpers().convertInvertedAllowlistRuleToDomain("example.org")
        XCTAssertEqual(expected, result)
    }
}
