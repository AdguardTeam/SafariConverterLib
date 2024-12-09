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
    private static let  URL_FILTER_REGEXP_END_SEPARATOR = "([\\/:&\\?].*)?$";
    private static let  URL_FILTER_REGEXP_SEPARATOR = "[/:&?]?";
    
    // Constants
    private static let maskStartUrl = "||" as NSString;
    private static let maskPipe = "|" as NSString;
    private static let maskSeparator = "^" as NSString;
    private static let maskAnySymbol = "*" as NSString;

    private static let regexAnySymbol = ".*";
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
        "+".utf16.first!,
        "?".utf16.first!,
        "$".utf16.first!,
        "{".utf16.first!,
        "}".utf16.first!,
        "(".utf16.first!,
        ")".utf16.first!,
        "[".utf16.first!,
        "]".utf16.first!,
        "/".utf16.first!,
        "\\".utf16.first!
    ]
    private static let charPipe = "|".utf16.first!
    private static let charSeparator = "^".utf16.first!
    private static let charWildcard = "*".utf16.first!

    /**
     * Creates regex
     */
    public static func createRegexText(str: NSString) -> NSString? {
        if (str == maskStartUrl ||
                str == maskPipe ||
                str == maskAnySymbol) {
            return regexAnySymbol as NSString;
        }
        
        var result = ""
        
        let maxIndex = str.length - 1
        var i = 0
        while i <= maxIndex {
            let char = str.character(at: i)

            if CHARS_TO_ESCAPE.contains(char) {
                result.append("\\")
                result.append(Character(UnicodeScalar(char)!))
            } else {
                switch char {
                case charPipe:
                    if i == 0 {
                        let nextChar = str.character(at: i+1)
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
                    if i == maxIndex {
                        result.append(URL_FILTER_REGEXP_END_SEPARATOR)
                    } else {
                        result.append(URL_FILTER_REGEXP_SEPARATOR)
                    }
                case charWildcard:
                    result.append(regexAnySymbol)
                default:
                    result.append(Character(UnicodeScalar(char)!))
                }
            }
            
            i += 1
        }

        return result as NSString;
    }

    /**
     * Check if target string matches regex
     */
    static func isMatch(regex: NSRegularExpression, target: NSString) -> Bool {
        let matchCount = regex.numberOfMatches(in: target as String, options: [], range: NSMakeRange(0, target.length))
        return matchCount > 0;
    }
    
    static func isMatch2(regex: NSRegularExpression, target: String) -> Bool {
        let matchCount = regex.numberOfMatches(in: target, options: [], range: NSMakeRange(0, target.utf16.count))
        return matchCount > 0;
    }
    
    // TODO(ameshkov): !!! Rename, rework
    static func isMatch3(regex: NSRegularExpression, target: Substring.UTF8View) -> Bool {
        let str = String(decoding: target, as: UTF8.self)
        
        // Note that we use UTF-16 view to count strings as NSString internal
        // representation is UTF-16 (and it is used by NSRegularExpression).
        let range = NSMakeRange(0, str.utf16.count)
        
        let matchCount = regex.numberOfMatches(in: str, options: [], range: range)

        return matchCount > 0;
    }

    /**
     * Returns target string matches
     */
    static func matches(regex: NSRegularExpression, target: NSString) -> [String] {
        let matches  = regex.matches(in: target as String, options: [], range: NSMakeRange(0, target.length))
        return matches.map { match in
            return target.substring(with: match.range)
        }
    }
    
    /**
     * Returns target string matches
     */
    static func matches2(regex: NSRegularExpression, target: String) -> [String] {
        let str: NSString = target as NSString

        let matches  = regex.matches(in: target, options: [], range: NSMakeRange(0, str.length))

        return matches.map { match in
            return str.substring(with: match.range)
        }
    }
}
