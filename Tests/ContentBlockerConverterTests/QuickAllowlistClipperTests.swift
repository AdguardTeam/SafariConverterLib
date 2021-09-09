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

        XCTAssertEqual(conversionResult.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        var result = try! QuickAllowlistClipper().remove(rule: "@@||test.com$document", from: conversionResult);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.totalConvertedCount, 1);

        var decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");

        ruleText = ["@@||example.org$document"];
        conversionResult = converter.convertArray(rules: ruleText);
        XCTAssertEqual(conversionResult.totalConvertedCount, 1);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        result = try! QuickAllowlistClipper().remove(rule: "@@||example.org$document", from: conversionResult);
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
        XCTAssertEqual(conversionResult.totalConvertedCount, 4);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        result = try! QuickAllowlistClipper().remove(rule: "@@||test.com$document", from: conversionResult);
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

        ruleText = [
            "@@||test.com$document",
            "example1.org##.banner",
            "@@||test.com$document",
            "@@||example.com$document",
            "@@||test.com$document",
            "||example2.org",
        ];

        conversionResult = converter.convertArray(rules: ruleText);
        XCTAssertEqual(conversionResult.totalConvertedCount, 6);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        result = try! QuickAllowlistClipper().remove(rule: "@@||test.com$document", from: conversionResult);
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
    }

    func testAddAllowlistRule() {
        var ruleText: [String] = [
            "test1.com##.banner",
            "||test2.com",
        ];

        var conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        let result = try! QuickAllowlistClipper().addAllowlistRule(by: "example.org", to: conversionResult);
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

        ruleText = [
            "test1.com##.banner",
            "@@||example.org$document",
            "||test2.com",
        ];

        conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 3);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        // try to add existing rule
        XCTAssertThrowsError(try QuickAllowlistClipper().addAllowlistRule(by: "example.org", to: conversionResult));
    }

    func testAddInvertedAllowlistRule() {
        var ruleText: [String] = [
            "test1.com##.banner",
            "||test2.com",
        ];

        var conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        let result = try! QuickAllowlistClipper().addInvertedAllowlistRule(by: "example.org", to: conversionResult);
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

        ruleText = [
            "test1.com##.banner",
            "@@||*$document,domain=~example.org",
            "||test2.com",
        ];

        conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 3);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        // try to add existing rule
        XCTAssertThrowsError(try QuickAllowlistClipper().addInvertedAllowlistRule(by: "example.org", to: conversionResult));
    }

    func testRemoveInvertedAllowlistRule() {
        let ruleText: [String] = [
            "example.org##.banner",
            "@@||*$document,domain=~test.com",
        ];

        let conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        let result = try! QuickAllowlistClipper().removeInvertedAllowlistRule(by: "test.com", from: conversionResult);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.totalConvertedCount, 1);

        let decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 1);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");
    }

    func testReplaceRuleMethod() {
        var ruleText: [String] = [
            "example.org##.banner",
            "@@||*$document,domain=~test.com",
        ];

        var conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        var result = try! QuickAllowlistClipper().replace(rule: "@@||*$document,domain=~test.com", with: "@@||*$document,domain=~example.com", in: conversionResult);
        XCTAssertEqual(result.convertedCount, 2);
        XCTAssertEqual(result.totalConvertedCount, 2);

        var decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 2);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");

        XCTAssertNil(decoded[1].trigger.ifDomain);
        XCTAssertEqual(decoded[1].trigger.unlessDomain, ["*example.com"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");

        ruleText = [
            "example.org##.banner",
            "@@||*$document,domain=~test.com",
        ];

        conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 2);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        // conversion result doesn't contain rule for replace
        XCTAssertThrowsError(try QuickAllowlistClipper().replace(rule: "@@||*$document,domain=~example.com", with: "@@||*$document,domain=~test.com", in: conversionResult));

        ruleText = [
            "@@||*$document,domain=~test.com",
            "@@||*$document,domain=~test.com",
            "example.org##.banner",
        ];

        conversionResult = converter.convertArray(rules: ruleText);

        XCTAssertEqual(conversionResult.totalConvertedCount, 3);
        XCTAssertEqual(conversionResult.errorsCount, 0);

        result = try! QuickAllowlistClipper().replace(rule: "@@||*$document,domain=~test.com", with: "@@||*$document,domain=~example.com", in: conversionResult);
        XCTAssertEqual(result.convertedCount, 3);
        XCTAssertEqual(result.totalConvertedCount, 3);

        decoded = try! ContentBlockerConverterTests().parseJsonString(json: result.converted);
        XCTAssertEqual(decoded.count, 3);
        XCTAssertEqual(decoded[0].trigger.ifDomain, ["*example.org"]);
        XCTAssertEqual(decoded[0].action.type, "css-display-none");
        XCTAssertEqual(decoded[0].action.selector, ".banner");

        XCTAssertNil(decoded[1].trigger.ifDomain);
        XCTAssertEqual(decoded[1].trigger.unlessDomain, ["*example.com"]);
        XCTAssertEqual(decoded[1].action.type, "ignore-previous-rules");

        XCTAssertNil(decoded[2].trigger.ifDomain);
        XCTAssertEqual(decoded[2].trigger.unlessDomain, ["*example.com"]);
        XCTAssertEqual(decoded[2].action.type, "ignore-previous-rules");

    }
    
    func testAllowlistContains() {
        var rulesText: [String] = [
            "@@||example.org^$document",
            "@@||test1.com^$document",
            "@@||test2.com^$document",
            "@@||test3.com^$document",
        ];
        
        var result = QuickAllowlistClipper().allowlistContains(domain: "test2.com", rulesText);
        XCTAssertTrue(result);
        
        rulesText = [
            "@@||example.org^$document",
            "@@||test1.com^$document",
            "@@||test2.com^$document",
            "! @@||test3.com^$document",
        ];
        
        result = QuickAllowlistClipper().allowlistContains(domain: "test3.com", rulesText);
        XCTAssertFalse(result);
        
        rulesText = [
            "@@||example.org^$document",
            "@@||test1.com$document",
            "@@||test2.com^$document",
            "@@||test3.com^$document",
        ];
        
        result = QuickAllowlistClipper().allowlistContains(domain: "test1.com", rulesText);
        XCTAssertTrue(result);
        
        rulesText = [
            "test1.com##.banner",
            "||test2.com",
            "@@||*$document,domain=~test3.com",
        ];
        
        let result1 = QuickAllowlistClipper().allowlistContains(domain: "test1.com", rulesText);
        XCTAssertFalse(result1);
        
        let result2 = QuickAllowlistClipper().allowlistContains(domain: "test2.com", rulesText);
        XCTAssertFalse(result2);
        
        let result3 = QuickAllowlistClipper().allowlistContains(domain: "test3.com", rulesText);
        XCTAssertFalse(result3);
    }
    
    func testInvertedAllowlistContains() {
        var rulesText: [String] = [
            "@@||*$document,domain=~test1.com",
            "@@||*$document,domain=~test2.com",
            "@@||*$document,domain=~test3.com",
            "@@||*$document,domain=~test4.com",
        ];
        
        var result = QuickAllowlistClipper().invertedAllowlistContains(domain: "test3.com", rulesText);
        XCTAssertTrue(result);
        
        rulesText = [
            "@@||*$document,domain=~test1.com",
            "! @@||*$document,domain=~test2.com",
            "@@||*$document,domain=~test3.com",
            "@@||*$document,domain=~test4.com",
        ];
        
        result = QuickAllowlistClipper().invertedAllowlistContains(domain: "test2.com", rulesText);
        XCTAssertFalse(result);
        
        rulesText = [
            "test1.com##.banner",
            "||test2.com",
            "@@||test3.com^$document",
            "@@||*$document,domain=~test4.com",
        ];
        
        let result1 = QuickAllowlistClipper().invertedAllowlistContains(domain: "test1.com", rulesText);
        XCTAssertFalse(result1);
        
        let result2 = QuickAllowlistClipper().invertedAllowlistContains(domain: "test2.com", rulesText);
        XCTAssertFalse(result2);
        
        let result3 = QuickAllowlistClipper().invertedAllowlistContains(domain: "test3.com", rulesText);
        XCTAssertFalse(result3);
    }
    
    static var allTests = [
        ("testRemoveAllowlistRule", testRemoveAllowlistRule),
        ("testAddAllowlistRule", testAddAllowlistRule),
        ("testAddInvertedAllowlistRule", testAddInvertedAllowlistRule),
        ("testRemoveInvertedAllowlistRule", testRemoveInvertedAllowlistRule),
        ("testReplaceRuleMethod", testReplaceRuleMethod),
        ("testAllowlistContains", testAllowlistContains),
        ("testInvertedAllowlistContains", testInvertedAllowlistContains),
    ]
}
