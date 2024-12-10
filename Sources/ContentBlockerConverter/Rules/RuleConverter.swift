import Foundation

/// Class responsible for converting third-party rules to AdGuard syntax.
///
/// Note, that the rules converter purposefully ignores some rules that AdGuard supports (and converts) on other platforms.
/// The problem is that Safari content blocking API is not enough to support those rules.
///
/// Here's the list of what's ignored (but may be required if Safari adds support for that):
///  - Adblock Plus $rewrite=abp-resource modifier
///  - uBO HTML filtering, i.e. ##^scrpit:has-text
///  - Options that are converted to $redirect rules: mp4, empty
///  - Options that are converted to $csp rules: inline-font, inline-script
///
/// Some options that on other platforms we handle by the rule converter are supported by NetworkRule:
/// - $all
/// - $1p
/// - $3p
///
/// TODO(ameshkov): Add tests with $1p, $3p, $all conversion
class RuleConverter {
    private static let UBO_SCRIPTLET_MASK_REG = "#@?#\\+js"
    private static let UBO_SCRIPTLET_MASK_REGEXP = try! NSRegularExpression(pattern: UBO_SCRIPTLET_MASK_REG, options: [.caseInsensitive])
    private static let SENTENCES_REGEXP = try! NSRegularExpression(pattern: #"'.*?'|".*?"|\S+"#, options: [.caseInsensitive])
    private static let DENYALLOW_MODIFIER_MASK = "denyallow="
    private static let DOMAIN_MODIFIER_MASK = "domain="
    private static let IMPORTANT_MODIFIER_MASK = "important"

    private static let MODIFIER_MASK = "$"
    private static let EXCEPTION_MASK = "@@"
    private static let EXCEPTION_SUFFIX = EXCEPTION_MASK + "||"

    private let UBO_SCRIPTLET_MASK = "##+js"
    private let UBO_SCRIPTLET_EXCEPTION_MASK = "#@#+js"
    private let UBO_CSS_STYLE_MASK = ":style("

    // AdGuard CSS rule mask regex.
    private static let ADG_CSS_MASK_REG = "#@?\\$#.+?\\s*\\{.*\\}\\s*$"
    private static let ADG_CSS_MASK_REGEXP = try! NSRegularExpression(pattern: ADG_CSS_MASK_REG, options: [.caseInsensitive])

    private static let delimeterChar = ",".utf16.first!
    private static let escapeChar = "\\".utf16.first!

    /// AdGuard script rules mask.
    private let ADGUARD_SCRIPTLET_MASK = "${domains}#%#//scriptlet(${args})"

    /// AdGuard scriptlet exception mask.
    private let ADGUARD_SCRIPTLET_EXCEPTION_MASK = "${domains}#@%#//scriptlet(${args})"

    /// Converts a rule to AdGuard-compatible syntax.
    ///
    /// Note, that some rules are converted to a list of rules.
    func convertRule(ruleText: String) -> [String?] {
        if (ruleText.isEmpty || isComment(ruleText: ruleText)) {
            return [ruleText]
        }

        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText)

        if markerInfo.index != -1 {
            // If a cosmetic rule marker has been found, check for scriptlet rules
            // conversions.
            if (isUboScriptletRule(ruleText: ruleText, marker: markerInfo.marker!, index: markerInfo.index)) {
                return [convertUboScriptletRule(rule: ruleText)]
            }
           
            if (isAbpSnippetRule(ruleText: ruleText, marker: markerInfo.marker!, index: markerInfo.index)) {
                return convertAbpSnippetRule(ruleText: ruleText, marker: markerInfo.marker!, index: markerInfo.index)
            }

            if markerInfo.marker == CosmeticRuleMarker.ElementHiding ||
                       markerInfo.marker == CosmeticRuleMarker.ElementHidingException {
                let uboCssStyleRule = convertUboCssStyleRule(ruleText: ruleText)
                if (uboCssStyleRule != nil) {
                    return [uboCssStyleRule!]
                }
            }
        } else {
            // Convert denyallow rule.
            let denyallowRules = convertDenyallowRule(ruleText: ruleText)
            if (denyallowRules != nil) {
                return denyallowRules!
            }
        }

        return [ruleText]
    }

    /// isComment returns true if the rule is a comment.
    private func isComment(ruleText: String) -> Bool {
        // TODO(ameshkov): !!! There's one more case, starts with HASH + SPACE
        return ruleText.utf8.first == Chars.EXCLAMATION;
    }
    
    /// Returns true if the rule is a uBO scriptlet rule.
    /// In this case the rule needs to be converted.
    private func isUboScriptletRule(ruleText: String, marker: CosmeticRuleMarker, index: Int) -> Bool {
        if marker != CosmeticRuleMarker.ElementHiding && marker != CosmeticRuleMarker.ElementHidingException {
            // uBO uses standard element hiding marker for scriptlet rules.
            return false
        }
        
        let contentIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index)
        let ruleContent = ruleText[contentIndex...]
        
