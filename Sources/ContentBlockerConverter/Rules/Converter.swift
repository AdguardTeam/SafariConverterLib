import Foundation

/**
 * Converter class
 */
class Converter {
    /**
     * Using .* for the css-display-none rules trigger.url-filter.
     * Please note, that this is important to use ".*" for this kind of rules, otherwise performance is degraded:
     * https://github.com/AdguardTeam/AdguardForiOS/issues/662
     */
    static let URL_FILTER_CSS_RULES = ".*";
    static let URL_FILTER_SCRIPT_RULES = ".*";
    static let URL_FILTER_SCRIPTLET_RULES = ".*";
    
    let advancedBlockingEnabled: Bool;
    
    init(advancedBlockingEnabled: Bool) {
        self.advancedBlockingEnabled = advancedBlockingEnabled;
    }
    
    /**
     * Converts rule object to blocker entry
     */
    func convertRuleToBlockerEntry(rule: Rule) -> BlockerEntry? {
        if (rule is NetworkRule) {
            return convertNetworkRule(rule: rule as! NetworkRule);
        } else {
            if (self.advancedBlockingEnabled) {
                if (rule.isScript) {
                    return convertScriptRule(rule: rule as! CosmeticRule);
                } else if (rule.isScriptlet) {
                    return convertScriptletRule(rule: rule as! CosmeticRule);
                }
            }
            
            return convertCssRule(rule: rule as! CosmeticRule);
        }
    }
    
    /**
     * Converts url filter rule
     *
     * @param rule
     * @return {*}
     */
    private func convertNetworkRule(rule: NetworkRule) -> BlockerEntry? {
        if (rule.isCspRule) {
            // CSP rules are not supported
            return nil;
        }

        let urlFilter = "";
//        const urlFilter = createUrlFilterString(rule);
//
//        validateRegExp(urlFilter);

//        const result = {
//            trigger: {
//                "url-filter": urlFilter
//            },
//            action: {
//                type: "block"
//            }
//        };
//
//        setWhiteList(rule, result);
//        addResourceType(rule, result);
//        addThirdParty(result.trigger, rule);
//        addMatchCase(result.trigger, rule);
//        addDomainOptions(result.trigger, rule);
//
//        // Check whitelist exceptions
//        checkWhiteListExceptions(rule, result);
//
//        // Validate the rule
//        validateUrlBlockingRule(result, rule);
//
//        return result;
        
        return nil;
    };
    
    private func convertScriptRule(rule: CosmeticRule) -> BlockerEntry? {
        var trigger = BlockerEntry.Trigger(urlFilter: Converter.URL_FILTER_SCRIPT_RULES);
        var action = BlockerEntry.Action(type: "script", script: rule.script);
        
        setWhiteList(rule: rule, action: &action);
        addDomainOptions(rule: rule, trigger: &trigger);

        return BlockerEntry(trigger: trigger, action: action);
    }
    
    private func convertScriptletRule(rule: CosmeticRule) -> BlockerEntry? {
        var trigger = BlockerEntry.Trigger(urlFilter: Converter.URL_FILTER_SCRIPTLET_RULES);
        var action = BlockerEntry.Action(type: "scriptlet", scriptlet: rule.scriptlet, scriptletParam: rule.scriptletParam);
        
        setWhiteList(rule: rule, action: &action);
        addDomainOptions(rule: rule, trigger: &trigger);

        return BlockerEntry(trigger: trigger, action: action);
    }
    
    private func convertCssRule(rule: CosmeticRule) -> BlockerEntry? {
        return nil;
    }
    
    private func setWhiteList(rule: Rule, action: inout BlockerEntry.Action) -> Void {
        if (rule.isWhiteList) {
            action.type = "ignore-previous-rules";
        }
    }
    
    private func addDomainOptions(rule: Rule, trigger: inout BlockerEntry.Trigger) -> Void {
        // TODO: addDomainOptions
//        var included = [String]();
//        var excluded = [String]();
//
//        parseDomains(rule, included, excluded);
//        resolveTopLevelDomainWildcards(included);
//        resolveTopLevelDomainWildcards(excluded);
//
//        writeDomainOptions(included, excluded, trigger);
    }
}
