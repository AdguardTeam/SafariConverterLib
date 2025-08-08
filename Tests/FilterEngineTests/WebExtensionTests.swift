import ContentBlockerConverter
import Foundation
import XCTest

@testable import FilterEngine

final class WebExtensionTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    /// Test that the filter engine is correctly built.
    func testBuildFilterEngine() throws {
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )
        let engine = try webExtension.buildFilterEngine(rules: "example.org###banner")
        let request = Request(url: URL(string: "https://example.org/")!)
        let rules = engine.findAll(for: request)

        XCTAssertEqual(rules.count, 1, "Expected 1 rule to be selected")

        // Check meta file contents
        let metaURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR, isDirectory: true)
            .appendingPathComponent(Schema.ENGINE_META_FILE_NAME)
        let meta = try EngineMeta.read(from: metaURL, lock: nil)
        XCTAssertGreaterThan(meta.timestamp, 0, "Engine timestamp must be saved to meta file")
        XCTAssertEqual(
            meta.schemaVersion,
            Int32(Schema.VERSION),
            "Schema version must be saved to meta file"
        )
    }

    /// Test that nothiing is found when the engine was not built.
    func testLookupNoEngine() throws {
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Don't build an engine, try selecting from it right away.
        let pageUrl = URL(string: "https://example.org/")!
        let conf = webExtension.lookup(pageUrl: pageUrl, topUrl: nil)

        // Nothing should be selected.
        XCTAssertNil(conf, "Expected no rules to be selected")
    }

    /// Test that empty config found when engine is built from an empty string.
    func testLookupEmptyEngine() throws {
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Make sure the filter engine was built and serialized.
        _ = try builder.buildFilterEngine(rules: "")

        // Now create a new WebExtension instance that will be used
        // to deserialize engine.
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        let pageUrl = URL(string: "https://example.org/")!
        let conf = webExtension.lookup(pageUrl: pageUrl, topUrl: nil)

        XCTAssertNotNil(conf, "Expected configuration to be selected (but empty)")

        guard let conf = conf else { return }

        XCTAssertTrue(conf.css.isEmpty, "CSS array should be empty")
        XCTAssertTrue(conf.extendedCss.isEmpty, "Extended CSS array should be empty")
        XCTAssertTrue(conf.js.isEmpty, "JS array should be empty")
        XCTAssertTrue(conf.scriptlets.isEmpty, "Scriptlets array should be empty")
        XCTAssertGreaterThan(conf.engineTimestamp, 0, "Engine timestamp should be set")
    }

    /// Test that lookup works as expected and returns a valid configuration.
    func testLookup() throws {
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Make sure the filter engine was built and serialized.
        let filterList = [
            "example.org###banner",
            "example.org#$##banner { visibility: hidden }",
            "example.org#?##banner:has(div)",
            "example.org#%#console.log('test')",
            "example.org#%#//scriptlet('log', 'test')",
        ].joined(separator: "\n")
        _ = try builder.buildFilterEngine(rules: filterList)

        // Now create a new WebExtension instance that will be used
        // to deserialize engine.
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        let pageUrl = URL(string: "https://example.org/")!
        let conf = webExtension.lookup(pageUrl: pageUrl, topUrl: nil)

        XCTAssertNotNil(conf, "Expected configuration to be selected")

        guard let conf = conf else { return }

        XCTAssertEqual(conf.css, ["#banner", "#banner { visibility: hidden }"])
        XCTAssertEqual(conf.extendedCss, ["#banner:has(div)"])
        XCTAssertEqual(conf.js, ["console.log('test')"])
        XCTAssertEqual(
            conf.scriptlets,
            [
                WebExtension.Scriptlet(name: "log", args: ["test"])
            ]
        )
        XCTAssertGreaterThan(conf.engineTimestamp, 0, "Engine timestamp should be set")
    }

    func testLookupWithRebuild() throws {
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Make sure the filter engine was built and serialized.
        let filterList = [
            "example.org###banner",
            "example.org#$##banner { visibility: hidden }",
            "example.org#?##banner:has(div)",
            "example.org#%#console.log('test')",
            "example.org#%#//scriptlet('log', 'test')",
        ].joined(separator: "\n")
        _ = try builder.buildFilterEngine(rules: filterList)

        // Emulate a situation that makes it necessary to rebuild the engine.
        // Overwrite the meta file with an old schema version.
        let metaURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.ENGINE_META_FILE_NAME)
        var oldMeta = try EngineMeta.read(from: metaURL, lock: nil)
        oldMeta = EngineMeta(timestamp: oldMeta.timestamp, schemaVersion: Int32(Schema.VERSION - 1))
        try EngineMeta.write(meta: oldMeta, to: metaURL, lock: nil)

        // Save the engine timestamp so that we could compare it to the one after rebuilding.
        let firstBuildTimestamp = oldMeta.timestamp
        // Sleep for a short period to make sure that the new timestamp will be newer.
        Thread.sleep(forTimeInterval: 0.01)

        // Make sure that the engine files are no more.
        let filterEngineFileURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.FILTER_ENGINE_INDEX_FILE_NAME)
        let filterRuleStorageFileURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.FILTER_RULE_STORAGE_FILE_NAME)
        try FileManager.default.removeItem(at: filterEngineFileURL)
        try FileManager.default.removeItem(at: filterRuleStorageFileURL)

        // Now create a new WebExtension instance that will be used
        // to deserialize engine.
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        let pageUrl = URL(string: "https://example.org/")!
        let conf = webExtension.lookup(pageUrl: pageUrl, topUrl: nil)

        XCTAssertNotNil(conf, "Expected configuration to be selected")

        guard let conf = conf else { return }

        XCTAssertEqual(conf.css, ["#banner", "#banner { visibility: hidden }"])
        XCTAssertEqual(conf.extendedCss, ["#banner:has(div)"])
        XCTAssertEqual(conf.js, ["console.log('test')"])
        XCTAssertEqual(
            conf.scriptlets,
            [
                WebExtension.Scriptlet(name: "log", args: ["test"])
            ]
        )
        XCTAssertNotEqual(
            conf.engineTimestamp,
            firstBuildTimestamp,
            "Engine timestamp should be newer"
        )
        XCTAssertGreaterThan(conf.engineTimestamp, 0, "Engine timestamp should be set")
    }

    func testMigrationMarkerPreventsRebuildAndLookup() throws {
        // Arrange: Build and serialize engine
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )
        let filterList = [
            "example.org###banner",
            "example.org#$##banner { visibility: hidden }",
            "example.org#?##banner:has(div)",
            "example.org#%#console.log('test')",
            "example.org#%#//scriptlet('log', 'test')",
        ].joined(separator: "\n")
        _ = try builder.buildFilterEngine(rules: filterList)

        // Emulate a situation that makes it necessary to rebuild the engine.
        let metaURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.ENGINE_META_FILE_NAME)
        var oldMeta = try EngineMeta.read(from: metaURL, lock: nil)
        oldMeta = EngineMeta(timestamp: oldMeta.timestamp, schemaVersion: Int32(Schema.VERSION - 1))
        try EngineMeta.write(meta: oldMeta, to: metaURL, lock: nil)

        // Remove engine/index files to force rebuild
        let filterEngineFileURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.FILTER_ENGINE_INDEX_FILE_NAME)
        let filterRuleStorageFileURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.FILTER_RULE_STORAGE_FILE_NAME)
        try FileManager.default.removeItem(at: filterEngineFileURL)
        try FileManager.default.removeItem(at: filterRuleStorageFileURL)

        // Create migration marker file
        let markerURL =
            tempDirectory
            .appendingPathComponent(Schema.BASE_DIR)
            .appendingPathComponent(Schema.MIGRATION_MARKER_FILE_NAME)
        FileManager.default.createFile(atPath: markerURL.path, contents: nil, attributes: nil)

        // Act: Try to lookup, which would normally trigger a rebuild
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )
        let pageUrl = URL(string: "https://example.org/")!
        let conf = webExtension.lookup(pageUrl: pageUrl, topUrl: nil)

        // Assert: Should not rebuild, lookup returns nil, marker file still exists
        XCTAssertNil(
            conf,
            "Lookup should return nil if migration marker exists and engine files are missing"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: markerURL.path),
            "Migration marker should still exist after prevented rebuild"
        )
    }

    /// Test that lookup properly handles subdocument and third-party detection.
    func testLookupWithSubdocumentAndThirdParty() throws {
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Create rules that specifically target subdocuments
        let filterList = [
            // Disable cosmetics on example.org iframes
            "@@||example.org^$subdocument,elemhide",
            // Cosmetic rule for example.com
            "example.org###banner",
            // Disable cosmetics on example.com iframes in third-party context
            "@@||example.com^$subdocument,elemhide,third-party",
            // Cosmetic rule for example.com
            "example.com###banner",
        ].joined(separator: "\n")

        _ = try builder.buildFilterEngine(rules: filterList)

        // Create a new WebExtension instance for lookups
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Test case 1: Main document (no subdocument)
        let mainPageUrl = URL(string: "https://example.org/")!
        let mainPageConf = webExtension.lookup(pageUrl: mainPageUrl, topUrl: nil)

        XCTAssertNotNil(mainPageConf, "Expected configuration to be selected for main page")
        guard let mainPageConf = mainPageConf else { return }

        // Only the regular rule should apply to the main document
        XCTAssertEqual(
            mainPageConf.css,
            ["#banner"],
            "Only one CSS rule should apply to main document"
        )

        // Test case 2: Subdocument (third-party=false)
        let sameDomainIframeUrl = URL(string: "https://example.org/")!
        let sameDomainIframeConf = webExtension.lookup(
            pageUrl: sameDomainIframeUrl,
            topUrl: mainPageUrl
        )

        XCTAssertNotNil(
            sameDomainIframeConf,
            "Expected configuration to be selected for same-domain iframe"
        )
        guard let sameDomainIframeConf = sameDomainIframeConf else { return }

        // Cosmetic rules should be disabled by the elemhide rule for iframes
        XCTAssertEqual(sameDomainIframeConf.css, [], "Cosmetic rules should be disabled")

        // Test case 3: Example.com subdocument (third-party=false)
        let mainFrameExampleComUrl = URL(string: "https://example.com/")!
        let mainFrameExampleComConf = webExtension.lookup(
            pageUrl: mainFrameExampleComUrl,
            topUrl: mainFrameExampleComUrl
        )

        XCTAssertNotNil(mainFrameExampleComConf, "Expected configuration to be selected for iframe")

        guard let mainFrameExampleComConf = mainFrameExampleComConf else { return }

        // Only the regular rule should apply to the frame
        XCTAssertEqual(
            mainFrameExampleComConf.css,
            ["#banner"],
            "Only one CSS rule should apply to iframe"
        )

        // Test case 4: Third-party subdocument (subdocument=true, third-party=true)
        let thirdPartyIframeUrl = URL(string: "https://example.com/iframe.html")!
        let thirdPartyIframeConf = webExtension.lookup(
            pageUrl: thirdPartyIframeUrl,
            topUrl: mainPageUrl
        )

        XCTAssertNotNil(
            thirdPartyIframeConf,
            "Expected configuration to be selected for third-party iframe"
        )

        guard let thirdPartyIframeConf = thirdPartyIframeConf else { return }

        // All rules should apply to third-party subdocument
        // Cosmetic rules should be disabled by the elemhide rule for third-party frames
        XCTAssertEqual(thirdPartyIframeConf.css, [], "Cosmetic rules should be disabled")
    }

    /// Test that lookup properly applies cosmetic rules with wildcard TLD domains.
    ///
    /// Validates that a rule like `example.*###banner` applies to different
    /// eTLDs (e.g., example.com, example.co.uk) and does not apply to
    /// non-matching domains.
    func testLookupWithWildcardTldDomains() throws {
        // Build the engine with a wildcard TLD cosmetic rule
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )
        let filterList = [
            "example.*###banner"
        ].joined(separator: "\n")
        _ = try builder.buildFilterEngine(rules: filterList)

        // Use a new WebExtension instance for lookups (deserialization path)
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Should match example.com
        let urlCom = URL(string: "https://example.com/")!
        let confCom = webExtension.lookup(pageUrl: urlCom, topUrl: nil)
        XCTAssertNotNil(confCom, "Expected configuration for example.com")
        XCTAssertEqual(confCom?.css, ["#banner"])
        XCTAssertTrue(confCom?.extendedCss.isEmpty ?? false)
        XCTAssertTrue(confCom?.js.isEmpty ?? false)
        XCTAssertTrue(confCom?.scriptlets.isEmpty ?? false)

        // Should also match example.co.uk (different eTLD)
        let urlCoUk = URL(string: "https://example.co.uk/")!
        let confCoUk = webExtension.lookup(pageUrl: urlCoUk, topUrl: nil)
        XCTAssertNotNil(confCoUk, "Expected configuration for example.co.uk")
        XCTAssertEqual(confCoUk?.css, ["#banner"])

        // Should not match non-related domains
        let urlOther = URL(string: "https://notexample.com/")!
        let confOther = webExtension.lookup(pageUrl: urlOther, topUrl: nil)
        XCTAssertNotNil(confOther, "Expected configuration object even if no rules match")
        XCTAssertEqual(confOther?.css ?? [], [], "No CSS rules should apply to non-matching domain")
    }

    /// Benchmark test for the buildFilterEngine method
    ///
    /// Baseline results (Aug 8, 2025):
    /// - Machine: MacBook Pro M4 Max, 48GB RAM
    /// - OS: macOS 26
    /// - Swift: 6.2
    /// - Average execution time: ~0.136 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testBuildFilterEngineBenchmark() throws {
        // Create a large filter list with many rules
        var filterRules: [String] = []
        for i in 1...1000 {
            if i % 2 == 0 {
                filterRules.append("@@||example\(i).org^$jsinject")
            }
            filterRules.append("example\(i).org###banner")
            filterRules.append("example\(i).org#$##banner { visibility: hidden }")
            filterRules.append("example\(i).org#?##banner:has(div)")
            filterRules.append("example\(i).org#%#console.log('test')")
            filterRules.append("example\(i).org#%#//scriptlet('log', 'test')")
        }
        let filterList = filterRules.joined(separator: "\n")

        // Measure the performance of building the filter engine
        measure {
            let webExtension = try! WebExtension(
                containerURL: tempDirectory,
                version: SafariVersion.safari16_4
            )

            _ = try! webExtension.buildFilterEngine(rules: filterList)
        }
    }

    /// Benchmark test for the lookup method
    ///
    /// Baseline results (Aug 8, 2025):
    /// - Machine: MacBook Pro M4 Max, 48GB RAM
    /// - OS: macOS 26
    /// - Swift: 6.2
    /// - Average execution time: ~0.008 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testLookupBenchmark() throws {
        // Create a filter list with many rules
        var filterRules: [String] = []
        for i in 1...1000 {
            if i % 2 == 0 {
                filterRules.append("@@||example\(i).org^$jsinject")
            }
            filterRules.append("example\(i).org###banner")
            filterRules.append("example\(i).org#$##banner { visibility: hidden }")
            filterRules.append("example\(i).org#?##banner:has(div)")
            filterRules.append("example\(i).org#%#console.log('test')")
            filterRules.append("example\(i).org#%#//scriptlet('log', 'test')")
        }
        let filterList = filterRules.joined(separator: "\n")

        // Build the filter engine first
        let builder = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )
        _ = try builder.buildFilterEngine(rules: filterList)

        // Create a new WebExtension instance for lookup
        let webExtension = try WebExtension(
            containerURL: tempDirectory,
            version: SafariVersion.safari16_4
        )

        // Create a list of URLs to test
        let urls = (1...100).map { URL(string: "https://example\($0).org/")! }

        // Measure the performance of lookup
        measure {
            for url in urls {
                _ = webExtension.lookup(pageUrl: url, topUrl: nil)
            }
        }
    }

    func testSharedSingletonReturnsSameInstance() throws {
        let groupID = UUID().uuidString
        let version = SafariVersion.safari16_4

        let instance1 = try WebExtension.shared(groupID: groupID, version: version)
        let instance2 = try WebExtension.shared(groupID: groupID, version: version)
        XCTAssertTrue(
            instance1 === instance2,
            "shared() should return the same instance for the same groupID and version"
        )

        let anotherGroupID = UUID().uuidString
        let instance3 = try WebExtension.shared(groupID: anotherGroupID, version: version)
        XCTAssertFalse(
            instance1 === instance3,
            "shared() should return different instances for different groupIDs"
        )
    }
}
