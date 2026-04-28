import Foundation

/// RuleFactory is responsible for parsing AdGuard rules.
public enum RuleFactory {
    /// Creates AdGuard rules from the specified lines.
    ///
    /// `$badfilter` rules are interpreted when creating rules, the rules that are negated
    /// will be filtered out.
    ///
    /// It also applies cosmetic exceptions, i.e. rules like `#@#.banner` by modifying the
    /// corresponding rules permitted/restricted domains.
    public static func createRules(
        lines: [String],
        for version: SafariVersion,
        errorsCounter: ErrorsCounter? = nil
    ) -> [Rule] {
        var result: [Rule] = []

        for line in lines {
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

            let convertedLines = RuleConverter.convertRule(ruleText: ruleLine)
            for convertedLine in convertedLines where convertedLine != nil {
                do {
                    if let convertedText = convertedLine,
                        let rule = try RuleFactory.createRule(ruleText: convertedText, for: version)
                    {
                        result.append(rule)
                    }
                } catch {
                    errorsCounter?.add()
                }
            }
        }

        return result
    }

    /// This function filters out rules that are disabled `$badfilter` and modifies domain restrictions
    /// using cosmetic exceptions. The first step is to find all `$badfilter` and cosmetic exceptions,
    /// and the second step is to filter out disabled rules.
    ///
    /// Depending on the Safari version the behavior may be different. For older Safari version we do not
    /// support mixing permitted and restricted domains so `#@#` (cosmetic exceptions) support is limited.
    /// For newer versions we support it for almost all cosmetic rules save for those with `$path` modifier.
    ///
    /// ## Examples
    ///
    /// ### $badfilter
    ///
    /// Rule `||example.org^` will be filtered out by `||example.org^$third-party,badfilter`.
    ///
    /// ### Cosmetic exceptions
    ///
    /// Rule `##.banner` will be changed by `example.org#@#.banner` and the final form will
    /// be `~example.org##.banner`.
    ///
    /// - Parameters:
    ///   - rules: source AdGuard rules that needs to be filtered.
    ///   - version: Safari version for which we perform
    public static func filterOutExceptions(from rules: [Rule], version: SafariVersion) -> [Rule] {
        var networkRules: [NetworkRule] = []
        var cosmeticRules: [CosmeticRule] = []

        var badfilterRules: [String: [NetworkRule]] = [:]
        var cosmeticExceptions: [String: [CosmeticRule]] = [:]

        var result: [Rule] = []

        for rule in rules {
            if let networkRule = rule as? NetworkRule {
                if networkRule.isBadfilter {
                    badfilterRules[networkRule.urlRuleText, default: []].append(networkRule)
                } else {
                    networkRules.append(networkRule)
                }
            } else if let cosmeticRule = rule as? CosmeticRule {
                if cosmeticRule.isWhiteList {
                    cosmeticExceptions[cosmeticRule.content, default: []].append(cosmeticRule)
                } else {
                    cosmeticRules.append(cosmeticRule)
                }
            }
        }

        result += RuleFactory.applyBadFilterExceptions(
            rules: networkRules,
            badfilterRules: badfilterRules
        )
        result += RuleFactory.applyCosmeticExceptions(
            rules: cosmeticRules,
            cosmeticExceptions: cosmeticExceptions,
            version: version
        )

        return result
    }

    /// Creates an AdGuard rule from the rule text.
    public static func createRule(ruleText: String, for version: SafariVersion) throws -> Rule? {
        do {
            if ruleText.isEmpty || RuleFactory.isComment(ruleText: ruleText) {
                return nil
            }

            if ruleText.utf8.count < 3 {
                throw SyntaxError.invalidRule(message: "The rule is too short")
            }

            if RuleFactory.isCosmetic(ruleText: ruleText) {
                return try CosmeticRule(ruleText: ruleText, for: version)
            }

            return try NetworkRule(ruleText: ruleText, for: version)
        } catch {
            Logger.log(
                "(RuleFactory) - Unexpected error: \(error) while creating rule from: \(String(describing: ruleText))"
            )
            throw error
        }
    }

    /// Filters out rules that are negated by `$badfilter` rules.
    private static func applyBadFilterExceptions(
        rules: [NetworkRule],
        badfilterRules: [String: [NetworkRule]]
    ) -> [Rule] {
        var result: [Rule] = []
        for rule in rules {
            let negatingRule = badfilterRules[rule.urlRuleText]?.first {
                $0.negatesBadfilter(specifiedRule: rule)
            }
            if negatingRule == nil {
                result.append(rule)
            }
        }

        return result
    }

