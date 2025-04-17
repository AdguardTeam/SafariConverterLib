import Foundation

/// Enum responsible for converting third-party rules to AdGuard syntax.
///
/// Note, that the rules converter purposefully ignores some rules that AdGuard
/// supports (and converts) on other platforms. The problem is that Safari
/// content blocking API is not enough to support those rules.
///
/// Here's the list of what's ignored (but may be required if Safari adds
/// support for that):
///
///  - Adblock Plus `$rewrite=abp-resource modifier`
///  - uBO HTML filtering, i.e. `##^scrpit:has-text`
///  - Options that are converted to `$redirect` rules: `mp4`, `empty`
///  - Options that are converted to `$csp` rules: `inline-font`, `inline-script`
///
/// Some options that on other platforms we handle by the rule converter are
/// supported by NetworkRule:
///
/// - `$all`
/// - `$1p`
/// - `$3p`
public enum RuleConverter {
    private static let UBO_SCRIPTLET_MASK_REG = "#@?#\\+js"
    // swiftlint:disable:next force_try
    private static let UBO_SCRIPTLET_MASK_REGEXP = try! NSRegularExpression(
        pattern: UBO_SCRIPTLET_MASK_REG,
        options: [.caseInsensitive]
    )
    // swiftlint:disable:next force_try
    private static let SENTENCES_REGEXP = try! NSRegularExpression(
        pattern: #"'.*?'|".*?"|\S+"#,
        options: [.caseInsensitive]
    )
    private static let DENYALLOW_MODIFIER_MASK = "denyallow="
    private static let DOMAIN_MODIFIER_MASK = "domain="
    private static let IMPORTANT_MODIFIER_MASK = "important"

    private static let MODIFIER_MASK = "$"
    private static let EXCEPTION_MASK = "@@"
    private static let EXCEPTION_SUFFIX = EXCEPTION_MASK + "||"

    private static let UBO_SCRIPTLET_MASK = "##+js"
    private static let UBO_SCRIPTLET_EXCEPTION_MASK = "#@#+js"
    private static let UBO_CSS_STYLE_MASK = ":style("

    // AdGuard CSS rule mask regex.
    private static let ADG_CSS_MASK_REG = "#@?\\$#.+?\\s*\\{.*\\}\\s*$"
    // swiftlint:disable:next force_try
    private static let ADG_CSS_MASK_REGEXP = try! NSRegularExpression(
        pattern: ADG_CSS_MASK_REG,
        options: [.caseInsensitive]
    )

    /// AdGuard script rules mask.
    private static let ADGUARD_SCRIPTLET_MASK = "${domains}#%#//scriptlet(${args})"

    /// AdGuard scriptlet exception mask.
    private static let ADGUARD_SCRIPTLET_EXCEPTION_MASK = "${domains}#@%#//scriptlet(${args})"

    /// Converts a rule to AdGuard-compatible syntax.
    ///
    /// Note, that some rules are converted to a list of rules.
    public static func convertRule(ruleText: String) -> [String?] {
        guard !ruleText.isEmpty else {
            return [ruleText]
        }

        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText)

        if let marker = markerInfo.marker, markerInfo.index != -1 {
            // If a cosmetic rule marker has been found, check for scriptlet rules
            // conversions.
            if isUboScriptletRule(ruleText: ruleText, marker: marker, index: markerInfo.index) {
                return [convertUboScriptletRule(rule: ruleText)]
            }

            if isAbpSnippetRule(ruleText: ruleText, marker: marker, index: markerInfo.index) {
                return convertAbpSnippetRule(
                    ruleText: ruleText,
                    marker: marker,
                    index: markerInfo.index
                )
            }

            if marker == .elementHiding || marker == .elementHidingException {
                if let uboCssStyleRule = convertUboCssStyleRule(ruleText: ruleText) {
                    return [uboCssStyleRule]
                }
            }
        } else {
            // Convert denyallow rule.
            if let denyallowRules = convertDenyallowRule(ruleText: ruleText) {
                return denyallowRules
            }
        }

