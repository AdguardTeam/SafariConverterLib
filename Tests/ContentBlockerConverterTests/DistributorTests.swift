import Foundation

import XCTest
@testable import ContentBlockerConverter

// TODO(ameshkov): !!! Rewrite tests for Distributor
final class DistributorTests: XCTestCase {
    func testEmpty() {
        let builder = Distributor(
            limit: 0,
            advancedBlocking: true
        );
        
        let result = builder.createConversionResult(data: CompilationResult());
        
        XCTAssertNotNil(result);
        XCTAssertEqual(result.totalConvertedCount, 0);
        XCTAssertEqual(result.convertedCount, 0);
        XCTAssertEqual(result.errorsCount, 0);
        XCTAssertEqual(result.overLimit, false);
        XCTAssertEqual(result.converted, ConversionResult.EMPTY_RESULT_JSON);
    }
}

