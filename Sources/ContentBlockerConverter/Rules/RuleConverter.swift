import Foundation

/**
 * Rule converter class.
 * Converts third-party and some unsupported constructions to AG rules
 */
class RuleConverter {
    private let COMMENT = "!";
    
    private let UBO_SCRIPTLET_MASK_REG = "##script\\:inject|#@?#\\s*\\+js";
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
    private let ADG_CSS_MASK_REG = "#@?\\$#.+?\\s*\\{.*\\}\\s*$";
    private let ADG_CSS_BLOCKING_RULE_MASK = "##";
    private let ADG_CSS_BLOCKING_RULE_EXCEPTION_MASK = "#@#";
    
    /**
     * AdGuard scriptlet mask
     */
    private let ADGUARD_SCRIPTLET_MASK = "${domains}#%#//scriptlet(${args})";

    /**
     * AdGuard scriptlet exception mask
     */
    private let ADGUARD_SCRIPTLET_EXCEPTION_MASK = "${domains}#@%#//scriptlet(${args})";

    /**
     * Maximum domains amount for css blocking rule
     */
    private let MAX_DOMAINS_FOR_CSS_BLOCKING_RULE = 250;
    
    /**
     * Converts text to AG supported rule format
     */
    func convertRule(rule: String) -> [String] {
        if (isComment(rule: rule)) {
            return [rule];
        }
        
        if (isUboScriptletRule(rule: rule)) {
            return [convertUboScriptletRule(rule: rule)];
        }
        
        if (isAbpSnippetRule(rule: rule)) {
            return convertAbpSnippetRule(rule: rule);
        }
        
        let uboScriptRules = convertUboScriptTagRule(ruleText: rule);
        if (uboScriptRules != nil) {
            return uboScriptRules!;
        }

        let uboCssStyleRule = convertUboCssStyleRule(ruleText: rule);
        if (uboCssStyleRule != nil) {
            return [uboCssStyleRule!];
        }

        // Convert abp redirect rule
        let abpRedirectRule = convertAbpRedirectRule(rule: rule);
        if (abpRedirectRule != nil) {
            return [abpRedirectRule!];
        }

        // Convert options
        let ruleWithConvertedOptions = convertOptions(rule: rule);
        if (ruleWithConvertedOptions != nil) {
            return ruleWithConvertedOptions!;
        }

        if (isCssBlockingRule(rule: rule)) {
            return handleMaxDomains(rule: rule);
        }
        
        return [rule];
    }
    
    private func isComment(rule: String) -> Bool {
        return rule.hasPrefix(COMMENT);
    }
    
    private func isUboScriptletRule(rule: String) -> Bool {
        return (rule.contains(UBO_SCRIPTLET_MASK_1) || rule.contains(UBO_SCRIPTLET_MASK_2) || rule.contains(UBO_SCRIPTLET_EXCEPTION_MASK_1) || rule.contains(UBO_SCRIPTLET_EXCEPTION_MASK_2)) && rule.isMatch(regex: UBO_SCRIPTLET_MASK_REG);
    }
    
    private func convertUboScriptletRule(rule: String) -> String {
        let mask = rule.matches(regex: UBO_SCRIPTLET_MASK_REG)[0];
        let domains = rule.subString(from: 0, toSubstring: mask);

        let template: String;
        if (mask.contains("@")) {
            template = ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        } else {
            template = ADGUARD_SCRIPTLET_MASK;
        }

        let clean = getStringInBraces(str: rule);
        let parsedArgs = clean.components(separatedBy: ", ");
          
        var args = [String]();
        for i in (0 ..< parsedArgs.count) {
            var arg = parsedArgs[i];
            if i == 0 {
                arg = "ubo-" + arg;
            }
            
            args.append(wrapInDoubleQuotes(str: arg));
        }
        
        let argsString = args.joined(separator: ", ")

        return replacePlaceholders(str: template, domains: domains!, args: argsString);
    }
    
    private func isAbpSnippetRule(rule: String) -> Bool {
        return (
            rule.contains(ABP_SCRIPTLET_MASK) ||
            rule.contains(ABP_SCRIPTLET_EXCEPTION_MASK)) &&
            !rule.isMatch(regex: ADG_CSS_MASK_REG);
    }
    
    /**
     * Convert string of ABP scriptlet rule to AdGuard scriptlet rule
     */
    private func convertAbpSnippetRule(rule: String) -> [String] {
        let mask = rule.contains(ABP_SCRIPTLET_MASK)
            ? ABP_SCRIPTLET_MASK
            : ABP_SCRIPTLET_EXCEPTION_MASK;
        
        let template = mask == ABP_SCRIPTLET_MASK
            ? ADGUARD_SCRIPTLET_MASK
            : ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        
        let domains = rule.subString(from: 0, toSubstring: mask);
        let maskIndex = rule.indexOf(target: mask);
        let args = rule.subString(startIndex: maskIndex + mask.count);
        
        let splitted = args.components(separatedBy: "; ");
        
        var result = [String]();
        
        for s in splitted {
            
            var sentences = [String]();
            let sen = getSentences(str: s);
            for part in sen {
                if (part != "") {
                    sentences.append(part);
                }
            }
            
            var wrapped = [String]();
            for (index, sentence) in sentences.enumerated() {
                let w = index == 0 ? "abp-" + sentence : sentence;
                wrapped.append(wrapInDoubleQuotes(str: w));
            }
            
            let converted = replacePlaceholders(str: template, domains: domains!, args: wrapped.joined(separator: ", "))
            result.append(converted);
        }
        
        return result;
    }

