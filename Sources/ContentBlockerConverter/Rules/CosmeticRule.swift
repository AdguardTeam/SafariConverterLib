import Foundation

/// Cosmetic rule class.
public class CosmeticRule: Rule {
    private static let EXT_CSS_PSEUDO_INDICATOR_HAS = "has"
    private static let EXT_CSS_PSEUDO_INDICATOR_IS = "is"

    /// Pseudo class indicators. They are used to detect if rule is extended or
    /// not even if rule does not have extended css marker.
    ///
    /// For instance, a rule like `##banner:contains(text)` will be considered
    /// extended CSS rule and it should be interpreted by the extension.
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

    /// Extended CSS attribute indicator. This is a backwards-compatible way
    /// of specifying extended CSS rules, i.e. instead of `##banner:has(#id)`
    /// we can specify `##banner[-ext-has="#id"]`.
    private static let EXT_CSS_ATTR_INDICATOR = "[-ext-"

    /// Adblock Plus uses special prefix for their pseudo-classes.
    ///
    /// For instance, instead of `##div:contains(smth)` they will have
    /// something like `##div:-abp-contains(smth)`.
    private static let EXT_CSS_ABP_PREFIX = "-abp-"

    /// Content depends on the rule type.
    ///
    /// - CSS selector for element hiding rules or CSS selector + style for CSS injection rules.
    /// - Script contents for script and scriptlet rules.
    public var content: String = ""

    /// If true, this is an element hiding rule.
    public var isElemhide = false

    // If true, this is CSS injection rule.
    public var isInjectCss = false

    /// If true, this is an extended CSS rule (can be eiter element hiding or CSS injection).
    public var isExtendedCss = false

    /// If true, this is a script rule or scriptlet.
    public var isScript = false

    /// If true, this is a scriptlet rule.
    public var isScriptlet = false

    /// Value of the `$path` modifier.
    public var pathModifier: String?

    /// `$path` value converted to regular expression.
    public var pathRegExpSource: String?

    /// Initializes a cosmetic rule by parsing its properties from the rule text.
    ///
    /// - Parameters:
    ///   - ruleText: AdGuard rule text.
    ///   - version: Safari version which will use that rule. Depending on the
    ///              version some features may be available or not.
    /// - Throws: SyntaxError if any issue with the rule is detected.
    public override init(
        ruleText: String,
        for version: SafariVersion = SafariVersion.autodetect()
    ) throws {
        try super.init(ruleText: ruleText)

        let markerInfo = CosmeticRuleMarker.findCosmeticRuleMarker(ruleText: ruleText)
        if markerInfo.index == -1 {
            throw SyntaxError.invalidRule(message: "Not a cosmetic rule")
        }

        guard let marker = markerInfo.marker else {
            throw SyntaxError.invalidRule(message: "Invalid cosmetic rule marker")
        }

        let contentIndex = markerInfo.index + marker.rawValue.utf8.count
        let utfContentIndex = ruleText.utf8.index(ruleText.utf8.startIndex, offsetBy: contentIndex)
        self.content = String(ruleText[utfContentIndex...])

        if self.content.isEmpty {
            throw SyntaxError.invalidRule(message: "Rule content is empty")
        }

        switch marker {
        case .elementHiding,
            .elementHidingExtCSS,
            .elementHidingException,
            .elementHidingExtCSSException:
            self.isElemhide = true
        case .css,
            .cssExtCSS,
            .cssException,
            .cssExtCSSException:
            self.isInjectCss = true
        case .javascript,
            .javascriptException:
            self.isScript = true
        default:
            throw SyntaxError.invalidRule(message: "Unsupported rule type")
        }

        if self.isScript {
            if ScriptletParser.isScriptlet(cosmeticRuleContent: self.content) {
                self.isScriptlet = true
            }
        }

        if markerInfo.index > 0 {
            // This means that the marker is preceded by the list of domains
            // Now it's a good time to parse them.
            let markerIndex = ruleText.utf8.index(
                ruleText.utf8.startIndex,
                offsetBy: markerInfo.index
            )
            let domains = String(ruleText[..<markerIndex])

            // Support for *## for generic rules
            // https://github.com/AdguardTeam/SafariConverterLib/issues/11
            if !(domains.utf8.count == 1 && domains.utf8.first == Chars.WILDCARD) {
                try setCosmeticRuleDomains(domains: domains)
            }
        }

        isWhiteList = CosmeticRule.isWhiteList(marker: marker)
        isExtendedCss = CosmeticRule.isExtCssMarker(marker: marker)

        if !isExtendedCss
            && CosmeticRule.hasExtCSSIndicators(content: self.content, version: version)
        {
            // Additional check if rule is extended css rule by pseudo class indicators.
            isExtendedCss = true
        }

        if isInjectCss && content.range(of: "url(") != nil {
            throw SyntaxError.invalidRule(message: "Forbidden style in a CSS rule")
        }

        if isWhiteList && pathModifier != nil {
            throw SyntaxError.invalidRule(
                message: "CSS exception rules with $path modifier are not supported"
            )
        }
    }

