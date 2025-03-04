import Foundation

/// Simplified logger (only enabled when #DEBUG is defined)
public enum Logger {
    /// Flag to check if we're running in a test environment
    private static var isRunningTests: Bool = {
        return NSClassFromString("XCTest") != nil
    }()

    public static func log(_ message: String) {
        #if DEBUG
        // Don't log anything if we're running tests.
        // Comment this if you need to debug something.
        if !isRunningTests {
            print("\(message)")
        }
        #endif
    }
}
