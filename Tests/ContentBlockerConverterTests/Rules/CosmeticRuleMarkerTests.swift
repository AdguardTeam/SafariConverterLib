import Foundation
import XCTest

@testable import ContentBlockerConverter

final class CosmeticRuleMarkerTests: XCTestCase {
    func testNoMarker() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "banner")

        XCTAssertEqual(result.index, -1)
        XCTAssertEqual(result.marker, nil)
    }

    func testElementHiding() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "##.banner")

        XCTAssertEqual(result.index, 0)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.elementHiding)
    }

    func testElementHidingException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#@#.banner")

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.elementHidingException)
    }

    func testElementHidingExtCSS() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#?#.textad")

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.elementHidingExtCSS)
    }

    func testElementHidingExtCSSException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.com#@?#h3:contains(cookies)"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.elementHidingExtCSSException)
    }

    func testCss() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.org#$#.textad { visibility: hidden; }"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.css)
    }

    func testCssException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.com#@$#h3:contains(cookies) { display: none!important; }"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.cssException)
    }

    func testCssExtCSS() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.com#$?#h3:contains(cookies) { display: none!important; }"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.cssExtCSS)
    }

    func testCssExtCSSException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.com#@$?#h3:contains(cookies) { display: none!important; }"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.cssExtCSSException)
    }

    func testJs() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#%#test")

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.javascript)
    }

    func testJsException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#@%#test")

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.javascriptException)
    }

    func testHtml() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.org$$script[data-src=\"banner\"]"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.html)
    }

    func testHtmlException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(
            ruleText: "example.org$@$script[data-src=\"banner\"]"
        )

        XCTAssertEqual(result.index, 11)
        XCTAssertEqual(result.marker, CosmeticRuleMarker.htmlException)
    }
}
