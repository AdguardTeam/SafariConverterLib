import Foundation

/**
 * Rule converter
 */
class RuleConverter {
    private let COMMENT = "!";
    
    private let UBO_SCRIPTLET_MASK_REG = "##script\\:inject|#@?#\\s*\\+js";
    private let UBO_SCRIPTLET_MASK_1 = "##+js";
    private let UBO_SCRIPTLET_MASK_2 = "##script:inject";
    private let UBO_SCRIPTLET_EXCEPTION_MASK_1 = "#@#+js";
    private let UBO_SCRIPTLET_EXCEPTION_MASK_2 = "#@#script:inject";
    private let UBO_SCRIPT_TAG_MASK = "##^script";
    
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
    func convertRule(rule: String) -> [String] {
        if (isComment(rule: rule)) {
            return [rule];
        }
        
        if (isUboScriptletRule(rule: rule)) {
            return [convertUboScriptletRule(rule: rule)];
        }
        
//        if (isAbpSnippetRule(rule)) {
//            return convertAbpSnippetRule(rule);
//        }
//
//        const uboScriptRule = convertUboScriptTagRule(rule);
//        if (uboScriptRule) {
//            return uboScriptRule;
//        }
//
//        const uboCssStyleRule = convertUboCssStyleRule(rule);
//        if (uboCssStyleRule) {
//            return uboCssStyleRule;
//        }
//
//        // Convert abp redirect rule
//        const abpRedirectRule = convertAbpRedirectRule(rule);
//        if (abpRedirectRule) {
//            return abpRedirectRule;
//        }
//
//        // Convert options
//        const ruleWithConvertedOptions = convertOptions(rule);
//        if (ruleWithConvertedOptions) {
//            return ruleWithConvertedOptions;
//        }
//
//        return rule;
        
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

    // Helpers

    private func getStringInBraces(str: String) -> String {
        let firstIndex = str.indexOf(target: "(");
        let lastIndex = str.lastIndexOf(target: ")");
        return str.subString(startIndex: firstIndex + 1, length: lastIndex - firstIndex - 1);
    }
    
    private func wrapInDoubleQuotes(str: String) -> String {
        var modified = str;
        if str.hasPrefix("\'") && str.hasSuffix("\'") {
            modified = str.subString(startIndex: 1, length: str.count - 1);
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
