import Foundation

/**
 * Rule factory creates rules from source texts
 */
class RuleFactory {
    
    private static let converter = RuleConverter();
    
    private var errorsCounter: ErrorsCounter;
    
    init(errorsCounter: ErrorsCounter) {
        self.errorsCounter = errorsCounter;
    }
    
    /**
     * Creates rules from lines
     */
    func createRules(lines: [String]) -> [Rule] {
        var result = [Rule]();
        var badfilterRules = [String]();
        
        for line in lines {
            let convertedLines = RuleFactory.converter.convertRule(rule: line);
            for convertedLine in convertedLines {
                let rule = safeCreateRule(ruleText: convertedLine);
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
        
        return RuleFactory.applyBadFilterExceptions(rules: result, badfilterRules: badfilterRules);
    }
    
    /**
     * Filters rules with badfilter exceptions
     */
    static func applyBadFilterExceptions(rules: [Rule], badfilterRules: [String]) -> [Rule] {
        var result = [Rule]();
        for rule in rules {
            if (badfilterRules.firstIndex(of: rule.ruleText) == nil) {
                result.append(rule);
            }
        }
        
        return result;
    }
    
    func safeCreateRule(ruleText: String?) -> Rule? {
        do {
            return try RuleFactory.createRule(ruleText: ruleText);
        } catch {
            self.errorsCounter.add();
            return nil;
        }
    }
    
    /**
     * Creates rule object from source text
     */
    static func createRule(ruleText: String?) throws -> Rule? {
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
            NSLog("AG: ContentBlockerConverter: Unexpected error: \(error) while creating rule from: \(String(describing: ruleText))");
            throw error;
        }
    };
    
    private static func isCosmetic(ruleText: String) -> Bool {
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText);
        return markerInfo.index != -1;
    }
}
