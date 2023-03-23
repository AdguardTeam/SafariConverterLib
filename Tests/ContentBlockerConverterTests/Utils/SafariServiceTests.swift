import Foundation

import XCTest
@testable import ContentBlockerConverter

final class SafariServiceTests: XCTestCase {

    func testSafariServiceSupportedVersion() {
        var safariVersion = 13
        var safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari13)
        
        safariVersion = 14
        safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari14)
        
        safariVersion = 16
        safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari16)
    }
    
    func testSafariServiceUnsupportedVersion() {
        var safariVersion = 10
        var safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari13)
        
        safariVersion = 35
        safariVersionResolved = SafariVersion(rawValue: safariVersion);
        XCTAssertEqual(safariVersionResolved, .safari13)
    }
    
    static var allTests = [
        ("testSafariServiceSupportedVersion", testSafariServiceSupportedVersion),
        ("testSafariServiceUnsupportedVersion", testSafariServiceUnsupportedVersion),
    ]
}
