import Foundation

/// Groups filter rules by their content blocker affinity.
///
/// `AffinityRulesGrouper` parses `!#safari_cb_affinity(...)` directives
/// embedded in filter rule lists and redistributes rules accordingly.
///
/// ## Affinity directive format
///
/// ```
/// !#safari_cb_affinity(general,privacy)
/// @@||example.com/js/ad.js
/// @@||example.org/tracker.js
/// !#safari_cb_affinity
/// ```
///
/// The rules between the opening and closing directives are assigned to the
/// content blockers listed in the opening directive (`general` and `privacy`
/// in the example above).
///
/// ## Usage
///
/// Callers prepare batches of rules grouped by their *default* content blocker
/// type (determined by the filter group). The grouper redistributes rules
/// within each batch according to any affinity directives found:
///
/// ```swift
/// let result = AffinityRulesGrouper.group(rules: [
///     (.general, generalRules),
///     (.privacy, privacyRules),
/// ])
/// // result[.general] includes:
/// //   - generalRules that have no affinity (default)
/// //   - rules from any batch directed to .general via affinity
/// ```
public enum AffinityRulesGrouper {
    /// Parses affinity directives within rule lists and redistributes rules
    /// to the appropriate content blocker types.
    ///
    /// - Parameter rules: An array of (defaultContentBlockerType, rules) pairs.
    ///   Each pair represents a batch of rules that *by default* belong to
    ///   `defaultContentBlockerType`. Rules inside the batch may override this
    ///   default via `!#safari_cb_affinity(...)` directives.
    ///
    /// - Returns: A dictionary mapping each `ContentBlockerType` to the rules
    ///   assigned to it after affinity redistribution.
    public static func group(
        rules: [(ContentBlockerType, [String])]
    ) -> [ContentBlockerType: [String]] {
        var result: [ContentBlockerType: [String]] = [:]

        for contentType in ContentBlockerType.allCases {
            result[contentType] = []
        }

        for (defaultType, lines) in rules {
            processBatch(lines: lines, defaultType: defaultType, result: &result)
        }

        return result
    }

    /// Wraps a rule string with `!#safari_cb_affinity(...)` directives.
    ///
    /// - Parameters:
    ///   - rule: The rule string to wrap.
    ///   - affinity: The affinity mask. Pass `nil` to return the rule
    ///     unchanged. Pass `[]` (or `.all`) to return the rule wrapped
    ///     with `all` affinity.
    ///
    /// - Returns: The rule wrapped with affinity directives, or the original
    ///   rule unchanged if `affinity` is `nil` or the rule is empty/whitespace.
    public static func rule(_ rule: String, withAffinity affinity: Affinity?) -> String {
        guard let affinity = affinity, !rule.trimmingCharacters(in: .whitespaces).isEmpty else {
            return rule
        }

        let affinityString = buildAffinityDirective(affinity)

        return """
            \(Constants.affinityPrefix)(\(affinityString))
            \(rule)
            \(Constants.affinitySuffix)
            """
    }

    // MARK: - Private

    private enum Constants {
        static let adblockFirstLine = "Adblock Plus"
        static let affinityPrefix = "!#safari_cb_affinity"
        static let affinitySuffix = "!#safari_cb_affinity"
    }

    /// String-to-Affinity mapping. Includes the `all` keyword that maps
    /// to the empty bitmask.
    private static let stringToAffinity: [String: Affinity] = [
        "general": .general,
        "privacy": .privacy,
        "social": .socialWidgetsAndAnnoyances,
        "other": .other,
        "custom": .custom,
        "security": .security,
        "all": Affinity(rawValue: 0),
    ]

    private static func processBatch(
        lines: [String],
        defaultType: ContentBlockerType,
        result: inout [ContentBlockerType: [String]]
    ) {
        var currentAffinity: Affinity?

        for (index, line) in lines.enumerated() {
            // Skip "Adblock Plus" first line
            if index == 0, line.lowercased().contains(Constants.adblockFirstLine.lowercased()) {
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // Affinity opening directive
            if trimmed.hasPrefix(Constants.affinityPrefix + "(") {
                currentAffinity = parseAffinity(from: trimmed)
                continue
            }

            // Affinity closing directive
            if trimmed == Constants.affinitySuffix {
                currentAffinity = nil
                continue
            }

            // Skip comments
            if trimmed.hasPrefix("!") {
                continue
            }

            // Distribute the rule
            distributeRule(trimmed, affinity: currentAffinity, defaultType: defaultType, result: &result)
        }
    }

    private static func parseAffinity(from line: String) -> Affinity? {
        let prefixCount = Constants.affinityPrefix.count + 1  // +1 for "("

        guard line.count > prefixCount + 1,
            line.last == ")" else {
            return nil
        }

        let startIndex = line.index(line.startIndex, offsetBy: prefixCount)
        let endIndex = line.index(before: line.endIndex)

        guard startIndex < endIndex else {
            return nil
        }

        let content = line[startIndex..<endIndex]
        let keywords = content.components(separatedBy: ",")

        var result: Affinity?
        for keyword in keywords {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let affinity = stringToAffinity[trimmed] else {
                continue
            }
            if result == nil {
                result = affinity
            } else {
                result?.insert(affinity)
            }
        }

        return result
    }

    private static func distributeRule(
        _ rule: String,
        affinity: Affinity?,
        defaultType: ContentBlockerType,
        result: inout [ContentBlockerType: [String]]
    ) {
        guard let affinity = affinity else {
            // No affinity — use default type
            result[defaultType]?.append(rule)
            return
        }

        // .all (rawValue 0) means every type
        if affinity.rawValue == 0 {
            for type in ContentBlockerType.allCases {
                result[type]?.append(rule)
            }
            return
        }

        // Distribute to matching types
        for type in ContentBlockerType.allCases where affinity.contains(type.affinity) {
            result[type]?.append(rule)
        }
    }

    private static func buildAffinityDirective(_ affinity: Affinity) -> String {
        if affinity.rawValue == 0 {
            return "all"
        }

        var keywords: [String] = []
        if affinity.contains(.general) { keywords.append("general") }
        if affinity.contains(.custom) { keywords.append("custom") }
        if affinity.contains(.other) { keywords.append("other") }
        if affinity.contains(.privacy) { keywords.append("privacy") }
        if affinity.contains(.security) { keywords.append("security") }
        if affinity.contains(.socialWidgetsAndAnnoyances) { keywords.append("social") }

        return keywords.joined(separator: ",")
    }
}

private extension ContentBlockerType {
    /// Maps a ``ContentBlockerType`` case to its corresponding ``Affinity`` bit.
    var affinity: Affinity {
        switch self {
        case .general: return .general
        case .privacy: return .privacy
        case .socialWidgetsAndAnnoyances: return .socialWidgetsAndAnnoyances
        case .other: return .other
        case .custom: return .custom
        case .security: return .security
        }
    }
}
