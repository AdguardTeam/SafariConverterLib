import Foundation

class RuleFactory {
    
    private static let converter = RuleConverter();
    
    // Parses rules from lines
    static func createRules(lines: [String]) -> [Rule] {
        var result = [Rule]();
        for line in lines {
            let convertedLines = converter.convertRule(rule: line);
            for convertedLine in convertedLines {
                let rule = createRule(ruleText: convertedLine);
                if (rule != nil) {
                    result.append(rule!);
                } else {
                    // NSLog("AG: ContentBlockerConverter: Unexpected error");
                }
            }
        }
        
        return applyBadFilterExceptions(rules: result);
    }
    
    static func applyBadFilterExceptions(rules: [Rule]) -> [Rule] {
        // TODO: Apply badfilter exceptions
        return rules;
    }
    
    static func createRule(ruleText: String?) -> Rule? {
        if (ruleText == nil || ruleText! == "" || ruleText!.hasPrefix("!") || ruleText!.hasPrefix(" ") || ruleText!.indexOf(target: " - ") > 0) {
            return nil;
        }
        
        if (ruleText!.count < 3) {
            return nil;
        }

        if (RuleFactory.isCosmetic(ruleText: ruleText!)) {
            return CosmeticRule(ruleText: ruleText!);
        }

    
        return NetworkRule(ruleText: ruleText!);
    };
    
    private static func isCosmetic(ruleText: String) -> Bool {
        let marker = findCosmeticRuleMarker(ruleText: ruleText);
        return marker != nil;
    }
    
    private static func findCosmeticRuleMarker(ruleText: String) -> CosmeticRuleMarker? {
        for marker in CosmeticRuleMarker.allCases {
            if (ruleText.indexOf(target: marker.rawValue) > -1) {
                return marker;
            }
        }
        
        return nil;
    }
    
    enum CosmeticRuleMarker: String, CaseIterable {
        case ElementHiding = "##"
        case ElementHidingException = "#@#"
        case ElementHidingExtCSS = "#?#"
        case ElementHidingExtCSSException = "#@?#"

        case Css = "#$#"
        case CssException = "#@$#"
        
        case CssExtCSS = "#$?#"
        case CssExtCSSException = "#@$?#"

        case Js = "#%#"
        case JsException = "#@%#"

        case Html = "$$"
        case HtmlException = "$@$"
    }
}
