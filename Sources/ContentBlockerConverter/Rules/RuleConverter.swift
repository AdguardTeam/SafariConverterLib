import Foundation

/**
 * Rule converter class.
 * Converts third-party and some unsupported constructions to AG rules
 */
class RuleConverter {
    private let COMMENT = "!".utf16.first!;
    private static let UBO_SCRIPTLET_MASK_REG = "##script\\:inject|#@?#\\s*\\+js";
    private static let UBO_SCRIPTLET_MASK_REGEXP = try! NSRegularExpression(pattern: UBO_SCRIPTLET_MASK_REG, options: [.caseInsensitive]);
    private static let SENTENCES_REGEXP = try! NSRegularExpression(pattern: #"'.*?'|".*?"|\S+"#, options: [.caseInsensitive]);
    
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
    func convertRule(rule: NSString) -> [NSString] {
        if (rule.length == 0 || isComment(rule: rule)) {
            return [rule];
        }
        
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: rule);
        if markerInfo.index != -1 {
            if (isUboScriptletRule(rule: rule, index: markerInfo.index)) {
                return [convertUboScriptletRule(rule: rule)];
            }

            if (isAbpSnippetRule(rule: rule, index: markerInfo.index)) {
                return convertAbpSnippetRule(rule: rule);
            }

            if markerInfo.marker == CosmeticRuleMarker.ElementHiding &&
                rule.substring(from: markerInfo.index).hasPrefix(UBO_SCRIPT_TAG_MASK) {

                let uboScriptRules = convertUboScriptTagRule(ruleText: rule);
                if (uboScriptRules != nil) {
                    return uboScriptRules!;
                }
            }

            if markerInfo.marker == CosmeticRuleMarker.ElementHiding ||
                markerInfo.marker == CosmeticRuleMarker.ElementHidingException {
                let uboCssStyleRule = convertUboCssStyleRule(ruleText: rule);
                if (uboCssStyleRule != nil) {
                    return [uboCssStyleRule!];
                }
            }
        } else {
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
        }
        
        return [rule];
    }
    
    private func isComment(rule: NSString) -> Bool {
        return rule.character(at: 0) == COMMENT;
    }
    
    private func isUboScriptletRule(rule: NSString, index: Int) -> Bool {
        let ruleContent = rule.substring(from: index)
        
        return (
            ruleContent.hasPrefix(UBO_SCRIPTLET_MASK_1)
                || ruleContent.hasPrefix(UBO_SCRIPTLET_MASK_2)
                || ruleContent.hasPrefix(UBO_SCRIPTLET_EXCEPTION_MASK_1)
                || ruleContent.hasPrefix(UBO_SCRIPTLET_EXCEPTION_MASK_2)
        ) && SimpleRegex.isMatch(regex: RuleConverter.UBO_SCRIPTLET_MASK_REGEXP, target: ruleContent);
    }
    
    private func convertUboScriptletRule(rule: NSString) -> NSString {
        let mask = SimpleRegex.matches(regex: RuleConverter.UBO_SCRIPTLET_MASK_REGEXP, target: rule as String)[0];
        let maskIndex = rule.range(of: mask).lowerBound;
        let domains = rule.substring(to: maskIndex);

        let template: String;
        if (mask.contains("@")) {
            template = ADGUARD_SCRIPTLET_EXCEPTION_MASK;
        } else {
            template = ADGUARD_SCRIPTLET_MASK;
        }

        let clean = getStringInBraces(str: rule as String);
        var parsedArgs = clean.components(separatedBy: ", ");
        if (parsedArgs.count == 1) {
            // Most probably this is not correct separator, in this case we use ','
            parsedArgs = clean.components(separatedBy: ",");
        }

        var args = [String]();
        for i in (0 ..< parsedArgs.count) {
            var arg = parsedArgs[i];
            if i == 0 {
                arg = "ubo-" + arg;
            }
            
            args.append(wrapInDoubleQuotes(str: arg));
        }
        
        let argsString = args.joined(separator: ", ")

        return replacePlaceholders(str: template, domains: domains, args: argsString);
    }
    
    private func isAbpSnippetRule(rule: NSString, index: Int) -> Bool {
        let ruleContent = rule.substring(from: index)

        return (
            ruleContent.hasPrefix(ABP_SCRIPTLET_MASK) ||
                ruleContent.hasPrefix(ABP_SCRIPTLET_EXCEPTION_MASK)) &&
            !SimpleRegex.isMatch(regex: RuleConverter.ADG_CSS_MASK_REGEXP, target: rule as String);
    }

    /**
     * Convert string of ABP scriptlet rule to AdGuard scriptlet rule
     */
    private func convertAbpSnippetRule(rule: NSString) -> [NSString] {
        let mask = rule.contains(ABP_SCRIPTLET_MASK)
            ? ABP_SCRIPTLET_MASK
            : ABP_SCRIPTLET_EXCEPTION_MASK;

        let template = mask == ABP_SCRIPTLET_MASK
            ? ADGUARD_SCRIPTLET_MASK
            : ADGUARD_SCRIPTLET_EXCEPTION_MASK;

        let maskIndex = rule.range(of: mask).lowerBound;
        let domains = rule.substring(to: maskIndex);
        let args = rule.substring(from: maskIndex + mask.count);

        let splitted = args.components(separatedBy: "; ");

        var result = [NSString]();

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

            let converted = replacePlaceholders(str: template, domains: domains, args: wrapped.joined(separator: ", "))
            result.append(converted as NSString);
        }

