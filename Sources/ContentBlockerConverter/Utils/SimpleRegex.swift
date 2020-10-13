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
    * Creates regex
    */
    public static func createRegexText(str: String) -> String? {
        if (str == maskStartUrl ||
            str == maskPipe ||
            str == maskAnySymbol) {
            return regexAnySymbol;
        }

        var regex = SimpleRegex.escapeRegExp(str: str) as NSString;

        var replaced: String;
        if (regex.hasPrefix(maskStartUrl)) {
            let substring = (regex.substring(to: regex.length - 1) as NSString).substring(from: maskStartUrl.count);
            replaced = regex.substring(to: maskStartUrl.count) +
                replaceAll(str: substring, find: "|", replace: "\\|") +
                regex.substring(from: regex.length - 1);
        } else if (regex.hasPrefix(maskPipe)) {
            let substring = (regex.substring(to: regex.length - 1) as NSString).substring(from: maskPipe.count);
            replaced = regex.substring(to: maskPipe.count) +
                replaceAll(str: substring, find: "|", replace: "\\|") +
                regex.substring(from: regex.length - 1);
        } else {
            let substring = regex.substring(to: regex.length - 1);
            replaced = replaceAll(str: substring, find: "|", replace: "\\|") +
                regex.substring(from: regex.length - 1);
        }

        // Replacing special url masks
        regex = replaceAll(str: replaced, find: maskAnySymbol, replace: regexAnySymbol) as NSString;
        regex = replaceAll(str: regex as String, find: maskSeparator, replace: regexSeparator) as NSString;

        if (regex.hasPrefix(maskStartUrl)) {
            regex = regexStartUrl + regex.substring(from: maskStartUrl.count) as NSString;
        } else if (regex.hasPrefix(maskPipe)) {
            regex = regexStartString + regex.substring(from: maskPipe.count) as NSString;
        }
        
        if (regex.hasSuffix(maskPipe)) {
            regex = regex.substring(to: regex.length - 1) + regexEndString as NSString;
        }

        return regex as String;
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
    
    /**
     * Escapes regular expression string
     * https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
     * should be escaped . * + ? ^ $ { } ( ) | [ ] / \
     * except of * | ^
     */
    private static func escapeRegExp(str: String) -> String {
        let nsstring = str as NSString;
        let maxIndex = nsstring.length - 1;
        
        var result = "";
        
        for index in 0...maxIndex {
            let char = nsstring.character(at: index)
            if (CHARS_TO_ESCAPE.contains(char)) {
                result.append("\\");
            }
            
            result.append(Character(UnicodeScalar(char)!));
        }
        
        return result;
    }
    
    private static func replaceAll(str: String, find: String, replace: String) -> String {
        return (str as NSString).replacingOccurrences(of: find, with: replace);
    }
}