    /// Applies cosmetic exception rules by modifying the cosmetic rule's permitted and restricted domains.
    private static func applyCosmeticExceptions(
        rules: [CosmeticRule],
        cosmeticExceptions: [String: [CosmeticRule]],
        version: SafariVersion
    ) -> [Rule] {
        var result: [Rule] = []

        for rule in rules {
            if let exceptionRules = cosmeticExceptions[rule.content] {
                if let newRule = applyCosmeticExceptions(
                    rule: rule,
                    exceptionRules: exceptionRules,
                    version: version
                ) {
                    result.append(newRule)
                }
            } else {
                result.append(rule)
            }
        }

        return result
    }

    /// Applies cosmetic exception rules to a cosmetic rule by modifying its permitted/restricted domains.
    ///
    /// Depending on Safari version it either supports mixing permitted/restricted domains or not.
    ///
    /// ## Examples
    ///
    /// For example, if we have two rules like this:
    ///
    /// ```
    /// example.org#@#.banner
    /// ##.banner
    /// ```
    ///
    /// They will be transformed to a single rule equivalent to `~example.org##.banner`.
    ///
    /// ## Edge cases
    ///
    /// There're some edge cases where the rule is completely redundant.
    ///
    /// ## Edge case #1: negate all domains
    ///
    /// This rule disables `##.banner` on all domains
    ///
    /// ```
    /// #@#.banner
    /// ```
    ///
    /// ## Edge case #2: all domains in the rule are negated
    ///
    /// In this case the final rule has no permitted domains, i.e. it's redundant and can be skipped.
    ///
    /// ```
    /// example.org,example.com##.banner
    /// example.org#@#.banner
    /// example.com#@#.banner
    /// ```
    ///
    /// - Parameters:
    ///    - rule: Rule to modify
    ///    - exceptionRules: Cosmetic exception rules to apply
    ///    - version: Safari version
    /// - Returns: modified rule or `nil` if after applying exception the rule is redundant.
    private static func applyCosmeticExceptions(
        rule: CosmeticRule,
        exceptionRules: [CosmeticRule],
        version: SafariVersion
    ) -> CosmeticRule? {
        for exceptionRule in exceptionRules {
            if exceptionRule.permittedDomains.isEmpty {
                // Completely disables the rule on all domains
                // I.e. `#@#.banner`
                return nil
            }

            for domain in exceptionRule.permittedDomains {
                if !rule.permittedDomains.isEmpty {
                    rule.permittedDomains.removeAll {
                        DomainUtils.isDomainOrSubdomain(candidate: $0, domain: domain)
                    }

                    // If the rule has no permitted domains now, skip it.
                    if rule.permittedDomains.isEmpty {
                        return nil
                    }

                    // For new Safari versions we can mix permitted and restricted
                    // domains in cosmetic rules and they can be then converted
                    // to one or multiple entries in the JSON.
                    if version.isSafari16_4orGreater() && !rule.restrictedDomains.contains(domain) {
                        /// Check if there's a domain among permitted that can actually
                        /// be restricted.
                        ///
                        /// For example, here it makes sense to add restricted domain:
                        /// ```
                        /// permitted = ["example.org"]
                        /// restricted = ["sub.example.org"]
                        /// ```
                        ///
                        /// But here adding `sub.example.com` to restricted makes no sense
                        /// since the rule will not be applied on any `example.com` subdomain
                        /// anyways:
                        ///
                        /// ```
                        /// permitted = ["example.org"]
                        /// restricted = ["sub.example.com"]
                        /// ```
                        let canRestrict = rule.permittedDomains.contains {
                            DomainUtils.isDomainOrSubdomain(candidate: domain, domain: $0)
                        }

                        if canRestrict {
                            rule.restrictedDomains.append(domain)
                        }
                    }
                } else if !rule.restrictedDomains.contains(domain) {
                    rule.restrictedDomains.append(domain)
                }
            }
        }

        return rule
    }

    /// Checks if the rule is a cosmetic (CSS/JS) or not.
    private static func isCosmetic(ruleText: String) -> Bool {
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText)
        return markerInfo.index != -1
    }

    /// Checks if the rule is a comment.
    ///
    /// There are two types of comments:
    /// A line starts with '!'
    /// A line starts with '# '
    private static func isComment(ruleText: String) -> Bool {
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