        return result;
    }

    /**
     * Converts UBO Script rule
     * @param {string} ruleText rule text
     * @returns {string} converted rule
     */
    private func convertUboScriptTagRule(ruleText: NSString) -> [NSString]? {
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

        var rules = [NSString]();
        for m in match {
            let attr = String(m.dropFirst().dropLast());
            let isRegExp = attr.hasPrefix("/") && attr.hasSuffix("/");

            var converted: String;
            if (isRegExp) {
                converted = domains + uboScriptTag + uboHasTextRule + "(" + attr + ")"

            } else {
                converted = domains + adgScriptTag + "[tag-content=\"" + attr + "\"]";
            }

            rules.append(converted as NSString);
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
    private func convertUboCssStyleRule(ruleText: NSString) -> NSString? {
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
                return (String(result.dropLast()) + " }") as NSString;
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
    private func convertAbpRedirectRule(rule: NSString) -> NSString? {
        let ABP_REDIRECT_KEYWORD = "rewrite=abp-resource:";
        let AG_REDIRECT_KEYWORD = "redirect=";
        if (!rule.contains(ABP_REDIRECT_KEYWORD)) {
            return nil;
        }
        return rule.replacingOccurrences(of: ABP_REDIRECT_KEYWORD, with: AG_REDIRECT_KEYWORD) as NSString;
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

    private static let conversionMap : [String:String] = [
        EMPTY_OPTION : "redirect=nooptext",
        MP4_OPTION : "redirect=noopmp4-1s",
        INLINE_SCRIPT_OPTION : CSP_OPTION + "=script-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:",
        INLINE_FONT_OPTION : CSP_OPTION + "=font-src 'self' 'unsafe-eval' http: https: data: blob: mediastream: filesystem:",
        UBO_1P_OPTION: "first-party",
        UBO_3P_OPTION: "third-party"
    ]

    private func convertOptions(rule: NSString) -> [NSString]? {
        var pattern: String = "";
        var options: String? = nil;
        do {
            let parseResult = try NetworkRuleParser.parseRuleText(ruleText: rule);
            options = parseResult.options;
            if (options == nil || options == "") {
                return nil;
            }

            pattern = NetworkRuleParser.getAsciiDomainRule(pattern: parseResult.pattern) ?? "";
        } catch {
            return [rule];
        }

        let optionParts = options!.splitByDelimiterWithEscapeCharacter(delimeter: RuleConverter.delimeterChar, escapeChar: RuleConverter.escapeChar);

        var optionsConverted = false;

        var updatedOptionsParts = [String]();
        var cspOptions = [String]();
        for part in optionParts {
            var cursor = part;
            var convertedOptionsPart = RuleConverter.conversionMap[part];

            if (convertedOptionsPart != nil) {
                // if option is $mp4, than it should go with $media option together
                // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/1452
                if (part == RuleConverter.MP4_OPTION) {
                    // check if media is not already among options
                    if (optionParts.firstIndex(of: RuleConverter.MEDIA_OPTION) == nil) {
                        convertedOptionsPart = convertedOptionsPart! + ",media";
                    }
                }

                optionsConverted = true;
                cursor = convertedOptionsPart!;
            }

            if (cursor.hasPrefix(RuleConverter.CSP_OPTION + "=")) {
                cspOptions.append(cursor.subString(startIndex: RuleConverter.CSP_OPTION.count + 1));
                continue;
            }

            updatedOptionsParts.append(cursor);
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
            ];

            var rules = [NSString]();
            for replacer in allOptionReplacers {
                // remove replacer and all option from the list
                var optionsButAllAndReplacer = [String]();
                for o in updatedOptionsParts {
                    if (o != replacer && o != RuleConverter.ALL_OPTION) {
                        optionsButAllAndReplacer.append(o);
                    }
                }

                // try get converted values, used for INLINE_SCRIPT_OPTION, INLINE_FONT_OPTION
                let convertedReplacer = RuleConverter.conversionMap[replacer] ?? replacer;

                // add replacer to the list of options
                optionsButAllAndReplacer.append(convertedReplacer)
                let updatedOptionsString = optionsButAllAndReplacer.reversed().joined(separator: ",");

                // create a new rule
                let newRule = pattern + "$" + updatedOptionsString;
                rules.append(newRule as NSString);
            }

            return rules;
        }

        if (optionsConverted) {
            let newRule = pattern + "$" + updatedOptionsParts.joined(separator: ",")
            return [newRule as NSString];
        }

        return nil;
    }

    // Helpers

    /**
     * Return array of strings separated by space which not in quotes
     */
    private func getSentences(str: String) -> [String] {
        return SimpleRegex.matches(regex: RuleConverter.SENTENCES_REGEXP, target: str);
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

    private func replacePlaceholders(str: String, domains: String, args: String) -> NSString {
        var result = str.replace(target: "${domains}", withString: domains);
        result = result.replace(target: "${args}", withString: args);
        
        return result as NSString;
    }
}
