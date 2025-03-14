import ContentBlockerConverter
import XCTest

@testable import FilterEngine

/// These tests are required to make sure that `Schema.VERSION` is changed whenever
/// any changes are made to `FilterRule`, `FilterRuleStorage` or `FilterEngine`
/// serialization & deserialization code.
final class SchemaTests: XCTestCase {
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

    /// **IMPORTANT**
    /// Whenever any changes are made to the serialization code
    /// that make this test fail, you need to do two things:
    ///
    /// 1. Fix this test.
    /// 2. Increment `Schema.VERSION`.
    func testSchemaVersion() throws {
        XCTAssertEqual(1, Schema.VERSION)

        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/advanced-rules.txt")

        let content = try! String(contentsOf: resourceURL, encoding: String.Encoding.utf8)
        let rules = content.components(separatedBy: "\n")

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

        // Get reference file paths
        let referenceRulesFileURL = thisDirectory.appendingPathComponent(
            "Resources/reference-rules.bin"
        )
        let referenceEngineFileURL = thisDirectory.appendingPathComponent(
            "Resources/reference-engine.bin"
        )

        // Read temporary files
        let tempRulesData = try Data(contentsOf: tempRulesFileURL)
        let tempEngineData = try Data(contentsOf: tempIndexFileURL)

        // Read reference files
        let referenceRulesData = try Data(contentsOf: referenceRulesFileURL)
        let referenceEngineData = try Data(contentsOf: referenceEngineFileURL)

        // Uncomment to update reference files
        // try tempRulesData.write(to: referenceRulesFileURL)
        // try tempEngineData.write(to: referenceEngineFileURL)

        // Compare the files
        XCTAssertEqual(
            tempRulesData,
            referenceRulesData,
            "Rules file content has changed. Update reference-rules.bin and increment Schema.VERSION."
        )
        XCTAssertEqual(
            tempEngineData,
            referenceEngineData,
            "Engine file content has changed. Update reference-engine.bin and increment Schema.VERSION."
        )
    }
}
