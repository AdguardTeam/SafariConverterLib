import Foundation

import XCTest
@testable import ContentBlockerConverter

final class SafariCbBuilderTests: XCTestCase {
    let testTrigger = BlockerEntry.Trigger(
        ifDomain: ["test_if_domain"],
        urlFilter: "test_url_filter",
        unlessDomain: ["test_unless_domain"]
    )

    let testAction = BlockerEntry.Action(
        type: "test_type",
        selector: nil
    )

    func assertEntry(actual: String?) -> Void {
        XCTAssertNotNil(actual);

        XCTAssertTrue(actual!.contains("\"url-filter\":\"test_url_filter\""));
        XCTAssertTrue(actual!.contains("test_unless_domain"));
        XCTAssertTrue(actual!.contains("test_if_domain"));
        XCTAssertTrue(actual!.contains("\"url-shortcut\":\"test_shortcut\""));

        XCTAssertTrue(actual!.contains("\"type\":\"test_type\""));
        XCTAssertTrue(actual!.contains("\"css\":\"test_css\""));
    }

    func testEmpty() {
        let result = SafariCbBuilder.buildCbJson(from: CompilationResult())

        XCTAssertNotNil(result)
        XCTAssertEqual(result.rulesCount, 0)
        XCTAssertEqual(result.discardedRulesCount, 0)
        XCTAssertEqual(result.json, ConversionResult.EMPTY_RESULT_JSON)
    }

    func testSimple() {
        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ]

        let compilationResult = CompilationResult(
            message: "test",
            cssBlockingWide: entries
        )

        let result = SafariCbBuilder.buildCbJson(from: compilationResult)

        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.discardedRulesCount, 0)

        assertEntry(actual: result.json)
    }

    func testOverlimit() {
        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction),
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];

        let compilationResult = CompilationResult(
            message: "test",
            cssBlockingWide: entries
        )

        let result = SafariCbBuilder.buildCbJson(from: compilationResult)

        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.discardedRulesCount, 1)
        assertEntry(actual: result.json)
    }

}
