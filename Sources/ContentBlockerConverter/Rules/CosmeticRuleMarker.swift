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
    
    /**
     * Parses marker from string source
     */
    static func findCosmeticRuleMarker(ruleText: NSString) -> ( index: Int, marker: CosmeticRuleMarker? ) {
        let hash: unichar = "#".utf16.first!;
        let atChar: unichar = "@".utf16.first!;
        let dollar: unichar = "$".utf16.first!;
        let percent: unichar = "%".utf16.first!;
        let question: unichar = "?".utf16.first!;
        
        let maxIndex = ruleText.length-1
        for i in 0...maxIndex {
            let char = ruleText.character(at: i);
            switch char {
                case hash:
                    if i + 4 <= maxIndex {
                        if ruleText.character(at: i + 1) == atChar
                            && ruleText.character(at: i + 2) == dollar
                            && ruleText.character(at: i + 3) == question
                            && ruleText.character(at: i + 4) == hash {
                            return (i, CssExtCSSException);
                        }
                    }

                    if i + 3 <= maxIndex {
                        if ruleText.character(at: i + 1) == atChar
                            && ruleText.character(at: i + 2) == question && ruleText.character(at: i + 3) == hash {
                            return (i, ElementHidingExtCSSException);
                        }

                        if ruleText.character(at: i + 1) == atChar
                            && ruleText.character(at: i + 2) == dollar && ruleText.character(at: i + 3) == hash {
                            return (i, CssException);
                        }

                        if ruleText.character(at: i + 1) == atChar
                            && ruleText.character(at: i + 2) == percent && ruleText.character(at: i + 3) == hash {
                            return (i, JsException);
                        }

                        if ruleText.character(at: i + 1) == dollar
                            && ruleText.character(at: i + 2) == question && ruleText.character(at: i + 3) == hash {
                            return (i, CssExtCSS);
                        }
                    }

                    if i + 2 <= maxIndex {
                        if ruleText.character(at: i + 1) == atChar && ruleText.character(at: i + 2) == hash {
                            return (i, ElementHidingException);
                        }

                        if ruleText.character(at: i + 1) == question && ruleText.character(at: i + 2) == hash {
                            return (i, ElementHidingExtCSS);
                        }

                        if ruleText.character(at: i + 1) == percent && ruleText.character(at: i + 2) == hash {
                            return (i, Js);
                        }

                        if ruleText.character(at: i + 1) == dollar && ruleText.character(at: i + 2) == hash {
                            return (i, Css);
                        }
                    }

                    if i + 1 <= maxIndex {
                        if ruleText.character(at: i + 1) == hash {
                            return (i, ElementHiding);
                        }
                    }
                case dollar:
                    if i + 2 <= maxIndex {
                        if ruleText.character(at: i + 1) == atChar && ruleText.character(at: i + 2) == dollar {
                            return (i, HtmlException);
                        }
                    }

                    if i + 1 <= maxIndex {
                        if ruleText.character(at: i + 1) == dollar {
                            return (i, Html);
                        }
                    }
                default: break
            }
        }

        return (-1, nil);
    }
}
