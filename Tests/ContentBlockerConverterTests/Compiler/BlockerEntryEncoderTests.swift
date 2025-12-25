import Foundation
import XCTest

@testable import ContentBlockerConverter

final class BlockerEntryEncoderTests: XCTestCase {
    private let encoder = BlockerEntryEncoder()

    func testEmpty() {
        let (result, _) = encoder.encode(entries: [BlockerEntry]())
        XCTAssertEqual(result, "[]")
    }

    func testSimpleEntry() throws {
        let converter = BlockerEntryFactory(
            errorsCounter: ErrorsCounter(),
            version: DEFAULT_SAFARI_VERSION
        )
        let rule = try NetworkRule(ruleText: "||example.com/path$domain=test.com")

        let entries = converter.createBlockerEntries(rule: rule)

        if let entries = entries {
            let (result, _) = encoder.encode(entries: entries)
            XCTAssertEqual(
                result,
                #"[{"trigger":{"url-filter":"^[^:]+://+([^:/]+\\.)?example\\.com\\/path","if-domain":["*test.com"]},"action":{"type":"block"}}]"#
            )
        }
    }

    func testRequestMethod() throws {
        let converter = BlockerEntryFactory(
            errorsCounter: ErrorsCounter(),
            version: SafariVersion.safari26
        )
        let rule = try NetworkRule(
            ruleText: "||example.com/path$domain=test.com,method=post",
            for: SafariVersion.safari26
        )

        let entries = converter.createBlockerEntries(rule: rule)

        if let entries = entries {
            let (result, _) = encoder.encode(entries: entries)
            XCTAssertEqual(
                result,
                #"[{"trigger":{"url-filter":"^[^:]+://+([^:/]+\\.)?example\\.com\\/path","request-method":"post","if-domain":["*test.com"]},"action":{"type":"block"}}]"#
            )
        }
    }

    func testFrameUrlEntry() throws {
        let converter = BlockerEntryFactory(
            errorsCounter: ErrorsCounter(),
            version: SafariVersion.safari26
        )
        let rule = try NetworkRule(ruleText: "||example.com/path$domain=test.*")

        let entries = converter.createBlockerEntries(rule: rule)

        if let entries = entries {
            let (result, _) = encoder.encode(entries: entries)
            XCTAssertEqual(
                result,
                #"[{"trigger":{"url-filter":"^[^:]+://+([^:/]+\\.)?example\\.com\\/path","if-frame-url":["^[^:]+://+([^:/]+\\.)?test\\.[^/:]+([/:?#].*)?$"]},"action":{"type":"block"}}]"#
            )
        }
    }
}
