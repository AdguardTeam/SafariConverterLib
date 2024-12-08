import Foundation

/**
 * Rule converter class.
 * Converts third-party and some unsupported constructions to AG rules
 */
class RuleConverter {
    private static let UBO_SCRIPTLET_MASK_REG = "##script\\:inject|#@?#\\s*\\+js";
    private static let UBO_SCRIPTLET_MASK_REGEXP = try! NSRegularExpression(pattern: UBO_SCRIPTLET_MASK_REG, options: [.caseInsensitive]);
    private static let SENTENCES_REGEXP = try! NSRegularExpression(pattern: #"'.*?'|".*?"|\S+"#, options: [.caseInsensitive]);
    private static let DENYALLOW_MODIFIER_MASK = "denyallow=";
    private static let DOMAIN_MODIFIER_MASK = "domain=";
    private static let IMPORTANT_MODIFIER_MASK = "important";

    private static let MODIFIER_MASK = "$";
    private static let EXCEPTION_MASK = "@@";
    private static let EXCEPTION_SUFFIX = EXCEPTION_MASK + "||";

    private let UBO_SCRIPTLET_MASK_1 = "##+js";
    private let UBO_SCRIPTLET_MASK_2 = "##script:inject";
    private let UBO_SCRIPTLET_EXCEPTION_MASK_1 = "#@#+js";
    private let UBO_SCRIPTLET_EXCEPTION_MASK_2 = "#@#script:inject";
    private let UBO_SCRIPT_TAG_MASK = "##^script";
    private let UBO_CSS_STYLE_MASK = ":style(";

    /**
     * AdBlock Plus snippet rule mask
     */
    private let ABP_SCRIPTLET_MASK = "#$#";
    private let ABP_SCRIPTLET_EXCEPTION_MASK = "#@$#";

    /**
     * AdGuard CSS rule mask
     */
    private static let ADG_CSS_MASK_REG = "#@?\\$#.+?\\s*\\{.*\\}\\s*$";
    private static let ADG_CSS_MASK_REGEXP = try! NSRegularExpression(pattern: ADG_CSS_MASK_REG, options: [.caseInsensitive]);

    private static let delimeterChar = ",".utf16.first!;
    private static let escapeChar = "\\".utf16.first!;

    /**
     * AdGuard scriptlet mask
     */
    private let ADGUARD_SCRIPTLET_MASK = "${domains}#%#//scriptlet(${args})";

    /**
     * AdGuard scriptlet exception mask
     */
    private let ADGUARD_SCRIPTLET_EXCEPTION_MASK = "${domains}#@%#//scriptlet(${args})";

    /**
     * Converts text to AG supported rule format
     */
    func convertRule(ruleText: String) -> [String?] {
        if (ruleText.isEmpty || isComment(ruleText: ruleText)) {
            return [ruleText];
        }

        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText);

        if markerInfo.index != -1 {
            // If a cosmetic rule marker has been found, check for scriptlet rules
            // conversions.
            
            if (isUboScriptletRule(ruleText: ruleText, index: markerInfo.index)) {
                return [convertUboScriptletRule(rule: ruleText)];
            }

            if (isAbpSnippetRule(ruleText: ruleText, index: markerInfo.index)) {
                return convertAbpSnippetRule(rule: ruleText);
            }

            if markerInfo.marker == CosmeticRuleMarker.ElementHiding &&
                ruleText.utf8.dropFirst(markerInfo.index).starts(with: UBO_SCRIPT_TAG_MASK.utf8) {

                let uboScriptRules = convertUboScriptTagRule(rule: ruleText);
                if (uboScriptRules != nil) {
                    return uboScriptRules!;
                }
            }

            if markerInfo.marker == CosmeticRuleMarker.ElementHiding ||
                       markerInfo.marker == CosmeticRuleMarker.ElementHidingException {
                let uboCssStyleRule = convertUboCssStyleRule(rule: ruleText);
                if (uboCssStyleRule != nil) {
                    return [uboCssStyleRule!];
                }
            }
        } else {
            // Convert abp redirect rule
            let abpRedirectRule = convertAbpRedirectRule(rule: ruleText);
            if (abpRedirectRule != nil) {
                return [abpRedirectRule!];
            }

            // Convert options
            let ruleWithConvertedOptions = convertOptions(ruleText: ruleText);
            if (ruleWithConvertedOptions != nil) {
                return ruleWithConvertedOptions!;
            }

            // Convert denyallow rule
            let denyallowRules = convertDenyallowRule(rule: ruleText);
            if (denyallowRules != nil) {
                return denyallowRules!;
            }
        }

        return [ruleText];
    }

