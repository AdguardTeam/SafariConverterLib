import Foundation
import Punycode

/// Simple parser that is only capable of splitting network rule into basic parts.
/// The further complicated parsing is done by NetworkRule.
class NetworkRuleParser {
    private static let MASK_WHITE_LIST_UTF8 = [Chars.AT_CHAR, Chars.AT_CHAR]
    private static let DOMAIN_VALIDATION_REGEXP = try! NSRegularExpression(pattern: "^[a-zA-Z0-9][a-zA-Z0-9-.]*[a-zA-Z0-9]\\.[a-zA-Z-]{2,}$", options: [.caseInsensitive])
    private static let startDomainPrefixMatcher = PrefixMatcher(prefixes: [
        "||", "@@||", "|https://", "|http://", "@@|https://", "@@|http://",
        "|ws://", "|wss://", "@@|ws://", "@@|wss://",
        "//", "://", "@@//", "@@://", "https://", "http://",
        "@@https://", "@@http://"
    ])

    /// Split the specified network rule into its basic parts: pattern and options strings.
    static func parseRuleText(ruleText: String) throws -> BasicRuleParts {
        var ruleParts = BasicRuleParts()

        let utf8 = ruleText.utf8
        var i = utf8.endIndex
        var start = utf8.startIndex
        var delimiterIndex: String.Index?

        if utf8.isEmpty {
            throw SyntaxError.invalidRule(message: "Rule is too short")
        }

        if utf8.starts(with: MASK_WHITE_LIST_UTF8) {
            start = utf8.index(utf8.startIndex, offsetBy: 2)
            ruleParts.whitelist = true
        }

        @inline(__always) func peekNext() -> UInt8? {
            let next = utf8.index(after: i)
            guard next < utf8.endIndex else { return nil }
            return utf8[next]
        }

        @inline(__always) func peekPrevious() -> UInt8? {
            guard i > start else { return nil }
            let previous = utf8.index(before: i)
            return utf8[previous]
        }

        // The first step is to find the options delimiter.
        // In order to do that we iterate over the string and look for the '$' character.
        // We also check that it's not escaped and that it's not likely a part of a regex.
        while i > start {
            i = utf8.index(before: i)

            let char = utf8[i]

            if char == Chars.DOLLAR {
                // Check that it's not escaped (\$) and that it's not likely a part of regex ($/).
                if peekPrevious() != Chars.BACKSLASH && peekNext() != Chars.SLASH {
                    delimiterIndex = i

                    // Delimiter index found, exit
                    break
                }
            }
        }

        var optionsIndex = utf8.endIndex
        if delimiterIndex != nil {
            optionsIndex = utf8.index(after: delimiterIndex!)
        }

        if optionsIndex == utf8.endIndex {
            if start == utf8.startIndex {
                // Avoid allocating new String if it's possible.
                ruleParts.pattern = ruleText
            } else {
                ruleParts.pattern = String(ruleText[start...])
            }
        } else {
            ruleParts.pattern = String(ruleText[start..<delimiterIndex!])
            ruleParts.options = String(ruleText[optionsIndex...])
        }

        return ruleParts
    }

    /// Searches for domain name in rule text and transforms it to punycode if required.
    static func encodeDomainIfRequired(pattern: String?) -> String? {
        if pattern == nil {
            return pattern
        }

        let res = extractDomain(pattern: pattern!)
        if res.domain == "" || res.domain.isASCII() {
            return pattern
        }

        return pattern!.replacingOccurrences(of: res.domain, with: res.domain.idnaEncoded!)
    }

    /// Extracts domain name from a basic rule pattern.
    ///
    /// This function uses a very simple logic and looks for the standard patterns.
    /// It looks if the pattern starts with any of the strings that are used before the domain name, i.e.:
    /// '||', '://', etc.
    ///
    /// And then it looks if there is anything that encloses the domain name: '^', '/'.
    ///
    /// - Parameters:
    ///   - pattern: rule pattern or rule text.
    /// - Returns:
    ///   - domain: Extracted domain or empty string if domain not found.
    ///   - patternMatchesPath: true if pattern matches more than just the domain.
    static func extractDomain(pattern: String) -> (domain: String, patternMatchesPath: Bool) {
        let utf8 = pattern.utf8
        let res = startDomainPrefixMatcher.matchPrefix(in: pattern)

        var startIndex = utf8.startIndex
        if res.idx != nil {
            startIndex = utf8.index(after: res.idx!)
        }

        var endIndex = utf8.endIndex
        var i = startIndex
        while i < endIndex {
            let char = utf8[i]

            let isLetter = char >= UInt8(ascii: "a") && char <= UInt8(ascii: "z")
            let isDigit = char >= UInt8(ascii: "0") && char <= UInt8(ascii: "9")

            // Suprisingly, non-ASCII chars are allowed as this function should be
            // able to extract anything that looks similar to a domain name including
            // not-yet-punycoded domains which will then be encoded later.
            let nonASCII = char >= 128

            // Also, do some minimal validation here.
            // ^[a-z0-9][a-z0-9-.]*[a-z0-9]\\.[a-zA-Z-]{2,}$
            if i == startIndex {
                if !(isLetter || isDigit || nonASCII) {
                    // Invalid character for a domain, return immediately.
                    return ("", false)
                }
            }

            if char == Chars.CARET || char == Chars.SLASH || char == Chars.DOLLAR {
                endIndex = i
                break
            }

            if !isLetter && !isDigit && !nonASCII && char != UInt8(ascii: "-") && char != UInt8(ascii: ".") {
                // Invalid characters for a domain name, return immediately.
                return ("", false)
            }

            i = utf8.index(after: i)
        }

        if startIndex == endIndex {
            return ("", false)
        }

        let domain = String(pattern[startIndex..<endIndex])
        if domain.utf8.count < 5 {
            // Too short for a domain name.
            return ("", false)
        }

        // Check if there's anything else important left in the pattern without domain.
        let patternMatchesPath = endIndex < utf8.endIndex && utf8.distance(from: endIndex, to: utf8.endIndex) > 1

        return (domain, patternMatchesPath)
    }

    /// Extracts domain from the rule pattern or text using extractPattern function and then validates the domain.
    static func extractDomainAndValidate(pattern: String)  -> (domain: String, patternMatchesPath: Bool) {
        let res = extractDomain(pattern: pattern)

        if !res.domain.isEmpty && res.domain.firstMatch(for: DOMAIN_VALIDATION_REGEXP) != nil {
            return res
        }

        return ("", false)
    }

    /// Represents main parts of a basic rule.
    ///
    /// Normally, the rule looks like this:
    /// [@@] pattern [$options]
    ///
    /// For instance, in the case of @@||example.org^$third-party the object will consist of the following:
    ///
    /// - pattern: ||example.org^
    /// - options: third-party
    /// - whitelist: true
    struct BasicRuleParts {
        var pattern: String = ""
        var options: String?
        var whitelist = false
    }
}
