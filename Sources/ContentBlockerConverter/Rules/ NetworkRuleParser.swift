import Foundation

/**
 *  Parser
 */
class NetworkRuleParser {
    private static let MASK_WHITE_LIST = "@@";
    
    /**
     * parseRuleText splits the rule text into multiple parts.
     * @param ruleText - original rule text
     * @returns basic rule parts
     *
     * @throws error if the rule is empty (for instance, empty string or `@@`)
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
            && (ruleParts.pattern?.indexOf(target: "$replace=") == nil)) {
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
        for (index, char) in ruleText.enumerated().reversed() {
            if (char == "$") {
                // ignore \$
                if (index > 0 && Array(ruleText)[index - 1] == "\\") {
                    continue;
                }
                
                // ignore $/
                if (index + 1 < ruleText.count && Array(ruleText)[index + 1] == "/") {
                    continue;
                }
                
                return index;
            }
        }
        
        return -1;
    }
    
    struct BasicRuleParts {
        var pattern: String?;
        var options: String?;
        var whitelist = false;
    }
}
