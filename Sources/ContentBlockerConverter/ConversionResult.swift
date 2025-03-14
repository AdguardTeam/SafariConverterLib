import Foundation

/// Represents the final conversion result.
public struct ConversionResult: CustomStringConvertible {
    public static let EMPTY_RESULT_JSON: String =
        // swiftlint:disable:next line_length
        "[{\"trigger\": {\"url-filter\": \".*\",\"if-domain\": [\"domain.com\"]},\"action\":{\"type\": \"ignore-previous-rules\"}}]"

    /// Helper function that creates an empty result.
    ///
    /// In this case we return a JSON with a single rule that does not do anything.
    /// The reason for that is that Safari requires at least one rule to be present.
    static func createEmptyResult() -> ConversionResult {
        return ConversionResult(
            sourceRulesCount: 0,
            sourceSafariCompatibleRulesCount: 0,
            safariRulesCount: 0,
            advancedRulesCount: 0,
            discardedSafariRules: 0,
            errorsCount: 0,
            safariRulesJSON: self.EMPTY_RESULT_JSON,
            advancedRulesText: nil
        )
    }

    /// Total number of AdGuard rules before the conversion started.
    public let sourceRulesCount: Int

    /// The number of source AdGuard rules before attempting to convert them
    /// to Safari content blocking syntax. This number does not include advanced
    /// rules which are counted separately.
    public let sourceSafariCompatibleRulesCount: Int

    /// The number of Safari rules in `safariRulesJSON`.
    public let safariRulesCount: Int

    /// The number of advanced rules in `advancedRulesText`.
    public let advancedRulesCount: Int

    /// The number of Safari rules that were discarded due to the limits that are imposed by the OS or Safari.
    ///
    /// There are two possible reasons for discarding rules:
    /// - Maximum number of rules in a content blocker (depends on the OS version, can be 50k or 150k)
    /// - Maximum size of the JSON file (the issue is specific to iOS versions, see FB13282146)
    public let discardedSafariRules: Int

    /// Count of conversion errors (i.e. count of rules that we could not convert).
    public let errorsCount: Int

    /// JSON with Safari content blocking rules.
    public let safariRulesJSON: String

    /// AdGuard rules that need to be interpreted by web extension (or app extension).
    public let advancedRulesText: String?

    /// String representation of the conversion result
    public var description: String {
        return """
            ## Conversion status

            * Source rules count: \(self.sourceRulesCount)
            * Source rules compatible with Safari: \(self.sourceSafariCompatibleRulesCount)
            * Failed to convert: \(self.errorsCount)
            * Discarded due to limits: \(self.discardedSafariRules)

            ## Result

            * Safari JSON rules count: \(self.safariRulesCount)
            * JSON size: \(self.safariRulesJSON.utf8.count)
            * Advanced rules count: \(self.advancedRulesCount)
            * Advanced rules size: \(self.advancedRulesText?.utf8.count ?? 0)
            """
    }
}

/// Make it possible to serialize ConversionResult to JSON.
///
/// We'll use this functionality for the command-line tool.
extension ConversionResult: Encodable {}
