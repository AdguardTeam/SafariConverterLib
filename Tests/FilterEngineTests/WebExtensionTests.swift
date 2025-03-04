import XCTest
import Foundation
import ContentBlockerConverter
@testable import FilterEngine

final class WebExtensionTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testBuildFilterEngine() throws {
        let sharedUserDefaults = EmptyDefaults(suiteName: #file)!

        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            sharedUserDefaults: sharedUserDefaults,
            version: SafariVersion.safari16_4
        )
        let engine = try! webExtension.buildFilterEngine(rules: "example.org###banner")
        let rules = engine.findAll(for: URL(string: "https://example.org/")!)

        XCTAssertEqual(rules.count, 1)
    }
}

class EmptyDefaults: UserDefaults {
    override func double(forKey defaultName: String) -> Double {
        0
    }

    override func integer(forKey defaultName: String) -> Int {
        0
    }

    override func set(_ value: Double, forKey defaultName: String) {
    }

    override func set(_ value: Int, forKey defaultName: String) {
    }
}
