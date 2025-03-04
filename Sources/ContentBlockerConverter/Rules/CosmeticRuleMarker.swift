import Foundation

/// Cosmetic rules marker enumeration
public enum CosmeticRuleMarker: String, CaseIterable {
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
        let length = ruleText.utf8.count
        let maxIndex = length - 2

        if maxIndex <= 0 {
            return (-1, nil)
        }

        // This is most likely a network rule as it starts with | or @,
        // something like ||example.org^ or @@||example.org^, so exit immediately.
        let firstChar = ruleText.utf8.first!
        if firstChar == Chars.PIPE || firstChar == Chars.AT_CHAR {
            return (-1, nil)
        }

        for i in 0...maxIndex {
            let char = ruleText.utf8[safeIndex: i]

            switch char {
            case Chars.HASH:  // #
                let nextChar = ruleText.utf8[safeIndex: i + 1]
                let twoAhead = (i + 2 < length) ? ruleText.utf8[safeIndex: i + 2] : nil
                let threeAhead = (i + 3 < length) ? ruleText.utf8[safeIndex: i + 3] : nil
                let fourAhead = (i + 4 < length) ? ruleText.utf8[safeIndex: i + 4] : nil

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
                let twoAhead = (i + 2 < length) ? ruleText.utf8[safeIndex: i + 2] : nil

                if nextChar == Chars.AT_CHAR && twoAhead == Chars.DOLLAR {
                    // $@$
                    return (i, HtmlException)
                } else if nextChar == Chars.DOLLAR {
                    return (i, Html)
                }
            default: break
            }
        }

        return (-1, nil)
    }
}
