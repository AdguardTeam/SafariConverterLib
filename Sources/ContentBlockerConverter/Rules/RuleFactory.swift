import Foundation
import Shared

/// RuleFactory is responsible for parsing AdGuard rules.
class RuleFactory {
    private static let converter = RuleConverter()
    private var errorsCounter: ErrorsCounter
    
    init(errorsCounter: ErrorsCounter) {
        self.errorsCounter = errorsCounter
    }
    
    /// Creates AdGuard rules from the specified lines.
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
            if ruleLine.isEmpty || RuleFactory.isComment(ruleText: ruleLine) {
                continue
            }

            let convertedLines = RuleFactory.converter.convertRule(ruleText: ruleLine)
            for convertedLine in convertedLines {
                guard shouldContinue else { return [] }

                if convertedLine != nil {
                    guard let rule = safeCreateRule(ruleText: convertedLine!) else { continue }
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
    
    /// Helper for safely create a rule or increment an errors counter.
    private func safeCreateRule(ruleText: String) -> Rule? {
        do {
            return try RuleFactory.createRule(ruleText: ruleText)
        } catch {
            self.errorsCounter.add()
            return nil
        }
    }
    
    /// Creates an AdGuard rule from the rule text.
    static func createRule(ruleText: String) throws -> Rule? {
        do {
            if ruleText.isEmpty || isComment(ruleText: ruleText) {
                return nil
            }
            
            if (ruleText.utf8.count < 3) {
                throw SyntaxError.invalidRule(message: "The rule is too short")
            }
            
            if (RuleFactory.isCosmetic(ruleText: ruleText)) {
                return try CosmeticRule(ruleText: ruleText)
            }

            return try NetworkRule(ruleText: ruleText)
        } catch {
            Logger.log("(RuleFactory) - Unexpected error: \(error) while creating rule from: \(String(describing: ruleText))")
            throw error
        }
    }
   
    /// Checks if the rule is a cosmetic (CSS/JS) or not.
    static func isCosmetic(ruleText: String) -> Bool {
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText)
        return markerInfo.index != -1
    }
    
    /// Checks if the rule is a comment.
    ///
    /// There are two types of comments:
    /// A line starts with '!'
    /// A line starts with '# '
    static func isComment(ruleText: String) -> Bool {
        switch ruleText.utf8.first {
            case Chars.EXCLAMATION:
            return true
        case Chars.HASH:
            if ruleText.utf8.count == 1 {
                return true
            }
            let nextChar = ruleText.utf8[ruleText.utf8.index(after: ruleText.utf8.startIndex)]
            if nextChar == Chars.WHITESPACE {
                return true
            }

            return false
        default:
            return false
        }
    }
}
