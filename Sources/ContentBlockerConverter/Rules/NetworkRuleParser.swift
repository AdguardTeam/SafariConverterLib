import Foundation

/**
 * Network rules parser
 */
class NetworkRuleParser {
    private static let MASK_WHITE_LIST = "@@";

    /**
     * Splits the rule text into multiple parts
     */
    static func parseRuleText(ruleText: String) throws -> BasicRuleParts {
        var ruleParts = BasicRuleParts();

        var startIndex = 0;
        if (ruleText.hasPrefix(MASK_WHITE_LIST)) {
            ruleParts.whitelist = true;
            startIndex = MASK_WHITE_LIST.count;
        }

        if (ruleText.count <= startIndex) {
            throw SyntaxError.invalidRule(message: "Rule is too short");
        }

        // Setting pattern to rule text (for the case of empty options)
        ruleParts.pattern = ruleText.subString(startIndex: startIndex);

        // Avoid parsing options inside of a regex rule
        if (ruleParts.pattern!.hasPrefix("/")
            && ruleParts.pattern!.hasSuffix("/")
            && (ruleParts.pattern?.indexOf(target: "$replace=") == -1)) {
            return ruleParts;
        }

        let delimeterIndex = NetworkRuleParser.findOptionsDelimeterIndex(ruleText: ruleText);
        if (delimeterIndex >= 0) {
            ruleParts.pattern = ruleText.subString(startIndex: startIndex, toIndex: delimeterIndex);
            ruleParts.options = ruleText.subString(startIndex: delimeterIndex + 1);
        }

        return ruleParts;
    }

    private static func findOptionsDelimeterIndex(ruleText: String) -> Int {
        var index = -1;
        var maxLength = ruleText.count;
        
        repeat {
            index = ruleText.lastIndexOf(target: "$", maxLength: maxLength);
            if (index == -1) {
                return index;
            }
            
            maxLength = index;
            
            // ignore \$
            if (index > 0 && Array(ruleText)[index - 1] == "\\") {
                continue;
            }
            
            // ignore $/
            if (index + 1 < ruleText.count && Array(ruleText)[index + 1] == "/") {
                continue;
            }
            
            return index;
        } while (index > -1)
        
        return index;
    }

    /**
    * Searches for domain name in rule text and transforms it to punycode if needed.
    */
    static func getAsciiDomainRule(pattern: String?) -> String? {
        if (pattern == nil) {
            return pattern;
        }

        if (pattern!.isUnicode()) {
            return pattern;
        }

        let domain = NetworkRuleParser.parseRuleDomain(pattern: pattern!);
        return pattern!.replacingOccurrences(of: domain, with: domain.idnaEncoded!);
    }

    private static func parseRuleDomain(pattern: String) -> String {
        let starts = ["http://www.", "https://www.", "http://", "https://", "||", "//"];
        let contains = ["/", "^"];

        var startIndex = 0;
        for start in starts {
            if (pattern.hasPrefix(start)) {
                startIndex = start.count;
                break;
            }
        }

        var endIndex = -1;
        for end in contains {
            let index = pattern.indexOf(target: end, startIndex: startIndex)
            if (index > -1) {
                endIndex = index;
                break;
            }
        }

        return endIndex == -1 ? pattern.subString(startIndex: startIndex) : pattern.subString(startIndex: startIndex, toIndex: endIndex);
    }

    struct BasicRuleParts {
        var pattern: String?;
        var options: String?;
        var whitelist = false;
    }
}
