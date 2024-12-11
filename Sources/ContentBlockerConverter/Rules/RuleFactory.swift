import Foundation
import Shared

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
    func createRules(lines: [String], progress: Progress? = nil) -> [Rule] {
        var shouldContinue: Bool {
            !(progress?.isCancelled ?? false)
        }

        var result = [Rule]()

        var networkRules = [NetworkRule]()
        var badfilterRules: [String: [NetworkRule]] = [:]

        for line in lines {
            guard shouldContinue else { return [] }
            
            var ruleLine = line
            if !ruleLine.isContiguousUTF8 {
                // This is of UTMOST importance for the conversion performance.
                // Converter heavily relies on the UTF-8 view when parsing the rules
                // and without having contigious UTF-8 any operation is painfully
                // slow.
                ruleLine.makeContiguousUTF8()
            }
            ruleLine = ruleLine.trimmingCharacters(in: .whitespacesAndNewlines)

            let convertedLines = RuleFactory.converter.convertRule(ruleText: ruleLine)
            for convertedLine in convertedLines {
                guard shouldContinue else { return [] }

                guard let rule = safeCreateRule(ruleText: convertedLine) else { continue }
                if let networkRule = rule as? NetworkRule {
                    if networkRule.badfilter {
                        badfilterRules[networkRule.urlRuleText, default: []].append(networkRule)
                    } else {
                        networkRules.append(networkRule)
                    }
                } else {
                    result.append(rule)
                }
            }
        }

        guard shouldContinue else { return [] }

        result += RuleFactory.applyBadFilterExceptions(rules: networkRules, badfilterRules: badfilterRules)

        return result
    }
    
    /// Filters out rules that are negated by $badfilter rules.
    static func applyBadFilterExceptions(rules: [NetworkRule], badfilterRules: [String: [NetworkRule]]) -> [Rule] {
        var result = [Rule]()
        for rule in rules {
            let negatingRule = badfilterRules[rule.urlRuleText]?.first(where: { $0.negatesBadfilter(specifiedRule: rule) })
            if negatingRule == nil {
                result.append(rule)
            }
        }
        
        return result
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
            if (ruleText == nil || ruleText! == "" || ruleText!.hasPrefix("!")) {
                return nil;
            }
            
            // TODO add proper validation
            if (ruleText!.utf8.count < 3) {
                throw SyntaxError.invalidRule(message: "Invalid rule text");
            }
            
            if (RuleFactory.isCosmetic(ruleText: ruleText!)) {
                return try CosmeticRule(ruleText: ruleText!);
            }

            return try NetworkRule(ruleText: ruleText!);
        } catch {
            Logger.log("(RuleFactory) - Unexpected error: \(error) while creating rule from: \(String(describing: ruleText))");
            throw error;
        }
    };
    
    
    /**
     * Checks if the rule is cosmetic (CSS, JS) or not
     */
    static func isCosmetic(ruleText: String) -> Bool {
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText);
        return markerInfo.index != -1;
    }
}
