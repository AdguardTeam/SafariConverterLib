import Foundation

import XCTest
@testable import ContentBlockerConverter

final class ConverterTests: XCTestCase {
    func testConvertScriptRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isScript = true;
        rule.script = "test script";

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        // TODO: Check
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
//        XCTAssertEqual(result!.trigger.ifDomain);
//        XCTAssertEqual(result!.trigger.unlessDomain);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "script");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, "test script");
        XCTAssertEqual(result!.action.scriptlet, nil);
        XCTAssertEqual(result!.action.scriptletParam, nil);
        
        // TODO: Test whitelist
    }
    
    func testConvertScriptletRule() {
        let converter = Converter(advancedBlockingEnabled: true);

        let rule = CosmeticRule();
        rule.isScriptlet = true;
        rule.scriptlet = "test scriptlet";
        rule.scriptletParam = "test scriptlet param";

        let result = converter.convertRuleToBlockerEntry(rule: rule);
        XCTAssertNotNil(result);
        // TODO: Check
        XCTAssertEqual(result!.trigger.urlFilter, ".*");
//        XCTAssertEqual(result!.trigger.ifDomain);
//        XCTAssertEqual(result!.trigger.unlessDomain);
        XCTAssertEqual(result!.trigger.shortcut, nil);
        XCTAssertEqual(result!.trigger.regex, nil);

        XCTAssertEqual(result!.action.type, "scriptlet");
        XCTAssertEqual(result!.action.selector, nil);
        XCTAssertEqual(result!.action.css, nil);
        XCTAssertEqual(result!.action.script, nil);
        XCTAssertEqual(result!.action.scriptlet, "test scriptlet");
        XCTAssertEqual(result!.action.scriptletParam, "test scriptlet param");
        
        // TODO: Test whitelist
    }

    static var allTests = [
        ("testConvertScriptRule", testConvertScriptRule),
        ("testConvertScriptletRule", testConvertScriptletRule),
    ]
}
