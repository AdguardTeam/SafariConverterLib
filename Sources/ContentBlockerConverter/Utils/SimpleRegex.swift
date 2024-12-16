import Foundation

/// This class provides logic for converting network rules patterns to regular expressions.
///
/// AdGuard's network rules mostly use a simplified syntax for matching URLs instead
/// of full-scale regular expressions. These patterns can be converted to regular expressions
/// that are supported by Safari content blocking rules.
class SimpleRegex {
    private static let maskStartUrl = "||"
    private static let maskPipe = "|"
    private static let maskSeparator = "^"
    private static let maskAnySymbol = "*"

    private static let regexAnySymbol = ".*"
    private static let regexAnySymbolChars = Array(".*".utf8)
    private static let regexStartString = Array("^".utf8)
    private static let regexEndString = Array("$".utf8)

    /// Improved regular expression instead of UrlFilterRule.REGEXP_START_URL (||).
    ///
    /// Please note, that this regular expression matches only ONE level of subdomains.
    /// Using ([a-z0-9-.]+\\.)? instead increases memory usage by 10Mb
    private static let regexStartUrl = Array(#"^[htpsw]+:\/\/([a-z0-9-]+\.)?"#.utf8)

    /// Simplified separator (to fix an issue with $ restriction - it can be only in the end of regexp).
    private static let regexEndSeparator = Array("([\\/:&\\?].*)?$".utf8)
    private static let regexSeparator = Array("[/:&?]?".utf8)

    /// Creates a regular expression from a network rule pattern.
    ///
    /// - Parameters:
    ///   - pattern: network rule pattern to convert.
    /// - Returns: regular expression corresponding to that pattern.
    /// - Throws: SyntaxError if the pattern contains non-ASCII characters.
    public static func createRegexText(pattern: String) throws -> String {
        if (pattern == "" ||
            pattern == maskStartUrl ||
            pattern == maskPipe ||
            pattern == maskAnySymbol) {
            return regexAnySymbol
        }

        var resultChars = [UInt8]()
        let utf8 = pattern.utf8
        var currentIndex = utf8.startIndex

        @inline(__always) func peekNext() -> UInt8? {
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
                resultChars.append(Chars.BACKSLASH)
                resultChars.append(char)
            case Chars.PIPE:
                let nextChar = peekNext()

                if currentIndex == utf8.startIndex {
                    if nextChar == Chars.PIPE {
                        // This is a start URL mask: `||`
                        resultChars.append(contentsOf: regexStartUrl)

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
                    resultChars.append(Chars.BACKSLASH)
                    resultChars.append(char)
                }
            case Chars.CARET:
                let nextChar = peekNext()

                if nextChar == nil {
                    resultChars.append(contentsOf: regexEndSeparator)
                } else {
                    resultChars.append(contentsOf: regexSeparator)
                }
            case Chars.WILDCARD:
                resultChars.append(contentsOf: regexAnySymbolChars)
            default:
                if char > 127 {
                    throw SyntaxError.invalidPattern(message: "Non ASCII characters are not supported")
                }

                resultChars.append(char)
            }

            currentIndex = utf8.index(after: currentIndex)
        }

        return String(decoding: resultChars, as: UTF8.self)
    }
}