        return (
            ruleContent.utf8.starts(with: UBO_SCRIPTLET_MASK.utf8)
            || ruleContent.utf8.starts(with: UBO_SCRIPTLET_EXCEPTION_MASK.utf8)
        ) && String(ruleContent).firstMatch(for: RuleConverter.UBO_SCRIPTLET_MASK_REGEXP) != nil
    }

    /// Converts a uBO scriptlet rule to AdGuard syntax.
    private func convertUboScriptletRule(rule: String) -> String? {
        let range = rule.firstMatch(for: RuleConverter.UBO_SCRIPTLET_MASK_REGEXP)
        if range == nil {
            return nil
        }
        
        let mask = rule[range!];
        let domains = String(rule[..<range!.lowerBound]);

        let template: String;
        if (mask.utf8.contains(Chars.AT_CHAR)) {
            template = ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        } else {
            template = ADGUARD_SCRIPTLET_MASK;
        }

        guard let arguments: String = extractArgumentsString(str: rule) else {
            return nil
        }
        
        var parsedArgs = arguments.components(separatedBy: ", ")
        if (parsedArgs.count == 1) {
            // Most probably this is not correct separator, in this case we use ','
            parsedArgs = arguments.components(separatedBy: ",")
        }

        var args = [String]()
        for i in (0..<parsedArgs.count) {
            var arg = parsedArgs[i]
            if i == 0 {
                arg = "ubo-" + arg
            }

            args.append(wrapInDoubleQuotes(str: arg));
        }

        let argsString = args.joined(separator: ", ")

        return replacePlaceholders(str: template, domains: domains, args: argsString);
    }

    /// Returns true if the rule most probably is a ABP snippet rule.
    private func isAbpSnippetRule(ruleText: String, marker: CosmeticRuleMarker, index: Int) -> Bool {
        if marker != CosmeticRuleMarker.Css && marker != CosmeticRuleMarker.CssException {
            // Adblock Plus uses the same marker as the one AdGuard uses for CSS rules (#$#, #@$#).
            return false
        }
        
        let contentIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index)
        let ruleContent = String(ruleText[contentIndex...])

        return ruleContent.firstMatch(for: RuleConverter.ADG_CSS_MASK_REGEXP) == nil
    }

    /// Convert string of ABP scriptlet rule to AdGuard scriptlet rule.
    private func convertAbpSnippetRule(ruleText: String, marker: CosmeticRuleMarker, index: Int) -> [String] {
        let template = marker == CosmeticRuleMarker.Css ? ADGUARD_SCRIPTLET_MASK : ADGUARD_SCRIPTLET_EXCEPTION_MASK
        
        let maskIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index)
        let domains = String(ruleText[..<maskIndex])
        
        let argsIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index + marker.rawValue.utf8.count)
        let args = ruleText[argsIndex...]

        let splitted = args.components(separatedBy: "; ")

        var result = [String]()

        for s in splitted {
            var sentences = [String]()
            let sen = s.matches(regex: RuleConverter.SENTENCES_REGEXP)
            for part in sen {
                if part != "" {
                    sentences.append(part)
                }
            }

            var wrapped = [String]()
            for (index, sentence) in sentences.enumerated() {
                let w = index == 0 ? "abp-" + sentence : sentence
                wrapped.append(wrapInDoubleQuotes(str: w))
            }

            let converted = replacePlaceholders(str: template, domains: domains, args: wrapped.joined(separator: ", "))
            result.append(converted)
        }

        return result;
    }

    /// Convers uBO-style CSS injection rule.
    ///
    /// Example:
    /// example.com##h1:style(background-color: blue !important)
    /// ->
    /// example.com#$#h1 { background-color: blue !important }
    ///
    /// Exception rule example:
    /// example.com#@#h1:style(background-color: blue !important)
    /// ->
    /// example.com#@$#h1 { background-color: blue !important }
    private func convertUboCssStyleRule(ruleText: String) -> String? {
        if !ruleText.utf8.includes(UBO_CSS_STYLE_MASK.utf8) {
            return nil
        }
        
        let uboToInjectCssMarkersDictionary: [String: String] = [
            "##": "#$#",
            "#@#": "#@$#",
            "#?#": "#$?#",
            "#@?#": "#@$?#",
        ]

        var replacedMarkerRule: String? = nil;
        for marker in uboToInjectCssMarkersDictionary.keys {
            if (ruleText.utf8.includes(marker.utf8)) {
                replacedMarkerRule = ruleText.replacingOccurrences(of: marker, with: uboToInjectCssMarkersDictionary[marker]!)
                let result = replacedMarkerRule!.replacingOccurrences(of: UBO_CSS_STYLE_MASK, with: " { ")

                return result.dropLast() + " }"
            }
        }

        return nil;
    }
    
    /// Validates and converts rule with $denyallow modifier into blocking rule and additional exception rules.
    ///
    /// Learn more about it here:
    /// https://github.com/AdguardTeam/CoreLibs/issues/1304
    private func convertDenyallowRule(ruleText: String) -> [String]? {
        if !ruleText.utf8.includes(RuleConverter.DENYALLOW_MODIFIER_MASK.utf8) {
            return nil
        }

        let ruleParts = try! NetworkRuleParser.parseRuleText(ruleText: ruleText)
        
        if ruleParts.pattern!.utf8.first == Chars.PIPE ||
            ruleParts.options == nil ||
            !ruleParts.options!.utf8.includes(RuleConverter.DOMAIN_MODIFIER_MASK.utf8) {
            
            // We can only support simple case like this: $denyallow=x.com,domain=y.com,
            // i.e. the rule that targets path (not domain) and it must have both
            // denyallow and domain modifier.

            // TODO(ameshkov): !!! Why don't we support ||example.org^$denyallow=x.com,domain=y.com
            
            return nil
        }

        var blockingElement: String = ruleParts.pattern!;
        if (blockingElement.starts(with: "/")) {
            blockingElement = String(blockingElement.dropFirst());
        }

        let isGenericRule = blockingElement == "" || blockingElement == "*"

        let ruleOptions = ruleParts.options!.components(separatedBy: ",")
        let denyallowOption = ruleOptions.first(where: { $0.contains(RuleConverter.DENYALLOW_MODIFIER_MASK) })!

        // Get denyallow domains list.
        let denyallowDomains = denyallowOption.replace(target: RuleConverter.DENYALLOW_MODIFIER_MASK, withString: "").components(separatedBy: "|")

        for domain in denyallowDomains {
            if (domain.hasPrefix("~") || domain.contains("*")) {
                // Modifier $denyallow cannot be negated or have a wildcard TLD
                return nil
            }
        }

        // Remove denyallow from options.
        let optionsWithoutDenyallow = ruleOptions.filter { part in
                    return part != denyallowOption
                }
                .joined(separator: ",")

        var result = [String]()

        let blockingRulePrefix: String = ruleParts.whitelist ? "@@" : ""
        let exceptionRulePrefix: String = ruleParts.whitelist ? "||" : RuleConverter.EXCEPTION_SUFFIX
        let exceptionRuleSuffix: String = ruleParts.whitelist ? "," + RuleConverter.IMPORTANT_MODIFIER_MASK : ""

        // Blocking rule.
        let blockingRule = blockingRulePrefix + ruleParts.pattern! + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow
        result.append(blockingRule)

        // Exception rules.
        for domain in denyallowDomains {
            if (!isGenericRule) {
                let exceptionRule = exceptionRulePrefix + domain + "/" + blockingElement + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow + exceptionRuleSuffix
                result.append(exceptionRule)

                let exceptionRuleWide = exceptionRulePrefix + domain + "/*/" + blockingElement + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow + exceptionRuleSuffix
                result.append(exceptionRuleWide)

            } else {
                let exceptionRule = exceptionRulePrefix + domain + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow + exceptionRuleSuffix
                result.append(exceptionRule)
            }
        }

        return result
    }

    /// Extracts arguments string from a scriptlet string.
    ///
    /// I.e. it will extract "1,2,3" from "func(1,2,3)".
    private func extractArgumentsString(str: String) -> String? {
        var firstIndex = str.utf8.firstIndex(of: Chars.BRACKET_OPEN)
        let lastIndex = str.utf8.lastIndex(of: Chars.BRACKET_CLOSE)
        
        if firstIndex == nil || lastIndex == nil {
            return nil
        }
        
        str.utf8.formIndex(after: &firstIndex!)
        if firstIndex! >= lastIndex! {
            return nil
        }
        
        return String(str[firstIndex!..<lastIndex!])
    }

    /// Wraps the specified string in doublequotes escaping quotes inside if required.
    private func wrapInDoubleQuotes(str: String) -> String {
        var modified = str
        // https://github.com/AdguardTeam/SafariConverterLib/issues/34
        if str.utf8.count <= 1 {
            modified = modified.replacingOccurrences(of: "\"", with: "\\\"")
        } else if str.utf8.first == Chars.QUOTE_SINGLE && str.utf8.last == Chars.QUOTE_SINGLE {
            modified = modified
                .trimmingCharacters(in: Chars.TRIM_SINGLE_QUOTE)
                .replacingOccurrences(of: "\"", with: "\\\"")
        } else if str.utf8.first == Chars.QUOTE_DOUBLE && str.utf8.last == Chars.QUOTE_DOUBLE {
            modified = modified
                .trimmingCharacters(in: Chars.TRIM_DOUBLE_QUOTE)
                .replacingOccurrences(of: "'", with: "\'")
        }
        
        return "\"\(modified)\""
    }

    /// Replaces placeholders for domains and arguments in the specified template string.
    private func replacePlaceholders(str: String, domains: String, args: String) -> String {
        var result = str.replace(target: "${domains}", withString: domains)
        result = result.replace(target: "${args}", withString: args)

        return result
    }
}
