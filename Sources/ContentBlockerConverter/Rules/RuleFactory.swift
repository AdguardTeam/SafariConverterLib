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
        
        var networkRules = [NetworkRule]();
        var badfilterRules = [NetworkRule]();
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines) as NSString;
            let convertedLines = RuleFactory.converter.convertRule(rule: trimmed);
            for convertedLine in convertedLines {
                let rule = safeCreateRule(ruleText: convertedLine);
                if (rule != nil) {
                    if (rule is NetworkRule) {
                        let networkRule = rule as! NetworkRule;
                        if (networkRule.badfilter != nil) {
                            badfilterRules.append(networkRule);
                        } else {
                            networkRules.append(networkRule);
                        }
                    } else {
                        result.append(rule!);
                    }
                }
            }
        }
        
        result += RuleFactory.applyBadFilterExceptions(rules: networkRules, badfilterRules: badfilterRules);
        return result;
    }
    
    /**
     * Filters rules with badfilter exceptions
     */
    static func applyBadFilterExceptions(rules: [NetworkRule], badfilterRules: [NetworkRule]) -> [Rule] {
        var badfilters = [String]();
        for badFilter in badfilterRules {
            badfilters.append(badFilter.badfilter!);
        }
        
        var result = [Rule]();
        for rule in rules {
            if (RuleFactory.isRuleNegatedByBadFilters(rule: rule, badfilterRules: badfilterRules)) {
                continue;
            }
            
            result.append(rule);
        }
        
        return result;
    }
    
    static func isRuleNegatedByBadFilters(rule: NetworkRule, badfilterRules: [NetworkRule]) -> Bool {
        for badfilter in badfilterRules {
            if (badfilter.negatesBadfilter(specifiedRule: rule)) {
                return true;
            }
        }
        
        return false;
    }
    
    func safeCreateRule(ruleText: NSString?) -> Rule? {
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
    static func createRule(ruleText: NSString?) throws -> Rule? {
        do {
            if (ruleText == nil || ruleText! == "" || ruleText!.hasPrefix("!") || ruleText!.hasPrefix(" ") || ruleText!.contains(" - ")) {
                return nil;
            }
            
            if (ruleText!.length < 3) {
                return nil;
            }
            
            if (RuleFactory.isCosmetic(ruleText: ruleText!)) {
                return try CosmeticRule(ruleText: ruleText!);
            }

            return try NetworkRule(ruleText: ruleText!);
        } catch {
            Logger.log("AG: ContentBlockerConverter: Unexpected error: \(error) while creating rule from: \(String(describing: ruleText))");
            throw error;
        }
    };
    
    
    /**
     * Checks if the rule is cosmetic (CSS, JS) or not
     */
    private static func isCosmetic(ruleText: NSString) -> Bool {
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText);
        return markerInfo.index != -1;
    }
}
