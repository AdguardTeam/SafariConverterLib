import Foundation
import Punycode

/**
 * Network rules parser
 */
class NetworkRuleParser {
    private static let MASK_WHITE_LIST = "@@";
    private static let MASK_WHITE_LIST_UTF8 = [Chars.AT_CHAR, Chars.AT_CHAR]
    private static let REPLACE_OPTION_MARKER = Array("$replace=".utf8)
    
    // Parses network rule in its basic parts: pattern and options string
    static func parseRuleText(ruleText: String) throws -> BasicRuleParts {
        var ruleParts = BasicRuleParts()
        
        // We'll be dealing with UTF8View when parsing.
        let utfString = ruleText.utf8
        
        // start index of the rule pattern
        //
        // a normal network rule looks like this:
        // [@@] pattern [$options]
        var startIndex = 0
        
        if utfString.starts(with: MASK_WHITE_LIST_UTF8) {
            ruleParts.whitelist = true
            startIndex = 2
        }
        
        if (utfString.count <= startIndex) {
            throw SyntaxError.invalidRule(message: "Rule is too short")
        }
        
        guard let utfStartIndex = utfString.index(utfString.startIndex, offsetBy: startIndex, limitedBy: utfString.endIndex)
        else {
            throw SyntaxError.invalidRule(message: "Invalid start index")
        }
        
        var pattern = utfString[utfStartIndex...]
        
        // This is a regular expression rule without options
        if pattern.first! == Chars.SLASH && pattern.last! == Chars.SLASH &&
            !pattern.includes(REPLACE_OPTION_MARKER) {
            
            ruleParts.pattern = String(decoding: pattern, as: UTF8.self)
            
            return ruleParts
        }
        
        let delimeterIndex = findOptionsDelimeterIndex(ruleText: utfString)
        if (delimeterIndex == utfString.count - 1) {
            throw SyntaxError.invalidRule(message: "Invalid options")
        }
        
        if (delimeterIndex >= 0) {
            var utfDelimiterIndex = utfString.index(utfString.startIndex, offsetBy: delimeterIndex, limitedBy: utfString.endIndex)
            
            pattern = utfString[utfStartIndex..<utfDelimiterIndex!]
            
            utfString.formIndex(after: &utfDelimiterIndex!)
            let options = utfString[utfDelimiterIndex!...]
            
            ruleParts.pattern = String(decoding: pattern, as: UTF8.self)
            ruleParts.options = String(decoding: options, as: UTF8.self)
        } else {
            ruleParts.pattern = String(decoding: pattern, as: UTF8.self)
        }
        
        return ruleParts
    }
    
    // Looks for the options delimiter ($) in a network rule.
    private static func findOptionsDelimeterIndex(ruleText: String.UTF8View) -> Int {
        let maxIndex = ruleText.count - 1
        for i in 0...maxIndex {
            let index = maxIndex - i
            let char = ruleText[safeIndex: index]
            switch char {
            case Chars.DOLLAR:
                // ignore \$
                if (index > 0 && ruleText[safeIndex: index - 1] == Chars.BACKSLASH) {
                    continue
                }
                
                // ignore $/
                if (index < maxIndex && ruleText[safeIndex: index + 1] == Chars.SLASH) {
                    continue
                }
                
                return index
            default:
                break
            }
        }
        
        return -1
    }
    
    /// Searches for domain name in rule text and transforms it to punycode if required.
    static func encodeDomainIfRequired(pattern: String?) -> String? {
        if pattern == nil {
            return pattern
        }
        
        if pattern!.isASCII() {
            return pattern
        }
        
        let domain = NetworkRuleParser.parseRuleDomain(pattern: pattern!)
        
        return pattern!.replacingOccurrences(of: domain, with: domain.idnaEncoded!)
    }
    
    /// Parses domain name from a basic rule text.
    ///
    /// For instance, for ||example.org^ it will return example.org.
    static func parseRuleDomain(pattern: String) -> String {
        let starts = ["||", "@@||", "http://www.", "https://www.", "http://", "https://", "//"]
        let contains = [Chars.SLASH, Chars.CARET]
        
        var startIndex = pattern.utf8.startIndex
        for start in starts {
            if pattern.utf8.starts(with: start.utf8) {
                startIndex = pattern.utf8.index(pattern.utf8.startIndex, offsetBy: start.utf8.count)
                break
            }
        }
        
        var endIndex: String.Index?
        
        for end in contains {
            endIndex = pattern.utf8.lastIndex(of: end)
            if endIndex != nil {
                break
            }
        }
        
        if endIndex == nil {
            return String(pattern[startIndex...])
        }
        
        return String(pattern[startIndex..<endIndex!])
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
        var pattern: String?;
        var options: String?;
        var whitelist = false;
    }
}
