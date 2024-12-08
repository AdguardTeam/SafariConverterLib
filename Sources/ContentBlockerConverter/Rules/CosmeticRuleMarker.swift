import Foundation

/// Cosmetic rules marker enumeration
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
    public static func findCosmeticRuleMarker(ruleText: String) -> (
        index: Int, marker: CosmeticRuleMarker?
    ) {
        let maxIndex = ruleText.utf8.count - 5
        for i in 0...maxIndex {
            let char = ruleText.utf8[safeIndex: i]
            
            // This is most likely a network rule as it starts with |,
            // something like ||example.org^, so exit immediately.
            if i == 0 && char == Chars.PIPE {
                return (-1, nil)
            }
            
            switch char {
            case Chars.HASH:  // #
                let nextChar = ruleText.utf8[safeIndex: i + 1]
                let twoAhead = ruleText.utf8[safeIndex: i + 2]
                let threeAhead = ruleText.utf8[safeIndex: i + 3]
                let fourAhead = ruleText.utf8[safeIndex: i + 4]
                
                switch nextChar {
                case Chars.AT_CHAR:  // #@
                    switch twoAhead {
                    case Chars.DOLLAR:  // #@$
                        if threeAhead == Chars.HASH {
                            // #@$#
                            return (i, CssException)
                        } else if threeAhead == Chars.QUESTION && fourAhead == Chars.HASH {
                            // #@$?#
                            return (i, CssExtCSSException)
                        }
                    case Chars.QUESTION:  // #@?
                        if threeAhead == Chars.HASH {
                            // #@?#
                            return (i, ElementHidingExtCSSException)
                        }
                    case Chars.PERCENT:  // #@%
                        if threeAhead == Chars.HASH {
                            // #@%#
                            return (i, JsException)
                        }
                    case Chars.HASH:  // #@#
                        return (i, ElementHidingException)
                    default: break
                    }
                case Chars.DOLLAR:  // #$
                    switch twoAhead {
                    case Chars.QUESTION:  // #$?
                        if threeAhead == Chars.HASH {
                            // #$?#
                            return (i, CssExtCSS)
                        }
                    case Chars.HASH:
                        // #$#
                        return (i, Css)
                    default: break
                    }
                case Chars.QUESTION:  // #?
                    if twoAhead == Chars.HASH {
                        // #?#
                        return (i, ElementHidingExtCSS)
                    }
                case Chars.PERCENT:  // #%
                    if twoAhead == Chars.HASH {
                        // #%#
                        return (i, Js)
                    }
                case Chars.HASH:  // ##
                    return (i, ElementHiding)
                default: break
                }
                
            case Chars.DOLLAR: // $
                let nextChar = ruleText.utf8[safeIndex: i + 1]
                let twoAhead = ruleText.utf8[safeIndex: i + 2]
                
                if nextChar == Chars.AT_CHAR && twoAhead == Chars.DOLLAR {
                    // $@$
                    return (i, HtmlException)
                } else if (nextChar == Chars.DOLLAR) {
                    return (i, Html)
                }
            default: break
            }
        }
        
        return (-1, nil)
    }
}
