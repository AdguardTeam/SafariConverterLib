import Foundation


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
    
    static func sortedCases() -> [CosmeticRuleMarker] {
        let allCases = CosmeticRuleMarker.allCases;
        return allCases.sorted { (left, right) -> Bool in
            return right.rawValue.count < left.rawValue.count;
        };
    }
    
    static func findCosmeticRuleMarker(ruleText: String) -> ( index: Int, marker: CosmeticRuleMarker? ) {
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
