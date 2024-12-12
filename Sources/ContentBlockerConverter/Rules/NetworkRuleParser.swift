import Foundation
import Punycode

/// Simple parser that is only capable of splitting network rule into basic parts.
/// The further complicated parsing is done by NetworkRule.
class NetworkRuleParser {
    private static let MASK_WHITE_LIST_UTF8 = [Chars.AT_CHAR, Chars.AT_CHAR]
    private static let REPLACE_OPTION_MARKER = Array("$replace=".utf8)
    
    /// Split the specified network rule into its basic parts: pattern and options strings.
    static func parseRuleText(ruleText: String) throws -> BasicRuleParts {
        var ruleParts = BasicRuleParts()
        
        let utf8 = ruleText.utf8
        var i = utf8.endIndex
        var start = utf8.startIndex
        var delimiterIndex: String.Index?

        if utf8.isEmpty {
            throw SyntaxError.invalidRule(message: "Rule is too short")
        }

        if utf8.starts(with: MASK_WHITE_LIST_UTF8) {
            start = utf8.index(utf8.startIndex, offsetBy: 2)
            ruleParts.whitelist = true
        }

        @inline(__always) func peekNext() -> UInt8? {
            let next = utf8.index(after: i)
            guard next < utf8.endIndex else { return nil }
            return utf8[next]
        }

        @inline(__always) func peekPrevious() -> UInt8? {
            guard i > start else { return nil }
            let previous = utf8.index(before: i)
            return utf8[previous]
        }

        // The first step is to find the options delimiter.
        // In order to do that we iterate over the string and look for the '$' character.
        // We also check that it's not escaped and that it's not likely a part of a regex.
        while i > start {
            i = utf8.index(before: i)
            
            let char = utf8[i]
            
            if char == Chars.DOLLAR {
                // Check that it's not escaped (\$) and that it's not likely a part of regex ($/).
                if peekPrevious() != Chars.BACKSLASH && peekNext() != Chars.SLASH {
                    delimiterIndex = i
                    
                    // Delimiter index found, exit
                    break
                }
            }
        }
        
        var optionsIndex = utf8.endIndex
        if delimiterIndex != nil {
            optionsIndex = utf8.index(after: delimiterIndex!)
        }

        if optionsIndex == utf8.endIndex {
            if start == utf8.startIndex {
                // Avoid allocating new String if it's possible.
                ruleParts.pattern = ruleText
            } else {
                ruleParts.pattern = String(ruleText[start...])
            }
        } else {
            ruleParts.pattern = String(ruleText[start..<delimiterIndex!])
            ruleParts.options = String(ruleText[optionsIndex...])
        }
        
        return ruleParts
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
        var pattern: String = ""
        var options: String?
        var whitelist = false
    }
}
