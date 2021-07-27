import XCTest
@testable import ContentBlockerConverter

final class QuickAllowlistClipperTests: XCTestCase {
    let START_URL_UNESCAPED = "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?";
    let converter = ContentBlockerConverter();
    
    func testRemoveAllowlistRule() {
        var ruleText: [String] = [
            "example.org##.banner",
            "@@||test.com$document",
        ];

        var conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult?.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult?.errorsCount, 0);

        var result = try! QuickAllowlistClipper().removeAllowlistRule(withText: "@@||test.com$document", conversionResult: conversionResult!);
        
        var decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        ruleText = ["@@||example.org$document"];
        conversionResult = converter.convertArray(rules: ruleText);
        XCTAssertEqual(conversionResult?.totalConvertedCount, 1);
        XCTAssertEqual(conversionResult?.errorsCount, 0);
        
        result = try! QuickAllowlistClipper().removeAllowlistRule(withText: "@@||example.org$document", conversionResult: conversionResult!);
        
        // check empty conversion result
        decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["domain.com"]);
        XCTAssertEqual(decoded[0].action.type, "ignore-previous-rules");
        
        ruleText = [
            "example1.org##.banner",
            "@@||test.com$document",
            "@@||example.com$document",
            "||example2.org",
        ];
        conversionResult = converter.convertArray(rules: ruleText);
        XCTAssertEqual(conversionResult?.totalConvertedCount, 4);
        XCTAssertEqual(conversionResult?.errorsCount, 0);
        
        result = try! QuickAllowlistClipper().removeAllowlistRule(withText: "@@||test.com$document", conversionResult: conversionResult!);
        
        decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 3);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example1.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "example2\\.org");
        XCTAssertEqual(decoded[1].action.type, "block");
        
        XCTAssertEqual(decoded[2].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
        
        result = try! QuickAllowlistClipper().removeAllowlistRule(withText: "@@||example.com$document", conversionResult: result);
        
        decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example1.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "example2\\.org");
        XCTAssertEqual(decoded[1].action.type, "block");
    }
    
    func testAddAllowlistRule() {
        let ruleText: [String] = [
            "test1.com##.banner",
            "||test2.com",
        ];

        let conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult?.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult?.errorsCount, 0);

        let result = try! QuickAllowlistClipper().addAllowlistRule(withText: "@@||example.org$document", conversionResult: conversionResult!);
        
        let decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 3);
        
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test1.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "test2\\.com");
        XCTAssertEqual(decoded[1].action.type, "block");
        
        XCTAssertEqual(decoded[2].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
        
    }

    static var allTests = [
        ("testRemoveAllowlistRule", testRemoveAllowlistRule),
        ("testAddAllowlistRule", testAddAllowlistRule),
    ]
}
