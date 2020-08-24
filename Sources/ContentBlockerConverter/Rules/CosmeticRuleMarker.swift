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
    
    static func findCosmeticRuleMarker(ruleText: String) -> ( index: Int, marker: CosmeticRuleMarker? ) {
        for marker in CosmeticRuleMarker.allCases {
            let index = ruleText.indexOf(target: marker.rawValue);
            if (index > -1) {
                return (index, marker);
            }
        }
        
        return (-1, nil);
    }
}