    // isComment returns true if the rule is a comment.
    private func isComment(ruleText: String) -> Bool {
        // TODO(ameshkov): !!! There's one more case, starts with HASH + SPACE
        return ruleText.utf8.first == Chars.EXCLAMATION;
    }
    
    // isUboScriptletRule2 returns true if the rule is a uBO scriptlet rule.
    // In this case the rule needs to be converted.
    private func isUboScriptletRule(ruleText: String, index: Int) -> Bool {
        let ruleContent = ruleText.utf8.dropFirst(index)
        
        return (
            ruleContent.starts(with: UBO_SCRIPTLET_MASK_1.utf8)
            || ruleContent.starts(with: UBO_SCRIPTLET_MASK_2.utf8)
            || ruleContent.starts(with: UBO_SCRIPTLET_EXCEPTION_MASK_1.utf8)
            || ruleContent.starts(with: UBO_SCRIPTLET_EXCEPTION_MASK_2.utf8)
        ) && SimpleRegex.isMatch3(regex: RuleConverter.UBO_SCRIPTLET_MASK_REGEXP, target: ruleContent);
        
    }

    private func convertUboScriptletRule(rule: String) -> String? {
        let ruleText = rule as NSString

        let mask = SimpleRegex.matches(regex: RuleConverter.UBO_SCRIPTLET_MASK_REGEXP, target: ruleText)[0];
        
        let maskIndex = ruleText.range(of: mask).lowerBound;
        let domains = ruleText.substring(to: maskIndex);

        let template: String;
        if (mask.contains("@")) {
            template = ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        } else {
            template = ADGUARD_SCRIPTLET_MASK;
        }

        guard let clean: String = getStringInBraces(str: rule as String) else {
            return nil
        }

        var parsedArgs = clean.components(separatedBy: ", ");
        if (parsedArgs.count == 1) {
            // Most probably this is not correct separator, in this case we use ','
            parsedArgs = clean.components(separatedBy: ",");
        }

        var args = [String]();
        for i in (0..<parsedArgs.count) {
            var arg = parsedArgs[i];
            if i == 0 {
                arg = "ubo-" + arg;
            }

            args.append(wrapInDoubleQuotes(str: arg));
        }

        let argsString = args.joined(separator: ", ")

        return replacePlaceholders(str: template, domains: domains, args: argsString);
    }
    
    private func isAbpSnippetRule(ruleText: String, index: Int) -> Bool {
        let ruleContent = ruleText.utf8.dropFirst(index)
        
        return (
            ruleContent.starts(with: ABP_SCRIPTLET_MASK.utf8) ||
            ruleContent.starts(with: ABP_SCRIPTLET_EXCEPTION_MASK.utf8)) &&
        !SimpleRegex.isMatch3(regex: RuleConverter.ADG_CSS_MASK_REGEXP, target: ruleContent);
    }