    /// Checks if the rule contains any extended CSS pseudo-class indicators.
    private static func hasExtCSSIndicators(content: String, version: SafariVersion) -> Bool {
        // Not enough for even minimal length pseudo.
        if content.utf8.count < 6 {
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
                if content.utf8.dropFirst(i).starts(with: CosmeticRule.EXT_CSS_ATTR_INDICATOR.utf8)
                {
                    return true
                }
            case Chars.COLON:
                insidePseudo = true
                pseudoStartIndex = i + 1
            case Chars.BRACKET_OPEN:
                if insidePseudo {
                    insidePseudo = false
                    let pseudoEndIndex = i - 1

                    if pseudoEndIndex > pseudoStartIndex {
                        let startIndex = content.utf8.index(
                            content.utf8.startIndex,
                            offsetBy: pseudoStartIndex
                        )
                        let endIndex = content.utf8.index(
                            content.utf8.startIndex,
                            offsetBy: pseudoEndIndex
                        )

                        let pseudo = String(content[startIndex...endIndex])

                        // the rule with `##` marker and `:has()` pseudo-class should not be considered as ExtendedCss,
                        // because `:has()` pseudo-class has native implementation since Safari 16.4
                        // https://www.webkit.org/blog/13966/webkit-features-in-safari-16-4/
                        // https://github.com/AdguardTeam/SafariConverterLib/issues/43
                        if version.isSafari16_4orGreater() && pseudo == EXT_CSS_PSEUDO_INDICATOR_HAS
                        {
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
            default:
                break
            }
        }

        return false
    }

    /// Returns true if the rule marker is for an exception rule.
    private static func isWhiteList(marker: CosmeticRuleMarker) -> Bool {
        switch marker {
        case .elementHidingException,
            .elementHidingExtCSSException,
            .cssException,
            .cssExtCSSException,
            .javascriptException,
            .htmlException:
            return true
        default:
            return false
        }
    }

    /// Returns true if the rule is an extended CSS rule.
    private static func isExtCssMarker(marker: CosmeticRuleMarker) -> Bool {
        switch marker {
        case .cssExtCSS,
            .cssExtCSSException,
            .elementHidingExtCSS,
            .elementHidingExtCSSException:
            return true
        default:
            return false
        }
    }

    /// Parses a single cosmetic option.
    private func parseOption(name: String, value: String) throws {
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

            guard let pathMod = pathModifier else {
                throw SyntaxError.invalidModifier(message: "Path modifier is nil")
            }

            if let regex = SimpleRegex.extractRegex(pathMod) {
                pathRegExpSource = regex
            } else {
                pathRegExpSource = try SimpleRegex.createRegexText(pattern: pathMod)
            }

            guard let regExpSource = pathRegExpSource, !regExpSource.isEmpty else {
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
        guard let endIndex = domains.utf8.lastIndex(of: Chars.SQUARE_BRACKET_CLOSE) else {
            throw SyntaxError.invalidModifier(message: "Invalid option format")
        }

        if domains.utf8.count < 3 || domains.utf8[safeIndex: 1] != Chars.DOLLAR {
            throw SyntaxError.invalidModifier(message: "Invalid cosmetic rule modifier")
        }

        let optionsString = String(domains[startIndex..<endIndex])
        let options = optionsString.split(delimiter: Chars.COMMA, escapeChar: Chars.BACKSLASH)

        for option in options {
            var optionName = option
            var optionValue = ""

            if let valueIndex = option.utf8.firstIndex(of: Chars.EQUALS_SIGN) {
                optionName = String(option[..<valueIndex])
                optionValue = String(option[option.utf8.index(after: valueIndex)...])
            }

            try parseOption(name: optionName, value: optionValue)
        }

        // Parse what's left after the options string.
        let domainsIndex = domains.index(after: endIndex)
        if domainsIndex < domains.endIndex {
            let domainsStr = domains[domainsIndex...]
            return String(domainsStr)
        }

        return nil
    }

    func setCosmeticRuleDomains(domains: String) throws {
        if domains.utf8.first == Chars.SQUARE_BRACKET_OPEN {
            if let remainingDomains = try parseCosmeticOptions(domains: domains),
                !remainingDomains.isEmpty
            {
                try addDomains(domainsStr: remainingDomains, separator: Chars.COMMA)
            }
        } else {
            try addDomains(domainsStr: domains, separator: Chars.COMMA)
        }
    }
}
