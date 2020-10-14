import Foundation

/**
 * Regex helper
 */
class SimpleRegex {
    /**
     * Improved regular expression instead of UrlFilterRule.REGEXP_START_URL (||)
     * Please note, that this regular expression matches only ONE level of subdomains
     * Using ([a-z0-9-.]+\\.)? instead increases memory usage by 10Mb
     */
    private static let  URL_FILTER_REGEXP_START_URL = #"^[htpsw]+:\/\/([a-z0-9-]+\.)?"#;
    /** Simplified separator (to fix an issue with $ restriction - it can be only in the end of regexp) */
    private static let  URL_FILTER_REGEXP_SEPARATOR = "[/:&?]?";
    
    // Constants
    private static let maskStartUrl = "||";
    private static let maskPipe = "|";
    private static let maskSeparator = "^";
    private static let maskAnySymbol = "*";

    private static let regexAnySymbol = ".*";
    private static let regexSeparator = URL_FILTER_REGEXP_SEPARATOR;
    private static let regexStartUrl = URL_FILTER_REGEXP_START_URL;
    private static let regexStartString = "^";
    private static let regexEndString = "$";

    /**
     * Characters to be escaped in the regex
     * https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
     * should be escaped . * + ? ^ $ { } ( ) | [ ] / \
     * except of * | ^
     */
    private static let CHARS_TO_ESCAPE = [
        ".".utf16.first!,
        "?".utf16.first!,
        "$".utf16.first!,
        "{".utf16.first!,
        "}".utf16.first!,
        "(".utf16.first!,
        ")".utf16.first!,
        "[".utf16.first!,
        "]".utf16.first!,
        "/".utf16.first!
    ]
    private static let charPipe = "|".utf16.first!
    private static let charSeparator = "^".utf16.first!
    private static let charWildcard = "*".utf16.first!

    /**
     * Creates regex
     */
    public static func createRegexText(str: String) -> String? {
        if (str == maskStartUrl ||
                str == maskPipe ||
                str == maskAnySymbol) {
            return regexAnySymbol;
        }
        
        var result = ""
        let nstr = str as NSString
        
        let maxIndex = nstr.length - 1
        var i = 0
        while i <= maxIndex {
            let char = nstr.character(at: i)

            if CHARS_TO_ESCAPE.contains(char) {
                result.append("\\")
                result.append(Character(UnicodeScalar(char)!))
            } else {
                switch char {
                case charPipe:
                    if i == 0 {
                        let nextChar = nstr.character(at: i+1)
                        if nextChar == charPipe {
                            result.append(regexStartUrl)
                            i += 1 // increment i as we processed next char already
                        } else {
                            result.append(regexStartString)
                        }
                    } else if i == maxIndex {
                        result.append(regexEndString)
                    } else {
                        result.append("\\")
                        result.append(Character(UnicodeScalar(char)!))
                    }
                case charSeparator:
                    result.append(regexSeparator)
                case charWildcard:
                    result.append(regexAnySymbol)
                default:
                    result.append(Character(UnicodeScalar(char)!))
                }
            }
            
            i += 1
        }

        return result;
    }

    /**
     * Check if target string matches regex
     */
    static func isMatch(regex: NSRegularExpression, target: String) -> Bool {
        let matchCount = regex.numberOfMatches(in: target, options: [], range: NSMakeRange(0, target.count))
        return matchCount > 0;
    }

    /**
     * Returns target string matches
     */
    static func matches(regex: NSRegularExpression, target: String) -> [String] {
        let matches  = regex.matches(in: target, options: [], range: NSMakeRange(0, target.count))
        return matches.map { match in
            return String(target[Range(match.range, in: target)!])
        }
    }
}
