import Foundation

/**
 * Cosmetic rule class
 */
class CosmeticRule: Rule {
    /**
     * Pseudo class indicators. They are used to detect if rule is extended or not even if rule does not
     * have extended css marker
     */
    private static let EXT_CSS_PSEUDO_INDICATORS = ["[-ext-has=", "[-ext-contains=", "[-ext-has-text=",
        "[-ext-matches-css=", "[-ext-matches-css-before=", "[-ext-matches-css-after=", ":has(", ":has-text(",
        ":contains(", ":matches-css(", ":matches-css-before(", ":matches-css-after(", ":-abp-has(", ":-abp-contains(",
        ":if(", ":if-not(", ":properties(", ":-abp-properties(", ":xpath(", ":nth-ancestor(", ":upward(", ":remove("];
    
    var content: String = "";
    
    var scriptlet: String? = nil;
    var scriptletParam: String? = nil;
    
    var isElemhide = false;
    var isExtendedCss = false;
    var isInjectCss = false;
    
    override init(ruleText: NSString) throws {
        try super.init(ruleText: ruleText);
        
        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText);
        if (markerInfo.index == -1) {
            throw SyntaxError.invalidRule(message: "Not a cosmetic rule");
        }

        self.content = ruleText.substring(from: markerInfo.index + markerInfo.marker!.rawValue.count);
        if (self.content == "") {
            throw SyntaxError.invalidRule(message: "Rule content is empty");
        }
        
        switch (markerInfo.marker!) {
            case CosmeticRuleMarker.ElementHiding,
                 CosmeticRuleMarker.ElementHidingExtCSS,
                 CosmeticRuleMarker.ElementHidingException,
                 CosmeticRuleMarker.ElementHidingExtCSSException:
                self.isElemhide = true;
            case CosmeticRuleMarker.Css,
                 CosmeticRuleMarker.CssExtCSS,
                 CosmeticRuleMarker.CssException,
                 CosmeticRuleMarker.CssExtCSSException:
                self.isInjectCss = true;
            case CosmeticRuleMarker.Js,
                 CosmeticRuleMarker.JsException:
                self.isScript = true;
            default:
                throw SyntaxError.invalidRule(message: "Unsupported rule type");
        }
        
        if (self.isScript) {
            if (self.content.hasPrefix("//scriptlet")) {
                self.isScriptlet = true;
                let scriptletInfo = try! ScriptletParser.parse(data:self.content);
                self.scriptlet = scriptletInfo.name;
                self.scriptletParam = scriptletInfo.json;
            }
        }

        if (markerInfo.index > 0) {
            // This means that the marker is preceded by the list of domains
            // Now it's a good time to parse them.
            let domains = ruleText.substring(to: markerInfo.index);
            try super.setDomains(domains: domains, sep: ",");
        }

        self.isWhiteList = CosmeticRule.parseWhitelist(marker: markerInfo.marker!);
        self.isExtendedCss = CosmeticRule.isExtCssMarker(marker: markerInfo.marker!);
        if (!self.isExtendedCss) {
            // additional check if rule is extended css rule by pseudo class indicators
            if (CosmeticRule.searchCssPseudoIndicators(content: self.content)) {
                self.isExtendedCss = true;
            }
        }
    }
    
    private static func searchCssPseudoIndicators(content: String) -> Bool {
        if (!content.contains("[") && !content.contains(":")) {
            return false;
        }

        for indicator in CosmeticRule.EXT_CSS_PSEUDO_INDICATORS {
            if (content.contains(indicator)) {
                return true;
            }
        }

        return false;
    }
    
    private static func parseWhitelist(marker: CosmeticRuleMarker) -> Bool {
        switch (marker) {
            case CosmeticRuleMarker.ElementHidingException,
                 CosmeticRuleMarker.ElementHidingExtCSSException,
                 CosmeticRuleMarker.CssException,
                 CosmeticRuleMarker.CssExtCSSException,
                 CosmeticRuleMarker.JsException,
                 CosmeticRuleMarker.HtmlException:
                return true;
            default:
                return false;
        }
    }
    
    private static func isExtCssMarker(marker: CosmeticRuleMarker) -> Bool {
        switch (marker) {
            case CosmeticRuleMarker.CssExtCSS,
                 CosmeticRuleMarker.CssExtCSSException,
                 CosmeticRuleMarker.ElementHidingExtCSS,
                 CosmeticRuleMarker.ElementHidingExtCSSException:
                return true;
            default:
                return false;
        }
    }
}
