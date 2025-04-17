import Foundation

/// Provides methods to manage allowlist and inverted allowlist rules without conversion.
public protocol WebExtensionHelpersProtocol {
    // Public method to check if provided rule is associated with the domain
    func userRuleIsAssociated(with domain: String, _ userRule: String) -> Bool

    // Public method to convert domain to allowlist rule
    func convertDomainToAllowlistRule(_ domain: String) -> String

    // Public method to convert allowlist rule to domain
    func convertAllowlistRuleToDomain(_ ruleText: String) -> String

    // Public method to convert domain to inverted allowlist rule
    func convertDomainToInvertedAllowlistRule(_ domain: String) -> String

    // Public method to convert inverted allowlist rule to domain
    func convertInvertedAllowlistRuleToDomain(_ rule: String) -> String
}

/// Provides helpers methods for web extension.
public class WebExtensionHelpers: WebExtensionHelpersProtocol {
    private static let allowlistPrefix = "@@||"
    private static let allowlistSuffix = "^$document"
    private static let invertedAllowlistPrefix = "@@||*$document,domain=~"

    public init() {}

    /// Parses domains from the provided rule.
    func parseRuleDomains(ruleText: String) -> [String] {
        do {
            guard
                let rule = try RuleFactory.createRule(
                    ruleText: ruleText,
                    for: SafariVersion.autodetect()
                )
            else {
                return []
            }

            var ruleDomains = rule.permittedDomains + rule.restrictedDomains

            if let networkRule = rule as? NetworkRule {
                let ruleDomain = NetworkRuleParser.extractDomain(pattern: networkRule.urlRuleText)
                if !ruleDomain.domain.isEmpty {
                    ruleDomains += [ruleDomain.domain]
                }
            }
            return ruleDomains
        } catch {
            return []
        }
    }

    /// Checks if the provided rule is associated with the specified domain.
    public func userRuleIsAssociated(with domain: String, _ userRule: String) -> Bool {
        let ruleDomains = parseRuleDomains(ruleText: userRule)

        return ruleDomains.contains { $0 == domain }
    }

    /// Converts domain to allowlist rule `@@||domain^$document`.
    /// If passed domain already contains `@@||` or `^$document` they won't be repeated.
    public func convertDomainToAllowlistRule(_ domain: String) -> String {
        var rule = domain

        if !rule.hasPrefix(Self.allowlistPrefix) {
            rule = Self.allowlistPrefix + rule
        }

        if !rule.hasSuffix(Self.allowlistSuffix) {
            rule += Self.allowlistSuffix
        }

        return rule
    }

    /// Converts rule with `@@||domain^$document` format to domain.
    /// If passed rule doesn't contain `@@||` or `^$document` the function will return rule without modifying it.
    public func convertAllowlistRuleToDomain(_ ruleText: String) -> String {
        var domain = ruleText

        if domain.hasPrefix(Self.allowlistPrefix) {
            domain.removeFirst(Self.allowlistPrefix.count)
        }

        if domain.hasSuffix(Self.allowlistSuffix) {
            domain.removeLast(Self.allowlistSuffix.count)
        }

        return domain
    }

    /// Converts domain to inverted allowlist rule `@@||*$document,domain=~<domain>`.
    /// If passed inverted allowlist rule instead of domain it returns inverted allowlist rule.
    public func convertDomainToInvertedAllowlistRule(_ domain: String) -> String {
        var rule = domain

        if !rule.hasPrefix(Self.invertedAllowlistPrefix) {
            rule = Self.invertedAllowlistPrefix + domain
        }

        return rule
    }

    /// Converts inverted allowlist rule `@@||*$document,domain=~<domain>` to domain.
    /// If passed domain instead of inverted allowlist rule it returns domain.
    public func convertInvertedAllowlistRuleToDomain(_ rule: String) -> String {
        var domain = rule

        if domain.hasPrefix(Self.invertedAllowlistPrefix) {
            domain.removeFirst(Self.invertedAllowlistPrefix.count)
        }

        return domain
    }
}
