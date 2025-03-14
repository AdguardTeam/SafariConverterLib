import XCTest

@testable import ContentBlockerConverter

/// Performance tests.
extension ContentBlockerConverterTests {
    /// Single run of the rule converter so that it was easier to profile it.
    func testPerformanceSingleRun() {
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/test-rules.txt")

        let content = try! String(contentsOf: resourceURL, encoding: String.Encoding.utf8)
        let rules = content.components(separatedBy: "\n")

        // On MBP M1 Max 2021 32GB
        // CPU profiler result:
        //
        // 345.95 Mc  69.7%: ContentBlockerConverter.convertArray
        let conversionResult = ContentBlockerConverter().convertArray(
            rules: rules,
            advancedBlocking: true
        )

        XCTAssertEqual(conversionResult.sourceRulesCount, 32644)
        XCTAssertEqual(conversionResult.safariRulesCount, 20018)
        XCTAssertEqual(conversionResult.sourceSafariCompatibleRulesCount, 28617)
        XCTAssertEqual(conversionResult.advancedRulesCount, 7299)
        XCTAssertEqual(conversionResult.errorsCount, 103)
        XCTAssertEqual(conversionResult.discardedSafariRules, 0)
    }

    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~1.383 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testPerformance() {
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        let resourceURL = thisDirectory.appendingPathComponent("Resources/test-rules.txt")

        let content = try! String(contentsOf: resourceURL, encoding: String.Encoding.utf8)
        let rules = content.components(separatedBy: "\n")

        self.measure {
            let conversionResult = ContentBlockerConverter().convertArray(
                rules: rules,
                advancedBlocking: true
            )

            XCTAssertEqual(conversionResult.sourceRulesCount, 32644)
            XCTAssertEqual(conversionResult.safariRulesCount, 20018)
            XCTAssertEqual(conversionResult.sourceSafariCompatibleRulesCount, 28617)
            XCTAssertEqual(conversionResult.advancedRulesCount, 7299)
            XCTAssertEqual(conversionResult.errorsCount, 103)
            XCTAssertEqual(conversionResult.discardedSafariRules, 0)
        }
    }

    /// Baseline results (March 2025):
    /// - Machine: MacBook Pro M1 Max, 32GB RAM
    /// - OS: macOS 15.1
    /// - Swift: 6.0
    /// - Average execution time: ~0.300 seconds
    ///
    /// To get your machine info: `system_profiler SPHardwareDataType`
    /// To get your macOS version: `sw_vers`
    /// To get your Swift version: `swift --version`
    func testSpecifichidePerformance() {
        let rulePairsCount: Int = 1000
        var rules = [String]()

        for index in 1...rulePairsCount {
            rules.append("test\(index).com,example\(index).org##.banner")
            rules.append("@@||example\(index).org^$specifichide")
        }

        self.measure {
            let conversionResult = ContentBlockerConverter().convertArray(rules: rules)

            XCTAssertEqual(conversionResult.sourceRulesCount, rulePairsCount * 2)
            XCTAssertEqual(conversionResult.safariRulesCount, rulePairsCount)
            XCTAssertEqual(conversionResult.errorsCount, 0)
            XCTAssertEqual(conversionResult.discardedSafariRules, 0)
        }
    }

    /// This is a basic test that checks that our converter does not crash on popular third-party lists.
    func testAttemptToConvertPopularLists() {
        let lists = [
            "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt",
            "https://filters.adtidy.org/ios/filters/1.txt",
            "https://filters.adtidy.org/ios/filters/2.txt",
            "https://filters.adtidy.org/ios/filters/3.txt",
            "https://filters.adtidy.org/ios/filters/4.txt",
            "https://filters.adtidy.org/ios/filters/5.txt",
            "https://filters.adtidy.org/ios/filters/10.txt",
            "https://filters.adtidy.org/ios/filters/14.txt",
            "https://easylist-downloads.adblockplus.org/easylist.txt",
            "https://easylist-downloads.adblockplus.org/easyprivacy.txt",
            "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
            "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
            "https://secure.fanboy.co.nz/fanboy-social.txt",
            "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
            "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-2022.txt",
            "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-2021.txt",
            "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-2020.txt",
        ]

        for listUrl in lists {
            let content = try! String(
                contentsOf: URL(string: listUrl)!,
                encoding: String.Encoding.utf8
            )
            let rules = content.components(separatedBy: "\n")

            let conversionResult = ContentBlockerConverter().convertArray(rules: rules)
            XCTAssertTrue(
                conversionResult.safariRulesCount > 0,
                "Conversion failed for URL: \(listUrl)"
            )
        }
    }
}
