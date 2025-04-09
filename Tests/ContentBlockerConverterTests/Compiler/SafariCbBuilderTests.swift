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
        selector: "test_selector"
    )

    func assertEntry(actual: String?) {
        XCTAssertNotNil(actual)

        XCTAssertTrue(actual!.contains("\"url-filter\":\"test_url_filter\""))
        XCTAssertTrue(actual!.contains("test_unless_domain"))
        XCTAssertTrue(actual!.contains("test_if_domain"))

        XCTAssertTrue(actual!.contains("\"type\":\"test_type\""))
        XCTAssertTrue(actual!.contains("\"selector\":\"test_selector\""))
    }

    func testEmpty() {
        let result = SafariCbBuilder.buildCbJson(
            from: CompilationResult(),
            maxRules: DEFAULT_SAFARI_VERSION.rulesLimit
        )

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
            cssBlockingWide: entries
        )

        let result = SafariCbBuilder.buildCbJson(
            from: compilationResult,
            maxRules: DEFAULT_SAFARI_VERSION.rulesLimit
        )

        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.discardedRulesCount, 0)

        assertEntry(actual: result.json)
    }

    func testOverlimit() {
        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction),
            BlockerEntry(trigger: testTrigger, action: testAction),
        ]

        let compilationResult = CompilationResult(
            cssBlockingWide: entries
        )

        let result = SafariCbBuilder.buildCbJson(from: compilationResult, maxRules: 1)

        XCTAssertEqual(result.rulesCount, 1)
        XCTAssertEqual(result.discardedRulesCount, 1)
        assertEntry(actual: result.json)
    }
}
