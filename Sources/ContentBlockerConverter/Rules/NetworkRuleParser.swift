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
                    continue;
                }

                // ignore $/
                if (index < maxIndex && ruleText[safeIndex: index + 1] == Chars.SLASH) {
                    continue;
                }

                return index;
            default:
                break;
            }
        }

        return -1;
    }

    /**
    * Searches for domain name in rule text and transforms it to punycode if needed.
    */
    static func getAsciiDomainRule(pattern: String?) -> String? {
        if pattern == nil {
            return pattern;
        }

        if pattern!.isASCII() {
            return pattern;
        }

        let domain = NetworkRuleParser.parseRuleDomain(pattern: pattern! as NSString);
        return pattern!.replacingOccurrences(of: domain, with: domain.idnaEncoded!);
    }

    static func parseRuleDomain(pattern: NSString) -> String {
        let starts = ["||", "@@||", "http://www.", "https://www.", "http://", "https://", "//"]
        let contains = ["/", "^"]

        var startIndex = 0
        for start in starts {
            if pattern.hasPrefix(start) {
                startIndex = start.unicodeScalars.count
                break
            }
        }

        var endIndex = NSNotFound
        for end in contains {
            let range = pattern.range(of: end, options: .literal, range: NSRange(location: startIndex, length: pattern.length - startIndex))
            let index = range.location
            if (index != NSNotFound) {
                endIndex = index;
                break;
            }
        }

        if endIndex == NSNotFound {
            return pattern.substring(from: startIndex)
        }

        return pattern.substring(with: NSRange(location: startIndex, length: endIndex - startIndex))
    }

    // TODO(ameshkov): !!! Change to UTF8View
    struct BasicRuleParts {
        var pattern: String?;
        var options: String?;
        var whitelist = false;
    }
}