    private func isCssBlockingRule(rule: String) -> Bool {
        return (
            !rule.contains(UBO_SCRIPTLET_MASK_1) ||
            !rule.contains(UBO_SCRIPTLET_MASK_2) ||
            !rule.contains(UBO_SCRIPTLET_EXCEPTION_MASK_1) ||
            !rule.contains(UBO_SCRIPTLET_EXCEPTION_MASK_2) ||
            !rule.contains(UBO_SCRIPT_TAG_MASK) &&
            (rule.contains(ADG_CSS_BLOCKING_RULE_MASK) ||
             rule.contains(ADG_CSS_BLOCKING_RULE_EXCEPTION_MASK))
        );
    }

    /**
     * Check domains amount in rule and if it's over limit divides into separate rules
     */
    private func checkAndDivideRule(rule: String, mask: String) -> [String] {
        let splitted = rule.components(separatedBy: mask);
            let domains = splitted[0].components(separatedBy: ",");
            let selectors = splitted[1];

            if (domains.count > MAX_DOMAINS_FOR_CSS_BLOCKING_RULE) {
                let rulesNum = domains.count / MAX_DOMAINS_FOR_CSS_BLOCKING_RULE;
                var resultRules = [String]();

                for n in 1...rulesNum {
                    let limitedDomains = domains.prefix(MAX_DOMAINS_FOR_CSS_BLOCKING_RULE * n).suffix(MAX_DOMAINS_FOR_CSS_BLOCKING_RULE).joined(separator: ",");
                    let limitedRule = limitedDomains + mask + selectors;
                    resultRules.append(limitedRule);
                }

                if (domains.count % MAX_DOMAINS_FOR_CSS_BLOCKING_RULE > 0) {
                    let lastRuleDomainsNum = domains.count % MAX_DOMAINS_FOR_CSS_BLOCKING_RULE;
                    let lastRuleDomains = domains.suffix(lastRuleDomainsNum).joined(separator: ",");
                    let limitedRule = lastRuleDomains + mask + selectors;
                    resultRules.append(limitedRule);
                }
                return resultRules;
            }
            return [rule];
    }

    /**
     * Handle domains amount for css blocking rules and exceptions
     */
    func handleMaxDomains(rule: String) -> [String] {
        if (rule.contains(ADG_CSS_BLOCKING_RULE_EXCEPTION_MASK)) {
            return checkAndDivideRule(rule: rule, mask: ADG_CSS_BLOCKING_RULE_EXCEPTION_MASK);
        }
        if (rule.contains(ADG_CSS_BLOCKING_RULE_MASK)) {
            return checkAndDivideRule(rule: rule, mask: ADG_CSS_BLOCKING_RULE_MASK);
        }
        return [rule];
    }

