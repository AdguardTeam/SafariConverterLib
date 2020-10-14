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

        regex = replaceAroundMask(regex: regex) as NSString;
        
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
    
    private static func replaceAroundMask(regex: NSString) -> String {
        let croppedEnd = regex.substring(to: regex.length - 1) as NSString;
        
        var mask: String? = nil;
        var newMask: String? = nil;
        if (regex.hasPrefix(maskStartUrl)) {
            mask = maskStartUrl;
            newMask = regexStartUrl;
        } else if (regex.hasPrefix(maskPipe)) {
            mask = maskPipe;
            newMask = regexStartString;
        }
    
        var replaceBody = croppedEnd as String;
        if (mask != nil) {
            replaceBody = croppedEnd.substring(from: mask!.count);
        }
        
        var replaced = replaceAll(str: replaceBody, find: "|", replace: "\\|");
        
        replaced = replaced + regex.substring(from: regex.length - 1);
        replaced = replaceSpecialUrlMasks(regex: replaced as NSString);
        
        if (newMask != nil) {
            replaced = newMask! + replaced;
        }
        
        return replaced;
    }
    
    private static func replaceSpecialUrlMasks(regex: NSString) -> String {
        // Replacing special url masks
        var replaced = regex as String;
        if (regex.contains(maskAnySymbol)) {
            replaced = replaceAll(str: regex as String, find: maskAnySymbol, replace: regexAnySymbol);
        }
        
        return replaceAll(str: replaced, find: maskSeparator, replace: regexSeparator);
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
