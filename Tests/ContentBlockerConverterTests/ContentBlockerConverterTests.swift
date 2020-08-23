import XCTest
@testable import ContentBlockerConverter

final class ContentBlockerConverterTests: XCTestCase {
    func testEmpty() {
        
        let converter = ContentBlockerConverter();
        let result = converter.convertArray(rules: [""], limit: 1000, optimize: false, advancedBlocking: false);
        
        XCTAssertEqual(result?.totalConvertedCount, 0);
        XCTAssertEqual(result?.convertedCount, 0);
        XCTAssertEqual(result?.errorsCount, 0);
        XCTAssertEqual(result?.overLimit, false);
        XCTAssertEqual(result?.converted, "[\n\n]");
    }
    
//    QUnit.test("Convert a comment", function(assert) {
//        const ruleText = "! this is a comment";
//        const result = SafariContentBlockerConverter.convertArray([ruleText]);
//        assert.equal(0, result.convertedCount);
//
//        // Comments are simply ignored, that's why just a zero
//        assert.equal(0, result.errorsCount);
//    });
//
//    QUnit.test("Convert a $network rule", function(assert) {
//        const ruleText = "127.0.0.1$network";
//        const result = SafariContentBlockerConverter.convertArray([ruleText]);
//
//        assert.equal(0, result.convertedCount);
//        assert.equal(1, result.errorsCount);
//    });

    static var allTests = [
        ("testEmpty", testEmpty),
    ]
}
