import WebKit
import XCTest

@testable import ContentBlockerConverter

/// Unit tests that verify `ContentBlockerConverter` output compiles
/// successfully with WebKit's `WKContentRuleListStore`.
final class WebKitCompilationTests: XCTestCase {

    // MARK: - Network rules

    func testBasicNetworkRules() async throws {
        try await convertAndCompile(
            [
                "||example.org^",
                "||ads.example.com^",
                "-ad-banner.",
                "/^https:\\/\\/example\\.com\\/ads\\//",
            ]
        )
    }

    func testExceptionRules() async throws {
        try await convertAndCompile(
            [
                "||example.org^",
                "@@||example.org^$document",
                "@@||safe.example.org^$image",
                "@@||cdn.example.org^$script,domain=example.org",
            ]
        )
    }

    // MARK: - Cosmetic rules

    func testCosmeticRules() async throws {
        try await convertAndCompile(
            [
                "example.org##.ad-banner",
                "example.org##div[id^=\"ad-\"]",
                "###advertisement",
                "##.sponsored-content",
            ]
        )
    }

    // MARK: - Domain modifier

    func testDomainModifier() async throws {
        try await convertAndCompile(
            [
                "||ads.example.org^$domain=example.org",
                "||tracker.com^$domain=~example.org",
                "||cdn.example.*^$domain=example.*",
                "||ad.example.net^$domain=example.com|example.net",
            ]
        )
    }

    func testRegexDomain() async throws {
        try XCTSkipIf(
            SafariVersion.autodetect().doubleValue < SafariVersion.safari26.doubleValue,
            "Regex domain rules require Safari 26+"
        )
        try await convertAndCompile(
            ["||banner.example.org^$domain=/example\\.(com|net|org)/"]
        )
    }

    // MARK: - Modifiers

    func testImportantModifier() async throws {
        try await convertAndCompile(
            [
                "||ads.example.org^$important",
                "@@||safe.example.org^$important",
            ]
        )
    }

    func testSpecifichideModifier() async throws {
        try await convertAndCompile(
            [
                "example.org##.ad-banner",
                "@@||example.org^$specifichide",
            ]
        )
    }

    func testDenyallowModifier() async throws {
        try await convertAndCompile(
            ["*$image,denyallow=x.com,domain=a.com|~b.com"]
        )
    }

    func testMethodModifier() async throws {
        try XCTSkipIf(
            SafariVersion.autodetect().doubleValue < SafariVersion.safari26.doubleValue,
            "Method modifier requires Safari 26+"
        )
        try await convertAndCompile(
            [
                "||tracker.example.com^$method=post",
                "||api.example.com^$method=get|post",
            ]
        )
    }

    // MARK: - Edge cases

    func testMixedRuleTypes() async throws {
        try await convertAndCompile(
            [
                "||ads.example.org^",
                "@@||example.org^$document",
                "example.org##.ad-banner",
                "||tracker.com^$domain=example.org",
                "||important.bad.com^$important",
                "@@||safe.example.org^$specifichide",
            ]
        )
    }

    func testEmptyRuleSet() async throws {
        try await convertAndCompile([])
    }

    func testUnicodeSelectors() async throws {
        try await convertAndCompile(
            [
                "example.org##.\u{0431}\u{0430}\u{043D}\u{043D}\u{0435}\u{0440}",
                "example.org##.\u{5E7F}\u{544A}",
                "example.org##.\u{0935}\u{093F}\u{091C}\u{094D}\u{091E}\u{093E}\u{092A}\u{0928}",
            ]
        )
    }

    // MARK: - Regression tests

    /// Regression test for rules with a regex containing `|` in the `$domain=`
    /// modifier. Such rules were previously incorrectly split on `|`, producing
    /// invalid `if-domain` entries that caused WebKit's YARR engine to fail.
    func testRegexDomainWithAlternation() async throws {
        try XCTSkipIf(
            SafariVersion.autodetect().doubleValue < SafariVersion.safari26.doubleValue,
            "Regex domain rules require Safari 26+"
        )
        try await convertAndCompile(
            [
                "||example.org^$domain=/example\\d*\\.(com|net|org)/",
                "||example.com^$domain=/test\\d*\\.(org|net|com)/",
            ]
        )
    }

}
