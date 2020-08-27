import Foundation

class RuleFactory {
    
    private static let converter = RuleConverter();
    
    // Parses rules from lines
    static func createRules(lines: [String]) -> [Rule] {
        var result = [Rule]();
        var badfilterRules = [String]();
        
        for line in lines {
            let convertedLines = converter.convertRule(rule: line);
            for convertedLine in convertedLines {
                let rule = createRule(ruleText: convertedLine);
                if (rule != nil) {
                    if (rule is NetworkRule) {
                        let networkRule = rule as! NetworkRule;
                        if (networkRule.badfilter != nil) {
                            badfilterRules.append(networkRule.badfilter!);
                            continue;
                        }
                    }
                    
                    result.append(rule!);
                }
            }
        }
        
        return applyBadFilterExceptions(rules: result, badfilterRules: badfilterRules);
    }
    
    static func applyBadFilterExceptions(rules: [Rule], badfilterRules: [String]) -> [Rule] {
        var result = [Rule]();
        for rule in rules {
            if (badfilterRules.firstIndex(of: rule.ruleText) == nil) {
                result.append(rule);
            }
        }
        
        return result;
    }
    
    static func createRule(ruleText: String?) -> Rule? {
        do {
            if (ruleText == nil || ruleText! == "" || ruleText!.hasPrefix("!") || ruleText!.hasPrefix(" ") || ruleText!.indexOf(target: " - ") > 0) {
                return nil;
            }
            
            if (ruleText!.count < 3) {
                return nil;
            }

            if (RuleFactory.isCosmetic(ruleText: ruleText!)) {
                return try CosmeticRule(ruleText: ruleText!);
            }

        
            return try NetworkRule(ruleText: ruleText!);
        } catch {
            ErrorsCounter.instance.add();
            return nil;
        }
    };
    
    private static func isCosmetic(ruleText: String) -> Bool {
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText);
        return markerInfo.index != -1;
    }
}