        return [ruleText]
    }

    /// Returns true if the rule is a uBO scriptlet rule.
    /// In this case the rule needs to be converted.
    private static func isUboScriptletRule(
        ruleText: String,
        marker: CosmeticRuleMarker,
        index: Int
    ) -> Bool {
        if marker != .elementHiding && marker != .elementHidingException {
            // uBO uses standard element hiding marker for scriptlet rules.
            return false
        }

        let contentIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index)
        let ruleContent = ruleText[contentIndex...]

        return
            (ruleContent.utf8.starts(with: Self.UBO_SCRIPTLET_MASK.utf8)
            || ruleContent.utf8.starts(with: Self.UBO_SCRIPTLET_EXCEPTION_MASK.utf8))
            && String(ruleContent).firstMatch(for: Self.UBO_SCRIPTLET_MASK_REGEXP) != nil
    }

    /// Converts a uBO scriptlet rule to AdGuard syntax.
    private static func convertUboScriptletRule(rule: String) -> String? {
        guard let range = rule.firstMatch(for: Self.UBO_SCRIPTLET_MASK_REGEXP) else {
            return nil
        }

        let mask = rule[range]
        let domains = String(rule[..<range.lowerBound])

        let template: String
        if mask.utf8.contains(Chars.AT_CHAR) {
            template = Self.ADGUARD_SCRIPTLET_EXCEPTION_MASK
        } else {
            template = Self.ADGUARD_SCRIPTLET_MASK
        }

        guard let arguments: String = extractArgumentsString(str: rule) else {
            return nil
        }

        var parsedArgs = arguments.components(separatedBy: ", ")
        if parsedArgs.count == 1 {
            // Most probably this is not correct separator, in this case we use ','
            parsedArgs = arguments.components(separatedBy: ",")
        }

        var args: [String] = []
        for i in (0..<parsedArgs.count) {
            var arg = parsedArgs[i]
            if i == 0 {
                arg = "ubo-" + arg
            }

            args.append(wrapInDoubleQuotes(str: arg))
        }

        let argsString = args.joined(separator: ", ")

        return replacePlaceholders(str: template, domains: domains, args: argsString)
    }

    /// Returns true if the rule most probably is a ABP snippet rule.
    private static func isAbpSnippetRule(
        ruleText: String,
        marker: CosmeticRuleMarker,
        index: Int
    ) -> Bool {
        if marker != .css && marker != .cssException {
            // Adblock Plus uses the same marker as the one AdGuard uses for CSS rules (#$#, #@$#).
            return false
        }

        let contentIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index)
        let ruleContent = String(ruleText[contentIndex...])

        return ruleContent.firstMatch(for: Self.ADG_CSS_MASK_REGEXP) == nil
    }

    /// Convert string of ABP scriptlet rule to AdGuard scriptlet rule.
    private static func convertAbpSnippetRule(
        ruleText: String,
        marker: CosmeticRuleMarker,
        index: Int
    ) -> [String] {
        let template =
            marker == .css ? Self.ADGUARD_SCRIPTLET_MASK : Self.ADGUARD_SCRIPTLET_EXCEPTION_MASK

        let maskIndex = ruleText.utf8.index(ruleText.startIndex, offsetBy: index)
        let domains = String(ruleText[..<maskIndex])

        let argsIndex = ruleText.utf8.index(
            ruleText.startIndex,
            offsetBy: index + marker.rawValue.utf8.count
        )
        let args = ruleText[argsIndex...]

        let splitted = args.components(separatedBy: "; ")

        var result: [String] = []

        for snippet in splitted {
            var sentences: [String] = []
            let sen = snippet.matches(regex: Self.SENTENCES_REGEXP)
            for part in sen where !part.isEmpty {
                sentences.append(part)
            }

            var wrapped: [String] = []
            for (index, sentence) in sentences.enumerated() {
                let wrappedSentence = index == 0 ? "abp-" + sentence : sentence
                wrapped.append(wrapInDoubleQuotes(str: wrappedSentence))
            }

            let converted = replacePlaceholders(
                str: template,
                domains: domains,
                args: wrapped.joined(separator: ", ")
            )
            result.append(converted)
        }

        return result
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
    private static func convertUboCssStyleRule(ruleText: String) -> String? {
        guard ruleText.utf8.includes(Self.UBO_CSS_STYLE_MASK.utf8) else {
            return nil
        }

        let uboToInjectCssMarkersDictionary: [String: String] = [
            "##": "#$#",
            "#@#": "#@$#",
            "#?#": "#$?#",
            "#@?#": "#@$?#",
        ]

        for (marker, replacement) in uboToInjectCssMarkersDictionary
        where ruleText.utf8.includes(marker.utf8) {
            let replacedMarkerRule = ruleText.replacingOccurrences(of: marker, with: replacement)
            let result = replacedMarkerRule.replacingOccurrences(
                of: Self.UBO_CSS_STYLE_MASK,
                with: " { "
            )
            return result.dropLast() + " }"
        }

        return nil
    }

    /// Validates and converts rule with $denyallow modifier into blocking rule and additional exception rules.
    ///
    /// Learn more about it here:
    /// https://github.com/AdguardTeam/CoreLibs/issues/1304
    private static func convertDenyallowRule(ruleText: String) -> [String]? {
        guard ruleText.utf8.includes(Self.DENYALLOW_MODIFIER_MASK.utf8) else {
            return nil
        }

        guard let ruleParts = try? NetworkRuleParser.parseRuleText(ruleText: ruleText) else {
            return nil
        }

        guard let options = ruleParts.options else {
            return nil
        }

        if ruleParts.pattern.utf8.first == Chars.PIPE
            || !options.utf8.includes(Self.DOMAIN_MODIFIER_MASK.utf8)
        {
            // We can only support simple case like this: $denyallow=x.com,domain=y.com,
            // i.e. the rule that targets path (not domain) and it must have both
            // denyallow and domain modifier.

            return nil
        }

        var blockingElement: String = ruleParts.pattern
        if blockingElement.starts(with: "/") {
            blockingElement = String(blockingElement.dropFirst())
        }

        let isGenericRule = blockingElement.isEmpty || blockingElement == "*"

        let ruleOptions = options.components(separatedBy: ",")
        guard
            let denyallowOption = ruleOptions.first(where: {
                $0.contains(Self.DENYALLOW_MODIFIER_MASK)
            })
        else {
            return nil
        }

        // Get denyallow domains list.
        let denyallowDomainsString = denyallowOption.replace(
            target: Self.DENYALLOW_MODIFIER_MASK,
            withString: ""
        )
        let denyallowDomains = denyallowDomainsString.components(separatedBy: "|")

        for domain in denyallowDomains {
            if domain.hasPrefix("~") || domain.contains("*") {
                // Modifier $denyallow cannot be negated or have a wildcard TLD
                return nil
            }
        }

        // Remove denyallow from options.
        let optionsWithoutDenyallow: [String] = ruleOptions.filter { part in
            part != denyallowOption
        }
        let optionsWithoutDenyallowString = optionsWithoutDenyallow.joined(separator: ",")

        var result: [String] = []

        let blockingRulePrefix: String = ruleParts.whitelist ? "@@" : ""
        let exceptionRulePrefix: String = ruleParts.whitelist ? "||" : Self.EXCEPTION_SUFFIX
        let exceptionRuleSuffix: String =
            ruleParts.whitelist ? "," + Self.IMPORTANT_MODIFIER_MASK : ""

        // Blocking rule.
        let blockingRule =
            blockingRulePrefix + ruleParts.pattern + Self.MODIFIER_MASK
            + optionsWithoutDenyallowString
        result.append(blockingRule)

        // Exception rules.
        for domain in denyallowDomains {
            if !isGenericRule {
                // Create exception rule for the domain with the path
                let exceptionPath = domain + "/" + blockingElement
                let exceptionRule =
                    exceptionRulePrefix + exceptionPath + Self.MODIFIER_MASK
                    + optionsWithoutDenyallowString + exceptionRuleSuffix
                result.append(exceptionRule)

                // Create exception rule for the domain with wildcard path
                let exceptionPathWide = domain + "/*/" + blockingElement
                let exceptionRuleWide =
                    exceptionRulePrefix + exceptionPathWide + Self.MODIFIER_MASK
                    + optionsWithoutDenyallowString + exceptionRuleSuffix
                result.append(exceptionRuleWide)
            } else {
                // Create exception rule for the domain only
                let exceptionRule =
                    exceptionRulePrefix + domain + Self.MODIFIER_MASK
                    + optionsWithoutDenyallowString + exceptionRuleSuffix
                result.append(exceptionRule)
            }
        }

        return result
    }

    /// Extracts arguments string from a scriptlet string.
    ///
    /// I.e. it will extract "1,2,3" from "func(1,2,3)".
    private static func extractArgumentsString(str: String) -> String? {
        guard var firstIndex = str.utf8.firstIndex(of: Chars.BRACKET_OPEN),
            let lastIndex = str.utf8.lastIndex(of: Chars.BRACKET_CLOSE)
        else {
            return nil
        }

        str.utf8.formIndex(after: &firstIndex)
        guard firstIndex < lastIndex else {
            return nil
        }

        return String(str[firstIndex..<lastIndex])
    }

    /// Wraps the specified string in doublequotes escaping quotes inside if required.
    private static func wrapInDoubleQuotes(str: String) -> String {
        var modified = str
        // https://github.com/AdguardTeam/SafariConverterLib/issues/34
        if str.utf8.count <= 1 {
            modified = modified.replacingOccurrences(of: "\"", with: "\\\"")
        } else if str.utf8.first == Chars.QUOTE_SINGLE && str.utf8.last == Chars.QUOTE_SINGLE {
            modified =
                modified
                .trimmingCharacters(in: Chars.TRIM_SINGLE_QUOTE)
                .replacingOccurrences(of: "\"", with: "\\\"")
        } else if str.utf8.first == Chars.QUOTE_DOUBLE && str.utf8.last == Chars.QUOTE_DOUBLE {
            modified =
                modified
                .trimmingCharacters(in: Chars.TRIM_DOUBLE_QUOTE)
                .replacingOccurrences(of: "'", with: "\'")
        }

        return "\"\(modified)\""
    }

    /// Replaces placeholders for domains and arguments in the specified template string.
    private static func replacePlaceholders(str: String, domains: String, args: String) -> String {
        var result = str.replace(target: "${domains}", withString: domains)
        result = result.replace(target: "${args}", withString: args)

        return result
    }
}
