import Foundation

/**
 * Cosmetic rule class
 */
class CosmeticRule: Rule {
    private static let EXT_CSS_PSEUDO_INDICATOR_HAS = "has"
    private static let EXT_CSS_PSEUDO_INDICATOR_IS = "is"

    /// Adblock Plus uses special prefix for their pseudo-classes.
    private static let EXT_CSS_ABP_PREFIX = "-abp-"

    /**
     * Pseudo class indicators. They are used to detect if rule is extended or not even if rule does not
     * have extended css marker
     */
    private static let EXT_CSS_PSEUDO_INDICATORS = [
        CosmeticRule.EXT_CSS_PSEUDO_INDICATOR_HAS,
        CosmeticRule.EXT_CSS_PSEUDO_INDICATOR_IS,
        "has-text",
        "contains",
        "matches-css",
        "if",
        "if-not",
        "xpath",
        "nth-ancestor",
        "upward",
        "remove",
        "matches-attr",
        "matches-property",
    ]

    private static let EXT_CSS_ATTR_INDICATOR = "[-ext-";

    private static let PATH_MODIFIER = "path="
    private static let DOMAIN_MODIFIER = "domain="

    var content: String = ""

    var scriptlet: String? = nil
    var scriptletParam: String? = nil

    var isElemhide = false
    var isExtendedCss = false
    var isInjectCss = false

    var pathModifier: String?
    var pathRegExpSource: String?

    /// Initializes a cosmetic rule by parsing its properties from the rule text.
    ///
    /// - Parameters:
    ///   - ruleText: AdGuard rule text.
    ///   - version: Safari version which will use that rule. Depending on the version some features may be available or not.
    /// - Throws: SyntaxError if any issue with the rule is detected.
    override init(ruleText: String, for version: SafariVersion = DEFAULT_SAFARI_VERSION) throws {
        try super.init(ruleText: ruleText)

        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText)
        if (markerInfo.index == -1) {
            throw SyntaxError.invalidRule(message: "Not a cosmetic rule")
        }

        let contentIndex = markerInfo.index + markerInfo.marker!.rawValue.utf8.count
        let utfContentIndex = ruleText.utf8.index(ruleText.utf8.startIndex, offsetBy: contentIndex)
        self.content = String(ruleText[utfContentIndex...])

        if (self.content == "") {
            throw SyntaxError.invalidRule(message: "Rule content is empty")
        }

        switch (markerInfo.marker!) {
        case CosmeticRuleMarker.ElementHiding,
            CosmeticRuleMarker.ElementHidingExtCSS,
            CosmeticRuleMarker.ElementHidingException,
            CosmeticRuleMarker.ElementHidingExtCSSException:
            self.isElemhide = true
        case CosmeticRuleMarker.Css,
            CosmeticRuleMarker.CssExtCSS,
            CosmeticRuleMarker.CssException,
            CosmeticRuleMarker.CssExtCSSException:
            self.isInjectCss = true
        case CosmeticRuleMarker.Js,
            CosmeticRuleMarker.JsException:
            self.isScript = true
        default:
            throw SyntaxError.invalidRule(message: "Unsupported rule type");
        }

        if (self.isScript) {
            if (self.content.hasPrefix(ScriptletParser.SCRIPTLET_MASK)) {
                self.isScriptlet = true
                let scriptletInfo = try ScriptletParser.parse(data:self.content);
                self.scriptlet = scriptletInfo.name
                self.scriptletParam = scriptletInfo.json
            }
        }

        if (markerInfo.index > 0) {
            // This means that the marker is preceded by the list of domains
            // Now it's a good time to parse them.
            let markerIndex = ruleText.utf8.index(ruleText.utf8.startIndex, offsetBy: markerInfo.index)
            let domains = String(ruleText[..<markerIndex])

            // Support for *## for generic rules
            // https://github.com/AdguardTeam/SafariConverterLib/issues/11
            if (!(domains.utf8.count == 1 && domains.utf8.first == Chars.WILDCARD)) {
                try setCosmeticRuleDomains(domains: domains)
            }
        }

