import Foundation
import Punycode

/**
 * Network rules parser
 */
class NetworkRuleParser {
    private static let MASK_WHITE_LIST = "@@";

    /**
     * Splits the rule text into multiple parts
     */
    static func parseRuleText(ruleText: NSString) throws -> BasicRuleParts {
        var ruleParts = BasicRuleParts()

        var startIndex = 0
        if (ruleText.hasPrefix(MASK_WHITE_LIST)) {
            ruleParts.whitelist = true
            startIndex = 2
        }

        if (ruleText.length <= startIndex) {
            throw SyntaxError.invalidRule(message: "Rule is too short")
        }

        // Setting pattern to rule text (for the case of empty options)
        ruleParts.pattern = ruleText.substring(from: startIndex)

        // Avoid parsing options inside of a regex rule
        if (ruleParts.pattern!.hasPrefix("/")
                && ruleParts.pattern!.hasSuffix("/")
                && (ruleParts.pattern?.indexOf(target: "$replace=") == -1)) {
            return ruleParts
        }

        let delimeterIndex = NetworkRuleParser.findOptionsDelimeterIndex(ruleText: ruleText)
        if (delimeterIndex == ruleText.length - 1) {
            throw SyntaxError.invalidRule(message: "Invalid options")
        }

        if (delimeterIndex >= 0) {
            ruleParts.pattern = (ruleText.substring(to: delimeterIndex) as NSString).substring(from: startIndex)
            ruleParts.options = ruleText.substring(from: delimeterIndex + 1)
        }

        return ruleParts
    }

    private static func findOptionsDelimeterIndex(ruleText: NSString) -> Int {
        let delim: unichar = "$".utf16.first!
        let slash: unichar = "\\".utf16.first!
        let bslash: unichar = "/".utf16.first!

        let maxIndex = ruleText.length - 1
        for i in 0...maxIndex {
            let index = maxIndex - i;
            let char = ruleText.character(at: index)
            switch char {
            case delim:
                // ignore \$
                if (index > 0 && ruleText.character(at: index - 1) == slash) {
                    continue;
                }

                // ignore $/
                if (index < maxIndex && ruleText.character(at: index + 1) == bslash) {
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

    struct BasicRuleParts {
        var pattern: String?;
        var options: String?;
        var whitelist = false;
    }
}
