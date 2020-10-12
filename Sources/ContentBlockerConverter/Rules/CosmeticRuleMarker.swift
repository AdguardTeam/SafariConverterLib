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
    static func findCosmeticRuleMarker(ruleText: String) -> ( index: Int, marker: CosmeticRuleMarker? ) {
        if (!ruleText.contains("#") && !ruleText.contains("$")) {
            return (-1, nil);
        }

        let arr = Array(ruleText)
        let maxIndex = arr.count-1
        for i in 0...maxIndex {
            let char = arr[i]
            switch char {
                case "#":
                    if i + 4 <= maxIndex {
                        if arr[i + 1] == "@" && arr[i + 2] == "$" && arr[i + 3] == "?" && arr[i + 4] == "#"{
                            return (i, CssExtCSSException);
                        }
                    }

                    if i + 3 <= maxIndex {
                        if arr[i + 1] == "@" && arr[i + 2] == "?" && arr[i + 3] == "#"{
                            return (i, ElementHidingExtCSSException);
                        }

                        if arr[i + 1] == "@" && arr[i + 2] == "$" && arr[i + 3] == "#"{
                            return (i, CssException);
                        }

                        if arr[i + 1] == "@" && arr[i + 2] == "%" && arr[i + 3] == "#"{
                            return (i, JsException);
                        }

                        if arr[i + 1] == "$" && arr[i + 2] == "?" && arr[i + 3] == "#"{
                            return (i, CssExtCSS);
                        }
                    }

                    if i + 2 <= maxIndex {
                        if arr[i + 1] == "@" && arr[i + 2] == "#" {
                            return (i, ElementHidingException);
                        }

                        if arr[i + 1] == "?" && arr[i + 2] == "#" {
                            return (i, ElementHidingExtCSS);
                        }

                        if arr[i + 1] == "%" && arr[i + 2] == "#" {
                            return (i, Js);
                        }

                        if arr[i + 1] == "$" && arr[i + 2] == "#" {
                            return (i, Css);
                        }
                    }

                    if i + 1 <= maxIndex {
                        if arr[i + 1] == "#" {
                            return (i, ElementHiding);
                        }
                    }
                case "$":
                    if i + 2 <= maxIndex {
                        if arr[i + 1] == "@" && arr[i + 2] == "$" {
                            return (i, HtmlException);
                        }
                    }

                    if i + 1 <= maxIndex {
                        if arr[i + 1] == "$" {
                            return (i, Html);
                        }
                    }
                default: break
            }
        }

        return (-1, nil);
    }
}
