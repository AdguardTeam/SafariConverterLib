import Foundation

import XCTest
@testable import ContentBlockerConverter

final class SafariServiceTests: XCTestCase {

    func testSafariServiceSupportedVersion() {
        var safariVersion = 13
        var safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari13)
        XCTAssertFalse(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16orGreater())

        safariVersion = 14
        safariVersionResolved = SafariVersion(rawValue: safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari14)
        XCTAssertFalse(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16orGreater())

        safariVersion = 15
        safariVersionResolved = SafariVersion(rawValue: safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari15)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16orGreater())

        safariVersion = 16
        safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari16)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertTrue(safariVersionResolved.isSafari16orGreater())
        
        safariVersion = 17
        safariVersionResolved = SafariVersion(rawValue: safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16Plus)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertTrue(safariVersionResolved.isSafari16orGreater())
    }

    func testSafariServiceUnsupportedVersion() {
        var safariVersion = 10
        var safariVersionResolved = SafariVersion(rawValue: safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari13)
        XCTAssertFalse(safariVersionResolved.isSafari15orGreater())
        XCTAssertFalse(safariVersionResolved.isSafari16orGreater())

        safariVersion = 35
        safariVersionResolved = SafariVersion(rawValue: safariVersion)
        XCTAssertEqual(safariVersionResolved, .safari16Plus)
        XCTAssertTrue(safariVersionResolved.isSafari15orGreater())
        XCTAssertTrue(safariVersionResolved.isSafari16orGreater())
    }

    static var allTests = [
        ("testSafariServiceSupportedVersion", testSafariServiceSupportedVersion),
        ("testSafariServiceUnsupportedVersion", testSafariServiceUnsupportedVersion),
    ]
}
