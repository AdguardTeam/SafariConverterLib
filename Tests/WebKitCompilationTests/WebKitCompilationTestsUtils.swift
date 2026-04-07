import Foundation
import WebKit
import XCTest

@testable import ContentBlockerConverter

// MARK: - Shared helpers

/// Compiles the given content blocker JSON using WebKit's
/// `WKContentRuleListStore`.
///
/// - Parameters:
///   - json: The content blocker JSON string to compile.
///   - identifier: A unique identifier for the rule list.
/// - Throws: An error if WebKit compilation fails.
func compileWithWebKit(_ json: String, identifier: String) async throws {
    let store = await MainActor.run { WKContentRuleListStore.default()! }
    _ = try await store.compileContentRuleList(
        forIdentifier: identifier,
        encodedContentRuleList: json
    )
}

/// Converts AdGuard rules to Safari content blocking JSON.
///
/// - Parameters:
///   - rules: The filter rules to convert.
///   - safariVersion: The target Safari version.
///   - advancedBlocking: Whether to include advanced blocking rules.
/// - Returns: The conversion result.
func convertRules(
    _ rules: [String],
    safariVersion: SafariVersion = SafariVersion.autodetect(),
    advancedBlocking: Bool = false
) -> ConversionResult {
    ContentBlockerConverter().convertArray(
        rules: rules,
        safariVersion: safariVersion,
        advancedBlocking: advancedBlocking
    )
}

/// Converts AdGuard rules and compiles the resulting JSON with WebKit.
///
/// - Parameters:
///   - rules: The filter rules to convert.
///   - safariVersion: The target Safari version.
///   - identifier: A unique identifier for the WebKit rule list.
/// - Throws: An error if conversion or WebKit compilation fails.
func convertAndCompile(
    _ rules: [String],
    safariVersion: SafariVersion = SafariVersion.autodetect(),
    identifier: String = UUID().uuidString
) async throws {
    let result = convertRules(rules, safariVersion: safariVersion)
    try await compileWithWebKit(result.safariRulesJSON, identifier: identifier)
}

/// Fetches the content at the given URL and returns it as a string.
///
/// - Parameter url: The URL string to fetch.
/// - Throws: An error if the request fails or the response cannot be decoded as UTF-8.
/// - Returns: The response body as a string.
func fetchURL(_ url: String) async throws -> String {
    guard let parsedURL = URL(string: url) else {
        throw URLError(.badURL)
    }
    let (data, _) = try await URLSession.shared.data(from: parsedURL)
    guard let text = String(data: data, encoding: .utf8) else {
        throw URLError(.cannotDecodeContentData)
    }
    return text
}
