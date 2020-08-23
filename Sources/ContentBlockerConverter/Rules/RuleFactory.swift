import Foundation

class RuleFactory {
    
    private static let converter = RuleConverter();
    
    // Parses rules from lines
    static func createRules(lines: [String]) -> [Rule] {
        var result = [Rule]();
        for line in lines {
            let convertedLines = converter.convertRule(rule: line);
            for convertedLine in convertedLines {
                let rule = createRule(ruleText: convertedLine);
                if (rule != nil) {
                    result.append(rule!);
                } else {
                    // NSLog("AG: ContentBlockerConverter: Unexpected error");
                }
            }
        }
        
        return result;
    }
    
    static func createRule(ruleText: String?) -> Rule? {
        if (ruleText == nil || ruleText! == "" || ruleText!.hasPrefix("!") || ruleText!.hasPrefix(" ") || ruleText!.indexOf(target: " - ") > 0) {
            return nil;
        }

        return createAGRule(ruleText: ruleText!);
    };
    
    private static func createAGRule(ruleText: String) -> Rule? {
        // TODO: Take from ts-url
        
        return Rule();
    }
}
