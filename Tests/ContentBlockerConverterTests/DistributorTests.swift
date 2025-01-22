import Foundation

import XCTest
@testable import ContentBlockerConverter

final class DistributorTests: XCTestCase {
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
        let builder = Distributor(limit: 0)

        let result = builder.createConversionResult(data: CompilationResult())

        XCTAssertNotNil(result)
        XCTAssertEqual(result.totalConvertedCount, 0)
        XCTAssertEqual(result.convertedCount, 0)
        XCTAssertEqual(result.errorsCount, 0)
        XCTAssertEqual(result.overLimit, false)
        XCTAssertEqual(result.converted, ConversionResult.EMPTY_RESULT_JSON)
    }

    func testSimple() {
        let builder = Distributor(limit: 0)

        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction)
        ]

        let compilationResult = CompilationResult(
            message: "test",
            cssBlockingWide: entries
        )

        let result = builder.createConversionResult(data: compilationResult)

        XCTAssertEqual(result.totalConvertedCount, 1);
        XCTAssertEqual(result.convertedCount, 1);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.message, "test");

        assertEntry(actual: result.converted);
    }

    func testOverlimit() {
        let builder = Distributor(limit: 1)

        let entries = [
            BlockerEntry(trigger: testTrigger, action: testAction),
            BlockerEntry(trigger: testTrigger, action: testAction)
        ];

        let compilationResult = CompilationResult(
            message: "test",
            cssBlockingWide: entries
        )

        let result = builder.createConversionResult(data: compilationResult)

        XCTAssertEqual(result.totalConvertedCount, 2)
        XCTAssertEqual(result.convertedCount, 1)
        XCTAssertEqual(result.errorsCount, 1)
        XCTAssertEqual(result.overLimit, true)
        XCTAssertEqual(result.message, "test")
        assertEntry(actual: result.converted)
    }

}
