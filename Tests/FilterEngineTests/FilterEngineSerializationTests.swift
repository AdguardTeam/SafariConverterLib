import ContentBlockerConverter
import Foundation
import XCTest

@testable import FilterEngine

final class FilterEngineSerializationTests: XCTestCase {
    private var tempDirectory: URL!
    private var tempRulesFileURL: URL!
    private var tempIndexFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        // File where initial FilterRuleStorage is stored:
        tempRulesFileURL = tempDirectory.appendingPathComponent("filterRules.bin")

        // File where the trie indexes will be written:
        tempIndexFileURL = tempDirectory.appendingPathComponent("index.bin")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testWriteAndReadIndexFile() throws {
        // Arrange: Create a small set of rules, ensuring one has a "permittedDomain",
        // another is purely cosmetic (no domain, thus ends in tail), etc.
        let lines = [
            // This should create a rule with permittedDomains = ["example.org"]
            "@@||example.org^$document",
            // This is a cosmetic rule with no domain => tail
            "##.banner",
        ]

        // Build a FilterRuleStorage from these lines
        let storage = try FilterRuleStorage(
            from: lines,
            for: .safari16_4,
            fileURL: tempRulesFileURL
        )

        // Create the first engine (in-memory tries), then write out the trie data
        let engine1 = try FilterEngine(storage: storage)
        try engine1.write(to: tempIndexFileURL)

        // Create a second engine by reading back the trie data from file
        let engine2 = try FilterEngine(storage: storage, indexFileURL: tempIndexFileURL)

        // Act: Compare some lookups between the two engines

        // 1) Query a URL that matches the "@@||example.org" domain-based rule
        let url1 = URL(string: "http://example.org/banner")!
        let rules1Engine1 = engine1.findAll(for: Request(url: url1))
        let rules1Engine2 = engine2.findAll(for: Request(url: url1))

        // 2) Query a URL that doesn't match the domain-based rule but might match the cosmetic rule
        let url2 = URL(string: "http://another-site.net/ads")!
        let rules2Engine1 = engine1.findAll(for: Request(url: url2))
        let rules2Engine2 = engine2.findAll(for: Request(url: url2))

        // Assert: The sets of rules returned by each engine should match
        XCTAssertEqual(
            rules1Engine1.count,
            rules1Engine2.count,
            "Mismatch in rules for example.org/banner"
        )
        XCTAssertEqual(
            rules2Engine1.count,
            rules2Engine2.count,
            "Mismatch in rules for another-site.net/ads"
        )

        // For extra confidence, we can confirm each corresponding rule is the same:
        for (r1, r2) in zip(rules1Engine1, rules1Engine2) {
            XCTAssertEqual(r1.action, r2.action, "Actions differ for matched domain rule")
            XCTAssertEqual(r1.cosmeticContent, r2.cosmeticContent)
        }
        for (r1, r2) in zip(rules2Engine1, rules2Engine2) {
            XCTAssertEqual(r1.action, r2.action, "Actions differ for matched tail rule")
            XCTAssertEqual(r1.cosmeticContent, r2.cosmeticContent)
        }
    }

    /// Test how fast the engine and storage can be serialized to a file.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~2.488 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceSerialization() {
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/advanced-rules.txt")

        let content = try! String(contentsOf: resourceURL, encoding: String.Encoding.utf8)
        let rules = content.components(separatedBy: "\n")

        self.measure {
            // Build a FilterRuleStorage from the rules
            let storage = try? FilterRuleStorage(
                from: rules,
                for: .safari16_4,
                fileURL: self.tempRulesFileURL
            )
            guard let storage = storage else {
                XCTFail("Failed to build FilterRuleStorage")
                return
            }

            // Build engine
            let engine = try? FilterEngine(storage: storage)
            guard let engine = engine else {
                XCTFail("Failed to build FilterEngine")
                return
            }

            // Serialize the engine to a file
            do {
                try engine.write(to: self.tempRulesFileURL)
            } catch {
                XCTFail("Failed to write engine: \(error)")
            }
        }
    }

    /// Test how fast the engine can be deserialized.
    ///
    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.001 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformanceDeserialization() {
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/advanced-rules.txt")

        let content = try! String(contentsOf: resourceURL, encoding: String.Encoding.utf8)
        let rules = content.components(separatedBy: "\n")

        do {
            // Build a FilterRuleStorage from the rules
            let storage = try FilterRuleStorage(
                from: rules,
                for: .safari16_4,
                fileURL: self.tempRulesFileURL
            )

            // Build engine
            let engine = try FilterEngine(storage: storage)

            // Serialize the engine to a file
            try engine.write(to: self.tempIndexFileURL)
        } catch {
            XCTFail("Failed to initialize engine and storage files: \(error)")
        }

        self.measure {
            do {
                // Deserialize the FilterRuleStorage.
                let storage = try FilterRuleStorage(fileURL: self.tempRulesFileURL)

                // Deserialize the engine.
                _ = try FilterEngine(storage: storage, indexFileURL: self.tempIndexFileURL)
            } catch {
                XCTFail("Failed to init storage or engine: \(error)")
            }
        }
    }
}
