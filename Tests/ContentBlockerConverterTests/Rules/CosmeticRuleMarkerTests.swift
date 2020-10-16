import Foundation

import XCTest
@testable import ContentBlockerConverter

final class CosmeticRuleMarkerTests: XCTestCase {
    func testNoMarker() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "banner");
        
        XCTAssertEqual(result.index, -1);
        XCTAssertEqual(result.marker, nil);
    }
    
    func testElementHiding() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "##.banner");
        
        XCTAssertEqual(result.index, 0);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.ElementHiding);
    }
    
    func testElementHidingException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#@#.banner");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.ElementHidingException);
    }
    
    func testElementHidingExtCSS() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#?#.textad");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.ElementHidingExtCSS);
    }
    
    func testElementHidingExtCSSException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.com#@?#h3:contains(cookies)");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.ElementHidingExtCSSException);
    }
    
    func testCss() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#$#.textad { visibility: hidden; }");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.Css);
    }
    
    func testCssException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.com#@$#h3:contains(cookies) { display: none!important; }");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.CssException);
    }
    
    func testCssExtCSS() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.com#$?#h3:contains(cookies) { display: none!important; }");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.CssExtCSS);
    }
    
    func testCssExtCSSException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.com#@$?#h3:contains(cookies) { display: none!important; }");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.CssExtCSSException);
    }
    
    func testJs() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#%#test");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.Js);
    }
    
    func testJsException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org#@%#test");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.JsException);
    }
    
    func testHtml() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org$$script[data-src=\"banner\"]");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.Html);
    }
    
    func testHtmlException() {
        let result = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: "example.org$@$script[data-src=\"banner\"]");
        
        XCTAssertEqual(result.index, 11);
        XCTAssertEqual(result.marker, CosmeticRuleMarker.HtmlException);
    }

    static var allTests = [
        ("testNoMarker", testNoMarker),
        ("testElementHiding", testElementHiding),
        ("testElementHidingException", testElementHidingException),
        ("testElementHidingExtCSS", testElementHidingExtCSS),
        ("testElementHidingExtCSSException", testElementHidingExtCSSException),
        ("testCss", testCss),
        ("testCssException", testCssException),
        ("testCssExtCSS", testCssExtCSS),
        ("testCssExtCSSException", testCssExtCSSException),
        ("testJs", testJs),
        ("testJsException", testJsException),
        ("testHtml", testHtml),
        ("testHtmlException", testHtmlException),
    ]
}
