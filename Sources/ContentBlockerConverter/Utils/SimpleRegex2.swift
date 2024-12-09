import Foundation

/**
 * Regex helper
 */
class SimpleRegex2 {
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
    
    /**
     * Characters to be escaped in the regex
     * https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
     * should be escaped . * + ? ^ $ { } ( ) | [ ] / \
     * except of * | ^
     */
    private static let CHARS_TO_ESCAPE = [
        ".".utf8.first!,
        "+".utf8.first!,
        "?".utf8.first!,
        "$".utf8.first!,
        "{".utf8.first!,
        "}".utf8.first!,
        "(".utf8.first!,
        ")".utf8.first!,
        "[".utf8.first!,
        "]".utf8.first!,
        "/".utf8.first!,
        "\\".utf8.first!
    ]
    private static let charPipe = "|".utf8.first!
    private static let charSeparator = "^".utf8.first!
    private static let charWildcard = "*".utf8.first!
    
    /// Creates a regular expression from a network rule pattern.
    public static func createRegexText(str: String) -> String {
        if (str == maskStartUrl ||
            str == maskPipe ||
            str == maskAnySymbol) {
            return regexAnySymbol
        }
        
        var result = ""
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
                case charWildcard:
                    resultChars.append(contentsOf: regexAnySymbolChars)
                default:
                    resultChars.append(char)
                }
            }
            
            i += 1
        }
        
        return String(bytes: resultChars, encoding: .utf8)!
    }
}
