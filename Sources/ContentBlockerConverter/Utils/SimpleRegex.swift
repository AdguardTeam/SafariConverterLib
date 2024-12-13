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

    /// Characters to be escaped in the regular expressions.
    ///
    /// Source:
    /// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
    ///
    /// '\*', '|', '^' are processed differently.
    private static let CHARS_TO_ESCAPE = [
        UInt8(ascii: "."),
        UInt8(ascii: "+"),
        UInt8(ascii: "?"),
        UInt8(ascii: "$"),
        UInt8(ascii: "{"),
        UInt8(ascii: "}"),
        UInt8(ascii: "("),
        UInt8(ascii: ")"),
        UInt8(ascii: "["),
        UInt8(ascii: "]"),
        UInt8(ascii: "/"),
        UInt8(ascii: "\\"),
    ]
    
    /// Creates a regular expression from a network rule pattern.
    public static func createRegexText(str: String) -> String {
        if (str == "" ||
            str == maskStartUrl ||
            str == maskPipe ||
            str == maskAnySymbol) {
            return regexAnySymbol
        }

        var resultChars = [UInt8]()
        
        let maxIndex = str.utf8.count - 1
        var i = 0
        while i <= maxIndex {
            let char = str.utf8[safeIndex: i]!
            
            if CHARS_TO_ESCAPE.contains(char) {
                resultChars.append(Chars.BACKSLASH)
                resultChars.append(char)
            } else {
                switch char {
                case Chars.PIPE:
                    if i == 0 {
                        let nextChar = str.utf8[safeIndex: i+1]
                        if nextChar == Chars.PIPE {
                            resultChars.append(contentsOf: regexStartUrl)
                            i += 1 // increment i as we processed next char already
                        } else {
                            resultChars.append(contentsOf: regexStartString)
                        }
                    } else if i == maxIndex {
                        resultChars.append(contentsOf: regexEndString)
                    } else {
                        resultChars.append(Chars.BACKSLASH)
                        resultChars.append(char)
                    }
                case Chars.CARET:
                    if i == maxIndex {
                        resultChars.append(contentsOf: regexEndSeparator)
                    } else {
                        resultChars.append(contentsOf: regexSeparator)
                    }
                case Chars.WILDCARD:
                    resultChars.append(contentsOf: regexAnySymbolChars)
                default:
                    resultChars.append(char)
                }
            }
            
            i += 1
        }

        return String(decoding: resultChars, as: UTF8.self)
    }
}
