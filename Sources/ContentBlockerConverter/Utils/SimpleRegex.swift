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
     * Special characters to escape
     */
    private static let SPECIAL_CHARS = [".", "?", "$", "{", "}", "(", ")", "[", "]", "/"];
    
    /**
    * Creates regex
    */
    public static func createRegexText(str: String) -> String? {
        if (str == maskStartUrl ||
            str == maskPipe ||
            str == maskAnySymbol) {
            return regexAnySymbol;
        }

        var regex = SimpleRegex.escapeRegExp(str: str);

        if (regex.hasPrefix(maskStartUrl)) {
            regex = regex.subString(startIndex: 0, toIndex: maskStartUrl.count) +
                replaceAll(str: regex.subString(startIndex: maskStartUrl.count, toIndex: regex.count - 1), find: "|", replace: "\\|") +
                regex.subString(startIndex: regex.count - 1);
        } else if (regex.hasPrefix(maskPipe)) {
            regex = regex.subString(startIndex: 0, toIndex: maskPipe.count) +
                replaceAll(str: regex.subString(startIndex: maskPipe.count, toIndex: regex.count - 1), find: "|", replace: "\\|") +
                regex.subString(startIndex: regex.count - 1);
        } else {
            regex = replaceAll(str: regex.subString(startIndex: 0, toIndex: regex.count - 1), find: "|", replace: "\\|") +
                regex.subString(startIndex: regex.count - 1);
        }

        // Replacing special url masks
        regex = replaceAll(str: regex, find: maskAnySymbol, replace: regexAnySymbol);
        regex = replaceAll(str: regex, find: maskSeparator, replace: regexSeparator);

        if (regex.hasPrefix(maskStartUrl)) {
            regex = regexStartUrl + regex.subString(startIndex: maskStartUrl.count);
        } else if (regex.hasPrefix(maskPipe)) {
            regex = regexStartString + regex.subString(startIndex: maskPipe.count);
        }
        if (regex.hasSuffix(maskPipe)) {
            regex = regex.subString(startIndex: 0, toIndex: regex.count - 1) + regexEndString;
        }

        return regex;
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
    
    /**
     * Escapes regular expression string
     * https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
     * should be escaped . * + ? ^ $ { } ( ) | [ ] / \
     * except of * | ^
     */
    private static func escapeRegExp(str: String) -> String {
        var result = str;
        
        for special in SimpleRegex.SPECIAL_CHARS {
            result = result.replacingOccurrences(of: special, with: "\\" + special);
        }
        
        return result;
    }
    
    private static func replaceAll(str: String, find: String, replace: String) -> String {
        return str.replacingOccurrences(of: find, with: replace);
    }
}
