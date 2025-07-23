import Foundation

/// This enum provides logic for converting network rules patterns to regular expressions.
///
/// AdGuard's network rules mostly use a simplified syntax for matching URLs instead
/// of full-scale regular expressions. These patterns can be converted to regular expressions
/// that are supported by Safari content blocking rules.
public enum SimpleRegex {
    private static let regexAnySymbol = ".*"
    private static let regexAnySymbolChars: [UInt8] = Array(".*".utf8)
    private static let regexStartString: [UInt8] = Array("^".utf8)
    private static let regexEndString: [UInt8] = Array("$".utf8)

    /// `||` start URL marker regex replacement. We are using the same regex that is recommended
    /// by Apple: https://webkit.org/blog/4062/targeting-domains-with-content-blockers/.
    private static let regexStartUrl: [UInt8] = Array(#"^[^:]+://+([^:/]+\.)?"#.utf8)

    /// Separator `^` default regex replacement.
    private static let regexSeparator: [UInt8] = Array("[/:&?]".utf8)

    /// Separator `^` regex replacement for the case when this is the end of pattern.
    /// We need to account for the fact that "the end of the address is also accepted as separator".
    private static let regexEndSeparator: [UInt8] = Array("[/:&?]?".utf8)

    /// Separator `^` regex replacement for the case when we're targeting a domain name,
    /// i.e. when the pattern starts with `||`.
    private static let regexDomainSeparator: [UInt8] = Array("[/:]".utf8)

    /// Creates a regular expression from a network rule pattern.
    ///
    /// - Parameters:
    ///   - pattern: network rule pattern to convert.
    /// - Returns: regular expression corresponding to that pattern.
    /// - Throws: `SyntaxError` if the pattern contains non-ASCII characters.
    public static func createRegexText(pattern: String) throws -> String {
        if pattern.isEmpty || pattern == "||" || pattern == "|" || pattern == "*" {
            return regexAnySymbol
        }

        var resultChars: [UInt8] = []
        let utf8 = pattern.utf8
        var currentIndex = utf8.startIndex
        var useDomainSeparator = false

        @inline(__always)
        func peekNext() -> UInt8? {
            let next = utf8.index(after: currentIndex)
            guard next < utf8.endIndex else { return nil }
            return utf8[next]
        }

        while currentIndex < utf8.endIndex {
            let char = utf8[currentIndex]

            switch char {
            case UInt8(ascii: "."), UInt8(ascii: "+"), UInt8(ascii: "?"), UInt8(ascii: "$"),
                UInt8(ascii: "{"), UInt8(ascii: "}"), UInt8(ascii: "("), UInt8(ascii: ")"),
                UInt8(ascii: "["), UInt8(ascii: "]"), UInt8(ascii: "/"), UInt8(ascii: "\\"):

                // Processing characters to be escaped in the regular expressions.
                //
                // Source for the characters:
                // https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
                //
                // '\*', '|', '^', and `$` are processed differently.
                resultChars.append(UInt8(ascii: "\\"))
                resultChars.append(char)

                // Special character signals that this is not a domain name and we should not
                // use `regexDomainSeparator` for replacing `^`.
                if char != UInt8(ascii: ".") {
                    useDomainSeparator = false
                }
            case UInt8(ascii: "|"):
                let nextChar = peekNext()

                if currentIndex == utf8.startIndex {
                    if nextChar == UInt8(ascii: "|") {
                        // This is a start URL mask: `||`
                        resultChars.append(contentsOf: regexStartUrl)

                        // We're dealing with a domain name so prepare to use
                        // `regexDomainSeparator` for replacing next `^`.
                        useDomainSeparator = true

                        // Increment index since we already processed next char.
                        currentIndex = utf8.index(after: currentIndex)
                    } else {
                        // This is a string string mask.
                        resultChars.append(contentsOf: regexStartString)
                    }
                } else if nextChar == nil {
                    // This is the end of string so this is an end of URL mask.
                    resultChars.append(contentsOf: regexEndString)
                } else {
                    // In other cases we just excape `|`.
                    resultChars.append(UInt8(ascii: "\\"))
                    resultChars.append(char)
                }
            case UInt8(ascii: "^"):
                let nextChar = peekNext()

                if useDomainSeparator {
                    resultChars.append(contentsOf: regexDomainSeparator)

                    // For all other separators use the default separator regex.
                    useDomainSeparator = false
                } else if nextChar == nil {
                    resultChars.append(contentsOf: regexEndSeparator)
                } else {
                    resultChars.append(contentsOf: regexSeparator)
                }
            case UInt8(ascii: "*"):
                resultChars.append(contentsOf: regexAnySymbolChars)

                // Special character, switch to using default separator regex.
                useDomainSeparator = false
            default:
                if char > 127 {
                    throw SyntaxError.invalidPattern(
                        message: "Non ASCII characters are not supported"
                    )
                } else if char == UInt8(ascii: ":") {
                    // Special character, switch to using default separator regex.
                    useDomainSeparator = false
                }

                resultChars.append(char)
            }

            currentIndex = utf8.index(after: currentIndex)
        }

        if let string = String(bytes: resultChars, encoding: .utf8) {
            return string
        }

        // This should never happen as we're only dealing with ASCII characters
        return regexAnySymbol
    }

    /// Checks if the rule pattern is a regex rule, i.e. enclosed in `/`.
    ///
    /// Example: `/regex/`.
    public static func isRegexPattern(_ pattern: String) -> Bool {
        pattern.utf8.count > 2 && pattern.utf8.first == Chars.SLASH
            && pattern.utf8.last == Chars.SLASH
    }

    /// Extracts a regex pattern from a regex rule. Returns `nil` if this is not a regex rule.
    public static func extractRegex(_ pattern: String) -> String? {
        if !isRegexPattern(pattern) {
            return nil
        }

        let startIndex = pattern.utf8.index(after: pattern.utf8.startIndex)
        let endIndex = pattern.utf8.index(before: pattern.utf8.endIndex)

        return String(pattern[startIndex..<endIndex])
    }
}