    /**
     * Convert string of ABP scriptlet rule to AdGuard scriptlet rule
     */
    private func convertAbpSnippetRule(rule: String) -> [String] {
        let ruleText = rule as NSString
        
        let mask = ruleText.contains(ABP_SCRIPTLET_MASK)
                ? ABP_SCRIPTLET_MASK
                : ABP_SCRIPTLET_EXCEPTION_MASK

        let template = mask == ABP_SCRIPTLET_MASK
                ? ADGUARD_SCRIPTLET_MASK
                : ADGUARD_SCRIPTLET_EXCEPTION_MASK

        let maskIndex = ruleText.range(of: mask).lowerBound
        let domains = ruleText.substring(to: maskIndex)
        let args = ruleText.substring(from: maskIndex + mask.unicodeScalars.count)

        let splitted = args.components(separatedBy: "; ")

        var result = [String]()

        for s in splitted {
            var sentences = [String]()
            let sen = getSentences(str: s);
            for part in sen {
                if (part != "") {
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

    /**
     * Converts UBO Script rule
     * @param {string} ruleText rule text
     * @returns {string} converted rule
     */
    private func convertUboScriptTagRule(rule: String) -> [String]? {
        let ruleText = rule as NSString
        
        // We convert only one case ##^script:has-text at now
        let uboHasTextRule = ":has-text";
        let adgScriptTag = "$$script";
        let uboScriptTag = "##^script";

        var match = ruleText.components(separatedBy: uboHasTextRule);
        if (match.count == 1) {
            return nil;
        }

        let domains = match[0].replace(target: uboScriptTag, withString: "");
        match.removeFirst();

        var rules = [String]();
        for m in match {
            let attr = String(m.dropFirst().dropLast());
            let isRegExp = attr.hasPrefix("/") && attr.hasSuffix("/");

            var converted: String;
            if (isRegExp) {
                converted = domains + uboScriptTag + uboHasTextRule + "(" + attr + ")"

            } else {
                converted = domains + adgScriptTag + "[tag-content=\"" + attr + "\"]";
            }

            rules.append(converted);
        }

        return rules;
    }

    /**
     * Converts CSS injection
     * example.com##h1:style(background-color: blue !important)
     * into
     * example.com#$#h1 { background-color: blue !important }
     * <p>
     * OR (for exceptions):
     * example.com#@#h1:style(background-color: blue !important)
     * into
     * example.com#@$#h1 { background-color: blue !important }
     */
    private func convertUboCssStyleRule(rule: String) -> String? {
        let ruleText = rule as NSString
        
        if (!ruleText.contains(UBO_CSS_STYLE_MASK)) {
            return nil;
        }

        let uboToInjectCssMarkersDictionary: [String: String] = [
            "##": "#$#",
            "#@#": "#@$#",
            "#?#": "#$?#",
            "#@?#": "#@$?#",
        ];

        var replacedMarkerRule: String? = nil;
        for marker in uboToInjectCssMarkersDictionary.keys {
            if (ruleText.contains(marker)) {
                replacedMarkerRule = ruleText.replacingOccurrences(of: marker, with: uboToInjectCssMarkersDictionary[marker]!)

                let result = replacedMarkerRule!.replacingOccurrences(of: UBO_CSS_STYLE_MASK, with: " { ");
                return (String(result.dropLast()) + " }");
            }
        }

        return nil;
    }

    /**
     * Converts abp rule into ag rule
     * e.g.
     * from:    "||example.org^$rewrite=abp-resource:blank-mp3"
     * to:      "||example.org^$redirect:blank-mp3"
     */
    private func convertAbpRedirectRule(rule: String) -> String? {
        let ruleText = rule as NSString
        
        let ABP_REDIRECT_KEYWORD = "rewrite=abp-resource:";
        let AG_REDIRECT_KEYWORD = "redirect=";
        if (!ruleText.contains(ABP_REDIRECT_KEYWORD)) {
            return nil;
        }

        return ruleText.replacingOccurrences(of: ABP_REDIRECT_KEYWORD, with: AG_REDIRECT_KEYWORD);
    }

    private static let EMPTY_OPTION = "empty";
    private static let MP4_OPTION = "mp4";
    private static let MEDIA_OPTION = "media";
    private static let CSP_OPTION = "csp";
    private static let INLINE_SCRIPT_OPTION = "inline-script";
    private static let INLINE_FONT_OPTION = "inline-font";
    private static let ALL_OPTION = "all";
    private static let POPUP_OPTION = "popup";
    private static let DOCUMENT_OPTION = "document";
    private static let UBO_1P_OPTION = "1p";
    private static let UBO_3P_OPTION = "3p";

    private static let conversionMap: [String: String] = [
        EMPTY_OPTION: "redirect=nooptext",
        MP4_OPTION: "redirect=noopmp4-1s",
        INLINE_SCRIPT_OPTION: CSP_OPTION + "=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:",
        INLINE_FONT_OPTION: CSP_OPTION + "=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:",
        UBO_1P_OPTION: "~third-party",
        UBO_3P_OPTION: "third-party"
    ]

    private func convertOptions(ruleText: String) -> [String]? {
        var pattern: String = ""
        var options: String? = nil
        do {
            let parseResult = try NetworkRuleParser.parseRuleText(ruleText: ruleText)
            options = parseResult.options
            if (options == nil || options == "") {
                return nil
            }

            pattern = NetworkRuleParser.getAsciiDomainRule(pattern: parseResult.pattern) ?? ""
            if parseResult.whitelist {
                pattern = RuleConverter.EXCEPTION_MASK + pattern
            }
        } catch {
            return [ruleText]
        }

        let optionParts = options!.splitByDelimiterWithEscapeCharacter(delimiter: RuleConverter.delimeterChar, escapeChar: RuleConverter.escapeChar)

        var optionsConverted = false

        var updatedOptionsParts = [String]()
        var cspOptions = [String]()
        for part in optionParts {
            var cursor = part;
            var convertedOptionsPart = RuleConverter.conversionMap[part]

            if (convertedOptionsPart != nil) {
                // if option is $mp4, than it should go with $media option together
                // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/1452
                if (part == RuleConverter.MP4_OPTION) {
                    // check if media is not already among options
                    if (optionParts.firstIndex(of: RuleConverter.MEDIA_OPTION) == nil) {
                        convertedOptionsPart = convertedOptionsPart! + ",media"
                    }
                }

                optionsConverted = true
                cursor = convertedOptionsPart!
            }

            if (cursor.hasPrefix(RuleConverter.CSP_OPTION + "=")) {
                cspOptions.append(cursor.subString(startIndex: RuleConverter.CSP_OPTION.unicodeScalars.count + 1))
                continue
            }

            updatedOptionsParts.append(cursor)
        }

        if (cspOptions.count > 0) {
            // if has more than one csp modifiers, we merge them into one
            updatedOptionsParts.append(RuleConverter.CSP_OPTION + "=" + cspOptions.joined(separator: "; "));
        }

        // options with all modifier
        let hasAllOption = updatedOptionsParts.firstIndex(of: RuleConverter.ALL_OPTION) != nil;
        if (hasAllOption) {
            let allOptionReplacers = [
                RuleConverter.DOCUMENT_OPTION,
                RuleConverter.POPUP_OPTION,
                RuleConverter.INLINE_SCRIPT_OPTION,
                RuleConverter.INLINE_FONT_OPTION,
            ]

            var rules = [String]();
            for replacer in allOptionReplacers {
                // remove replacer and all option from the list
                var optionsButAllAndReplacer = [String]()
                for o in updatedOptionsParts {
                    if (o != replacer && o != RuleConverter.ALL_OPTION) {
                        optionsButAllAndReplacer.append(o)
                    }
                }

                // try get converted values, used for INLINE_SCRIPT_OPTION, INLINE_FONT_OPTION
                let convertedReplacer = RuleConverter.conversionMap[replacer] ?? replacer

                // add replacer to the list of options
                optionsButAllAndReplacer.append(convertedReplacer)
                let updatedOptionsString = optionsButAllAndReplacer.reversed().joined(separator: ",")

                // create a new rule
                let newRule = pattern + "$" + updatedOptionsString
                rules.append(newRule)
            }

            return rules
        }

        if (optionsConverted) {
            let newRule = pattern + "$" + updatedOptionsParts.joined(separator: ",")
            return [newRule]
        }

        return nil
    }

    // Helpers

    /**
     * Return array of strings separated by space which not in quotes
     */
    private func getSentences(str: String) -> [String] {
        return SimpleRegex.matches(regex: RuleConverter.SENTENCES_REGEXP, target: str as NSString)
    }

    private func getStringInBraces(str: String) -> String? {
        let firstIndex = str.indexOf(target: "(")
        let lastIndex = str.lastIndexOf(target: ")")
        if firstIndex > lastIndex {
            return nil
        }
        return str.subString(startIndex: firstIndex + 1, length: lastIndex - firstIndex - 1)
    }

    private func wrapInDoubleQuotes(str: String) -> String {
        var modified = str as NSString
        // https://github.com/AdguardTeam/SafariConverterLib/issues/34
        if str.unicodeScalars.count <= 1 {
            modified = modified
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "'", with: "\'") as NSString
        } else if str.hasPrefix("\'") && str.hasSuffix("\'") {
            modified = modified
                    .substring(with: NSRange(location: 1, length: modified.length - 2))
                    .replacingOccurrences(of: "\"", with: "\\\"") as NSString
        } else if str.hasPrefix("\"") && str.hasSuffix("\"") {
            modified = modified
                    .substring(with: NSRange(location: 1, length: modified.length - 1))
                    .replacingOccurrences(of: "'", with: "\'") as NSString
        }

        return "\"\(modified)\""
    }

    private func replacePlaceholders(str: String, domains: String, args: String) -> String {
        var result = str.replace(target: "${domains}", withString: domains)
        result = result.replace(target: "${args}", withString: args)

        return result
    }

    /**
     * Validates and converts rule with $denyallow modifier into blocking rule and additional exception rules
     * https:github.com/AdguardTeam/CoreLibs/issues/1304
     */
    private func convertDenyallowRule(rule: String) -> [String]? {
        let ruleText = rule as NSString
        
        if (!ruleText.contains(RuleConverter.DENYALLOW_MODIFIER_MASK)) {
            return nil;
        }

        let rule = try! NetworkRuleParser.parseRuleText(ruleText: rule);

        if (rule.pattern!.hasPrefix("|") || rule.pattern!.hasPrefix("||") || !ruleText.contains(RuleConverter.DOMAIN_MODIFIER_MASK)) {
            // Rule's matching pattern cannot target any domain or been used without $domain modifier
            return nil;
        }

        var blockingElement: String = rule.pattern!;
        if (blockingElement.starts(with: "/")) {
            blockingElement = String(blockingElement.dropFirst());
        }

        let isGenericRule = blockingElement == "" || blockingElement == "*";

        let ruleOptions = rule.options!.components(separatedBy: ",");
        let denyallowOption = ruleOptions.first(where: { $0.contains(RuleConverter.DENYALLOW_MODIFIER_MASK) })!;

        // get denyallow domains list
        let denyallowDomains = denyallowOption.replace(target: RuleConverter.DENYALLOW_MODIFIER_MASK, withString: "").components(separatedBy: "|");

        for domain in denyallowDomains {
            if (domain.hasPrefix("~") || domain.contains("*")) {
                // Modifier $denyallow cannot be negated or have a wildcard TLD
                return nil;
            }
        }

        // remove denyallow from options
        let optionsWithoutDenyallow = ruleOptions.filter { part in
                    return part != denyallowOption;
                }
                .joined(separator: ",");

        var result = [String]();

        let blockingRulePrefix: String = rule.whitelist ? "@@" : "";
        let exceptionRulePrefix: String = rule.whitelist ? "||" : RuleConverter.EXCEPTION_SUFFIX;
        let exceptionRuleSuffix: String = rule.whitelist ? "," + RuleConverter.IMPORTANT_MODIFIER_MASK : "";

        // blocking rule
        let blockingRule = blockingRulePrefix + rule.pattern! + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow;
        result.append(blockingRule);

        // exception rules
        for domain in denyallowDomains {
            if (!isGenericRule) {
                let exceptionRule = exceptionRulePrefix + domain + "/" + blockingElement + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow + exceptionRuleSuffix;
                result.append(exceptionRule);

                let exceptionRuleWide = exceptionRulePrefix + domain + "/*/" + blockingElement + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow + exceptionRuleSuffix;
                result.append(exceptionRuleWide);

            } else {
                let exceptionRule = exceptionRulePrefix + domain + RuleConverter.MODIFIER_MASK + optionsWithoutDenyallow + exceptionRuleSuffix;
                result.append(exceptionRule);
            }
        }

        return result;
    }
}
