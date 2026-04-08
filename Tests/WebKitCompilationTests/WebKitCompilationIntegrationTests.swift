import Foundation
import WebKit
import XCTest

@testable import ContentBlockerConverter

// MARK: - Filter index data transfer objects

/// An entry in the AdGuard filter index JSON.
private struct FilterIndexEntry: Decodable {
    let filterId: Int
    let name: String
    let downloadUrl: String
    let tags: [Int]
    let deprecated: Bool?

    var isDeprecated: Bool { deprecated ?? false }
    var isRecommended: Bool { tags.contains(10) }
}

/// Top-level container of the AdGuard filter index JSON.
private struct FilterIndex: Decodable {
    let filters: [FilterIndexEntry]
}

// MARK: - Integration tests

/// Integration tests that fetch real filter lists from the AdGuard filter
/// index and verify they compile successfully with WebKit.
///
/// These tests require network access. They are skipped automatically when
/// the network is unavailable.
final class WebKitCompilationIntegrationTests: XCTestCase {

    private static let filterIndexURL =
        "https://filters.adtidy.org/extension/safari/filters.json"

    /// Fetches every non-deprecated recommended filter from the AdGuard index,
    /// converts it, and asserts that WebKit can compile the result.
    func testRecommendedFiltersCompile() async throws {
        let indexText: String
        do {
            indexText = try await fetchURL(Self.filterIndexURL)
        } catch {
            throw XCTSkip("Network unavailable: \(error)")
        }

        let indexData = Data(indexText.utf8)
        let entries: [FilterIndexEntry]
        do {
            let index = try JSONDecoder().decode(FilterIndex.self, from: indexData)
            entries = index.filters
        } catch {
            XCTFail("Failed to decode filter index: \(error)")
            return
        }

        let recommended = entries.filter { !$0.isDeprecated && $0.isRecommended }
        XCTAssertFalse(recommended.isEmpty, "No recommended filters found in the index")

        var compiledCount = 0

        for entry in recommended {
            let filterText: String
            do {
                filterText = try await fetchURL(entry.downloadUrl)
            } catch {
                // Skip individual filters that are temporarily unreachable.
                continue
            }

            let rules = filterText.components(separatedBy: "\n")
            let result = convertRules(rules, safariVersion: SafariVersion.autodetect())

            do {
                try await compileWithWebKit(
                    result.safariRulesJSON,
                    identifier: "filter-\(entry.filterId)"
                )
                compiledCount += 1
            } catch {
                XCTFail(
                    "WebKit compilation failed for filter '\(entry.name)' "
                        + "(id: \(entry.filterId)): \(error)"
                )
            }
        }

        XCTAssertGreaterThan(
            compiledCount,
            0,
            "No filters were actually compiled — all downloads failed"
        )
    }
}
