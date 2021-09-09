import Foundation

/**
 * Provides methods to manage allowlist and inverted allowlist rules without conversion
 */
public protocol WebExtensionHelpersProtocol {
    // Public method to check if provided rule is associated with the domain
    func userRuleIsAssociated(with domain: String, _ userRule: String) -> Bool
}

/**
 * Provides methods for web extension
 */
public class WebExtensionHelpers: WebExtensionHelpersProtocol {
    public init() {}
    
    /**
     * Parses domains from provided rule
     */
    func parseRuleDomains(ruleText: String) -> [String] {
        do {
            let rule = try RuleFactory.createRule(ruleText: ruleText as NSString)
            if rule == nil {
                return []
            }
            
            var ruleDomains = rule!.permittedDomains + rule!.restrictedDomains
            
            if !RuleFactory.isCosmetic(ruleText: ruleText as NSString) {
                let ruleDomain = (rule! as! NetworkRule).parseRuleDomain()?.domain
                if (ruleDomain != nil) {
                    ruleDomains += [String(ruleDomain!)]
                }
            }
            return ruleDomains;

        } catch {
            return []
        }
    }
    
    /**
     * Checks if provided rule is associated with the domain
     */
    public func userRuleIsAssociated(with domain: String, _ userRule: String) -> Bool {
        let ruleDomains = parseRuleDomains(ruleText: userRule)
        return ruleDomains.contains{ $0 == domain }
    }
}
