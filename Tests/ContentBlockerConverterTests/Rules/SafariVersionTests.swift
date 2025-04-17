import Foundation
import XCTest

@testable import ContentBlockerConverter

final class SafariVersionTests: XCTestCase {
    func testSafariVersionSupportedVersion() {
        var safariVersion = 13.0
        var safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari13)
        XCTAssertFalse(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 14.0
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari14)
        XCTAssertFalse(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 15.0
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari15)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 15.1
        safariVersionResolved = SafariVersion(safariVersion)
        print(safariVersionResolved)
        XCTAssertEqual(safariVersionResolved, .safari15)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 16.0
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 16.2
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 16.4
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16_4)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertTrue(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 17
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16_4Plus(safariVersion))
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertTrue(safariVersionResolved.isSafari16_4orGreater())
    }

    func testSafariVersionUnsupportedVersion() {
        var safariVersion = 10.1
        var safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari13)
        XCTAssertFalse(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16_4orGreater())

        safariVersion = 35.0
        safariVersionResolved = SafariVersion(safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16_4Plus(safariVersion))
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertTrue(safariVersionResolved.isSafari16_4orGreater())
    }
}
