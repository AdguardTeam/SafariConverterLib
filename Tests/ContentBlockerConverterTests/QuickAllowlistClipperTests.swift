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

        var result = try! QuickAllowlistClipper().remove(rule: "@@||test.com$document", from: conversionResult!);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.totalConvertedCount, 1);
        
        var decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        ruleText = ["@@||example.org$document"];
        conversionResult = converter.convertArray(rules: ruleText);
        XCTAssertEqual(conversionResult?.totalConvertedCount, 1);
        XCTAssertEqual(conversionResult?.errorsCount, 0);
        
        result = try! QuickAllowlistClipper().remove(rule: "@@||example.org$document", from: conversionResult!);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.totalConvertedCount, 0);
        
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
        
        result = try! QuickAllowlistClipper().remove(rule: "@@||test.com$document", from: conversionResult!);
        XCTAssertEqual(result.convertedCount, 3);
        XCTAssertEqual(result.totalConvertedCount, 3);
        
        decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 3);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example1.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "example2\\.org");
        XCTAssertEqual(decoded[1].action.type, "block");
        
        XCTAssertEqual(decoded[2].trigger.ifDomain, ["*example.com"]);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
        
        result = try! QuickAllowlistClipper().remove(rule: "@@||example.com$document", from: result);
        XCTAssertEqual(result.convertedCount, 2);
        XCTAssertEqual(result.totalConvertedCount, 2);
        
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

        let result = try! QuickAllowlistClipper().addAllowlistRule(by: "example.org", to: conversionResult!);
        XCTAssertEqual(result.convertedCount, 3);
        XCTAssertEqual(result.totalConvertedCount, 3);
        
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
    
    func testAddInvertedAllowlistRule() {
        let ruleText: [String] = [
            "test1.com##.banner",
            "||test2.com",
        ];

        let conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult?.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult?.errorsCount, 0);

        let result = try! QuickAllowlistClipper().addInvertedAllowlistRule(by: "example.org", to: conversionResult!);
        XCTAssertEqual(result.convertedCount, 3);
        XCTAssertEqual(result.totalConvertedCount, 3);
        
        let decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 3);
        
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*test1.com"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
        
        XCTAssertEqual(decoded[1].trigger.urlFilter, START_URL_UNESCAPED + "test2\\.com");
        XCTAssertEqual(decoded[1].action.type, "block");
        
        XCTAssertNil(decoded[2].trigger.ifDomain);
        XCTAssertEqual(decoded[2].trigger.unlessDomain, ["*example.org"]);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");
    }
    
    func testRemoveInvertedAllowlistRule() {
        let ruleText: [String] = [
            "example.org##.banner",
            "@@||*$document,domain=~test.com",
        ];

        let conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult?.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult?.errorsCount, 0);

        let result = try! QuickAllowlistClipper().remove(rule: "@@||*$document,domain=~test.com", from: conversionResult!);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.totalConvertedCount, 1);
        
        let decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
    }

    static var allTests = [
        ("testRemoveAllowlistRule", testRemoveAllowlistRule),
        ("testAddAllowlistRule", testAddAllowlistRule),
        ("testAddInvertedAllowlistRule", testAddInvertedAllowlistRule),
        ("testRemoveInvertedAllowlistRule", testRemoveInvertedAllowlistRule),
    ]
}
