import Foundation

/// Cosmetic rules marker enumeration
public enum CosmeticRuleMarker: String, CaseIterable {
    case elementHiding = "##"
    case elementHidingException = "#@#"
    case elementHidingExtCSS = "#?#"
    case elementHidingExtCSSException = "#@?#"

    case css = "#$#"
    case cssException = "#@$#"

    case cssExtCSS = "#$?#"
    case cssExtCSSException = "#@$?#"

    case javascript = "#%#"
    case javascriptException = "#@%#"

    case html = "$$"
    case htmlException = "$@$"

    /**
     * Parses marker from string source
     */
    public static func findCosmeticRuleMarker(
        ruleText: String
    ) -> (
        index: Int, marker: CosmeticRuleMarker?
    ) {
        let length = ruleText.utf8.count
        let maxIndex = length - 2

        if maxIndex <= 0 {
            return (-1, nil)
        }

        // This is most likely a network rule as it starts with | or @,
        // something like ||example.org^ or @@||example.org^, so exit immediately.
        guard let firstChar = ruleText.utf8.first else {
            return (-1, nil)
        }

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
                            return (i, .cssException)
                        } else if threeAhead == Chars.QUESTION && fourAhead == Chars.HASH {
                            // #@$?#
                            return (i, .cssExtCSSException)
                        }
                    case Chars.QUESTION:  // #@?
                        if threeAhead == Chars.HASH {
                            // #@?#
                            return (i, .elementHidingExtCSSException)
                        }
                    case Chars.PERCENT:  // #@%
                        if threeAhead == Chars.HASH {
                            // #@%#
                            return (i, .javascriptException)
                        }
                    case Chars.HASH:  // #@#
                        return (i, .elementHidingException)
                    default: break
                    }
                case Chars.DOLLAR:  // #$
                    switch twoAhead {
                    case Chars.QUESTION:  // #$?
                        if threeAhead == Chars.HASH {
                            // #$?#
                            return (i, .cssExtCSS)
                        }
                    case Chars.HASH:
                        // #$#
                        return (i, .css)
                    default: break
                    }
                case Chars.QUESTION:  // #?
                    if twoAhead == Chars.HASH {
                        // #?#
                        return (i, .elementHidingExtCSS)
                    }
                case Chars.PERCENT:  // #%
                    if twoAhead == Chars.HASH {
                        // #%#
                        return (i, .javascript)
                    }
                case Chars.HASH:  // ##
                    return (i, .elementHiding)
                default: break
                }

            case Chars.DOLLAR:  // $
                let nextChar = ruleText.utf8[safeIndex: i + 1]
                let twoAhead = (i + 2 < length) ? ruleText.utf8[safeIndex: i + 2] : nil

                if nextChar == Chars.AT_CHAR && twoAhead == Chars.DOLLAR {
                    // $@$
                    return (i, .htmlException)
                } else if nextChar == Chars.DOLLAR {
                    return (i, .html)
                }
            default: break
            }
        }

        return (-1, nil)
    }
}