        isWhiteList = CosmeticRule.isWhiteList(marker: markerInfo.marker!)
        isExtendedCss = CosmeticRule.isExtCssMarker(marker: markerInfo.marker!)
        if (!isExtendedCss && CosmeticRule.hasExtCSSIndicators(content: self.content, version: version)) {
            // Additional check if rule is extended css rule by pseudo class indicators.
            isExtendedCss = true
        }

        if isInjectCss && content.range(of: "url(") != nil {
            throw SyntaxError.invalidRule(message: "Forbidden style in a CSS rule")
        }
    }

    /// Checks if the rule contains any extended CSS pseudo-class indicators.
    private static func hasExtCSSIndicators(content: String, version: SafariVersion) -> Bool {
        // Not enough for even minimal length pseudo.
        if (content.utf8.count < 6) {
            return false
        }

        let maxIndex = content.utf8.count - 1
        var insidePseudo = false
        var pseudoStartIndex = 0

        // Going through all characters in the CSS selector and looking for CSS pseudo-classes.
        for i in 0...maxIndex {
            let char = content.utf8[safeIndex: i]

            switch char {
            case Chars.SQUARE_BRACKET_OPEN:
                if content.utf8.dropFirst(i).starts(with: CosmeticRule.EXT_CSS_ATTR_INDICATOR.utf8) {
                    return true
                }

                break
            case Chars.COLON:
                insidePseudo = true
                pseudoStartIndex = i + 1

                break
            case Chars.BRACKET_OPEN:
                if insidePseudo {
                    insidePseudo = false
                    let pseudoEndIndex = i - 1

                    if pseudoEndIndex > pseudoStartIndex {
                        let startIndex = content.utf8.index(content.utf8.startIndex, offsetBy: pseudoStartIndex)
                        let endIndex = content.utf8.index(content.utf8.startIndex, offsetBy: pseudoEndIndex)

                        let pseudo = String(content[startIndex...endIndex])

                        // the rule with `##` marker and `:has()` pseudo-class should not be considered as ExtendedCss,
                        // because `:has()` pseudo-class has native implementation since Safari 16.4
                        // https://www.webkit.org/blog/13966/webkit-features-in-safari-16-4/
                        // https://github.com/AdguardTeam/SafariConverterLib/issues/43
                        if version.isSafari16_4orGreater() && pseudo == EXT_CSS_PSEUDO_INDICATOR_HAS {
                            continue
                        }

                        // `:is()` pseudo-class has native implementation since Safari 14
                        if version.isSafari14orGreater() && pseudo == EXT_CSS_PSEUDO_INDICATOR_IS {
                            continue
                        }

                        if pseudo.utf8.starts(with: CosmeticRule.EXT_CSS_ABP_PREFIX.utf8) {
                            // This is an ext-css rule for Adblock Plus.
                            return true
                        }

                        if EXT_CSS_PSEUDO_INDICATORS.contains(pseudo) {
                            // This is a known pseudo class from AdGuard ExtendedCss library.
                            return true
                        }
                    }
                }

                break
            default:
                break
            }
        }

        return false
    }

    /// Returns true if the rule marker is for an exception rule.
    private static func isWhiteList(marker: CosmeticRuleMarker) -> Bool {
        switch (marker) {
        case CosmeticRuleMarker.ElementHidingException,
            CosmeticRuleMarker.ElementHidingExtCSSException,
            CosmeticRuleMarker.CssException,
            CosmeticRuleMarker.CssExtCSSException,
            CosmeticRuleMarker.JsException,
            CosmeticRuleMarker.HtmlException:
            return true
        default:
            return false
        }
    }

    /// Returns true if the rule is an extended CSS rule.
    private static func isExtCssMarker(marker: CosmeticRuleMarker) -> Bool {
        switch (marker) {
        case CosmeticRuleMarker.CssExtCSS,
            CosmeticRuleMarker.CssExtCSSException,
            CosmeticRuleMarker.ElementHidingExtCSS,
            CosmeticRuleMarker.ElementHidingExtCSSException:
            return true
        default:
            return false
        }
    }

    /// Parses a single cosmetic option.
    private func parseOption(name: String, value: String) throws -> Void {
        switch name {
        case "domain", "from":
            if value.isEmpty {
                throw SyntaxError.invalidModifier(message: "$domain modifier cannot be empty")
            }
            try addDomains(domainsStr: value, separator: Chars.PIPE)
        case "path":
            if value.isEmpty {
                throw SyntaxError.invalidRule(message: "$path modifier cannot be empty")
            }

            pathModifier = value
            if pathModifier!.utf8.count > 1 &&
                pathModifier!.utf8.first == Chars.SLASH &&
                pathModifier!.utf8.last == Chars.SLASH {
                // Dealing with a regex.
                let startIndex = pathModifier!.utf8.index(after: pathModifier!.utf8.startIndex)
                let endIndex = pathModifier!.utf8.index(before: pathModifier!.utf8.endIndex)

                pathRegExpSource = String(pathModifier![startIndex..<endIndex])
            } else {
                pathRegExpSource = try SimpleRegex.createRegexText(pattern: pathModifier!)
            }

            if pathRegExpSource == "" {
                throw SyntaxError.invalidModifier(message: "Empty regular expression for path")
            }

        default:
            throw SyntaxError.invalidModifier(message: "Unsupported modifier \(name)")
        }
    }

    /// Parses cosmetic rule options.
    ///
    /// The rule can look like this:
    /// [$domain=example.com,path=/test.html]example.net##example.org
    ///
    /// Learn more about this syntax here.
    /// https://adguard.com/kb/general/ad-filtering/create-own-filters/#non-basic-rules-modifiers
    ///
    /// - Returns: what's left of the domains string or nil if the rule only has cosmetic options.
    private func parseCosmeticOptions(domains: String) throws -> String? {
        let startIndex = domains.utf8.index(domains.utf8.startIndex, offsetBy: 2)
        let endIndex = domains.utf8.lastIndex(of: Chars.SQUARE_BRACKET_CLOSE)

        if domains.utf8.count < 3 ||
            domains.utf8[safeIndex: 1] != Chars.DOLLAR ||
            endIndex == nil {
            throw SyntaxError.invalidModifier(message: "Invalid cosmetic rule modifier")
        }

        let optionsString = String(domains[startIndex..<endIndex!])
        let options = optionsString.split(delimiter: Chars.COMMA, escapeChar: Chars.BACKSLASH)

        for option in options {
            var optionName = option
            var optionValue = ""

            let valueIndex = option.utf8.firstIndex(of: Chars.EQUALS_SIGN)
            if valueIndex != nil {
                optionName = String(option[..<valueIndex!])
                optionValue = String(option[option.utf8.index(after: valueIndex!)...])
            }

            try parseOption(name: optionName, value: optionValue)
        }

        // Parse what's left after the options string.
        let domainsIndex = domains.index(after: endIndex!)
        if domainsIndex < domains.endIndex {
            let domainsStr = domains[domainsIndex...]
            return String(domainsStr)
        }

        return nil
    }

    func setCosmeticRuleDomains(domains: String) throws -> Void {
        if domains.utf8.first == Chars.SQUARE_BRACKET_OPEN {
            let remainingDomains = try parseCosmeticOptions(domains: domains)
            if remainingDomains != nil && !remainingDomains!.isEmpty {
                try addDomains(domainsStr: remainingDomains!, separator: Chars.COMMA)
            }
        } else {
            try addDomains(domainsStr: domains, separator: Chars.COMMA)
        }
    }
}
