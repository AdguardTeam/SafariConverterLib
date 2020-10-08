import Foundation

/**
 * Cosmetic rules marker enumeration
 */
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
    
    private static var sorted: [CosmeticRuleMarker]? = nil;

    private static func sortedCases() -> [CosmeticRuleMarker] {
        if (self.sorted == nil) {
            let allCases = CosmeticRuleMarker.allCases;
            self.sorted = allCases.sorted { (left, right) -> Bool in
                return right.rawValue.count < left.rawValue.count;
            };
        }
        
        return self.sorted!;
    }
    
    /**
     * Parses marker from string source
     */
    static func findCosmeticRuleMarker(ruleText: String) -> ( index: Int, marker: CosmeticRuleMarker? ) {
        if (!ruleText.contains("#") && !ruleText.contains("$")) {
            return (-1, nil);
        }
        
        let sortedCases = CosmeticRuleMarker.sortedCases();
        for marker in sortedCases {
            let index = ruleText.indexOf(target: marker.rawValue);
            if (index > -1) {
                return (index, marker);
            }
        }

        return (-1, nil);
    }
}