    /**
     * Converts UBO Script rule
     * @param {string} ruleText rule text
     * @returns {string} converted rule
     */
    private func convertUboScriptTagRule(ruleText: String) -> [String]? {
        if (!ruleText.contains(UBO_SCRIPT_TAG_MASK)) {
            return nil;
        }

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
            
            if (isRegExp) {
                rules.append(domains + uboScriptTag + uboHasTextRule + "(" + attr + ")");
            } else {
                rules.append(domains + adgScriptTag + "[tag-content=\"" + attr + "\"]");
            }
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
    private func convertUboCssStyleRule(ruleText: String) -> String? {
        if (!ruleText.contains(UBO_CSS_STYLE_MASK)) {
            return nil;
        }
        
        let uboToInjectCssMarkersDictionary : [String:String] = [
            "##" : "#$#",
            "#@#" : "#@$#",
            "#?#" : "#$?#",
            "#@?#" : "#@$?#",
        ];
        
        var replacedMarkerRule : String? = nil;
        for marker in uboToInjectCssMarkersDictionary.keys {
            if (ruleText.contains(marker)) {
                replacedMarkerRule = ruleText.replacingOccurrences(of: marker, with: uboToInjectCssMarkersDictionary[marker]!)
                
                let result = replacedMarkerRule!.replacingOccurrences(of: UBO_CSS_STYLE_MASK, with: " { ");
                return String(result.dropLast()) + " }";
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
        let ABP_REDIRECT_KEYWORD = "rewrite=abp-resource:";
        let AG_REDIRECT_KEYWORD = "redirect=";
        if (!rule.contains(ABP_REDIRECT_KEYWORD)) {
            return nil;
        }
        return rule.replace(target: ABP_REDIRECT_KEYWORD, withString: AG_REDIRECT_KEYWORD);
    }
    
    private func convertOptions(rule: String) -> [String]? {
        let EMPTY_OPTION = "empty";
        let MP4_OPTION = "mp4";
        let MEDIA_OPTION = "media";
        let CSP_OPTION = "csp";
        let INLINE_SCRIPT_OPTION = "inline-script";
        let INLINE_FONT_OPTION = "inline-font";
        let ALL_OPTION = "all";
        let POPUP_OPTION = "popup";
        let DOCUMENT_OPTION = "document";

        let conversionMap : [String:String] = [
            EMPTY_OPTION : "redirect=nooptext",
            MP4_OPTION : "redirect=noopmp4-1s",
            INLINE_SCRIPT_OPTION : CSP_OPTION + "=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:",
            INLINE_FONT_OPTION : CSP_OPTION + "=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:"
        ]

        var pattern: String = "";
        var options: String? = nil;
        do {
            let parseResult = try NetworkRuleParser.parseRuleText(ruleText: rule);
            options = parseResult.options;
            pattern = parseResult.pattern ?? "";
            if (options == nil) {
                return nil;
            }
        } catch {
            return [rule];
        }
        
        let optionParts = options!.splitByDelimiterWithEscapeCharacter(delimeter: ",", escapeChar: "\\");
        
        var optionsConverted = false;
        
        var updatedOptionsParts = [String]();
        var cspOptions = [String]();
        for part in optionParts {
            var cursor = part;
            var convertedOptionsPart = conversionMap[part];
            
            if (convertedOptionsPart != nil) {
                // if option is $mp4, than it should go with $media option together
                // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/1452
                if (part == MP4_OPTION) {
                    // check if media is not already among options
                    if (optionParts.firstIndex(of: MEDIA_OPTION) == nil) {
                        convertedOptionsPart = convertedOptionsPart! + ",media";
                    }
                }

                optionsConverted = true;
                cursor = convertedOptionsPart!;
            }
            
            if (cursor.hasPrefix(CSP_OPTION)) {
                cspOptions.append(cursor.subString(startIndex: CSP_OPTION.count + 1));
                continue;
            }

            updatedOptionsParts.append(cursor);
        }

        if (cspOptions.count > 0) {
            // if has more than one csp modifiers, we merge them into one
            updatedOptionsParts.append(CSP_OPTION + "=" + cspOptions.joined(separator: "; "));
        }

        // options with all modifier
        let hasAllOption = updatedOptionsParts.firstIndex(of: ALL_OPTION) != nil;
        if (hasAllOption) {
            let allOptionReplacers = [
                DOCUMENT_OPTION,
                POPUP_OPTION,
                INLINE_SCRIPT_OPTION,
                INLINE_FONT_OPTION,
            ];
            
            var rules = [String]();
            for replacer in allOptionReplacers {
                // remove replacer and all option from the list
                var optionsButAllAndReplacer = [String]();
                for o in updatedOptionsParts {
                    if (o != replacer && o != ALL_OPTION) {
                        optionsButAllAndReplacer.append(o);
                    }
                }

                // try get converted values, used for INLINE_SCRIPT_OPTION, INLINE_FONT_OPTION
                let convertedReplacer = conversionMap[replacer] ?? replacer;

                // add replacer to the list of options
                optionsButAllAndReplacer.append(convertedReplacer)
                let updatedOptionsString = optionsButAllAndReplacer.reversed().joined(separator: ",");
                
                // create a new rule
                rules.append(pattern + "$" + updatedOptionsString);
            }
            
            return rules;
        }

        if (optionsConverted) {
            return [pattern + "$" + updatedOptionsParts.joined(separator: ",")];
        }

        return nil;
    }

    // Helpers
    
    /**
    * Return array of strings separated by space which not in quotes
    */
    private func getSentences(str: String) -> [String] {
        let reg = #"'.*?'|".*?"|\S+"#;
        return str.matches(regex: reg);
    }

    private func getStringInBraces(str: String) -> String {
        let firstIndex = str.indexOf(target: "(");
        let lastIndex = str.lastIndexOf(target: ")");
        return str.subString(startIndex: firstIndex + 1, length: lastIndex - firstIndex - 1);
    }
    
    private func wrapInDoubleQuotes(str: String) -> String {
        var modified = str;
        if str.hasPrefix("\'") && str.hasSuffix("\'") {
            modified = str.subString(startIndex: 1, length: str.count - 2);
            modified = modified.replace(target: "\"", withString: "\\\"");
        } else if str.hasPrefix("\"") && str.hasSuffix("\"") {
            modified = str.subString(startIndex: 1, length: str.count - 1);
            modified = modified.replace(target: "'", withString: "\'");
        }
        
        return "\"" + modified + "\"";
    }
    
    private func replacePlaceholders(str: String, domains: String, args: String) -> String {
        var result = str.replace(target: "${domains}", withString: domains);
        result = result.replace(target: "${args}", withString: args);
        
        return result;
    }
}
