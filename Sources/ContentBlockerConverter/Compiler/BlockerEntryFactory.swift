import Foundation
import Shared

/// BlockerEntryFactory creates Safari content blocking rules from AdGuard's NetworkRule and CosmeticRule.
class BlockerEntryFactory {

    /// For the patterns that match any URL we use simplified "url-filter" instead of simply converting
    /// the pattern. The reason for that is to achieve higher performance in Safari.
    ///
    /// Otherwise, we may have complaints like the ones here:
    /// https://github.com/AdguardTeam/AdguardForiOS/issues/550
    static let ANY_URL_TEMPLATES = ["||*", "", "*", "|*"]
    static let URL_FILTER_ANY_URL = ".*"
    static let URL_FILTER_WS_ANY_URL = "^wss?:\\/\\/"
   
    /// Regular expression for cosmetic rules.
    ///
    /// Please note, that this is important to use `.*` for this kind of rules, otherwise performance is degraded:
    /// https://github.com/AdguardTeam/AdguardForiOS/issues/662
    static let URL_FILTER_COSMETIC_RULES = ".*"
    
    /// Prefix for the regular expression that we prepend to the regexp from the $path modifier.
    static let URL_FILTER_PREFIX_CSS_RULES_PATH_START_STRING = "^(https?:\\/\\/)([^\\/]+)"

    /**
     * In some cases URL_FILTER_ANY_URL doesn't work for domain-specific url exceptions
     * https://github.com/AdguardTeam/AdGuardForSafari/issues/285
     */
    private static let URL_FILTER_URL_RULES_EXCEPTIONS = ".*"

    /// Top 100 most popular TLDs according to data here:
    /// https://github.com/AdguardTeam/FiltersRegistry/blob/master/scripts/wildcard-domain-processor/wildcard_domains.json
    private static let POPULAR_TLDS = [
        "com.bd", "com.np", "com", "net", "org", "co", "de", "ru", "fr", "me",
        "it", "nl", "io", "cc", "in", "pl", "xyz", "es", "se", "co.uk",
        "tv", "pro", "info", "site", "us", "online", "ch", "at", "eu", "top",
        "be", "cz", "biz", "fi", "one", "dk", "app", "ca", "to", "vip",
        "com.br", "no", "fun", "live", "mx", "ro", "ws", "pt", "club", "sk",
        "store", "com.au", "jp", "cloud", "hu", "gr", "my", "cl", "ie", "com.tr",
        "cn", "mobi", "life", "com.mx", "dev", "icu", "asia", "com.co", "si", "co.za",
        "shop", "uk", "lt", "lv", "space", "ee", "is", "id", "com.ua", "kz",
        "work", "co.in", "tech", "co.kr", "com.ar", "blog", "pw", "co.il", "ph", "su",
        "co.nz", "rs", "ai", "website", "bg", "ua", "ma", "world", "pe", "link"
    ]

    private let advancedBlockingEnabled: Bool
    private let errorsCounter: ErrorsCounter
    private let version: SafariVersion

    /// Creates a new instance of BlockerEntryFactory.
    ///
    /// - Parameters:
    ///   - advancedBlockingEnabled: if true, advanced rules (the ones interpreted by WebExtension) are also converted.
    ///   - errorsCounter: object where we count the total number of conversion errors though the whole conversion process.
    ///   - version: version of Safari for which the rules are being built.
    init(advancedBlockingEnabled: Bool, errorsCounter: ErrorsCounter, version: SafariVersion) {
        self.advancedBlockingEnabled = advancedBlockingEnabled
        self.errorsCounter = errorsCounter
        self.version = version
    }

    /// Converts an AdGuard rule into a Safari content blocking rule.
    ///
    /// - Parameters:
    ///   - rule: AdGuard rule (either `NetworkRule` or `CosmeticRule`).
    /// - Returns: `BlockerEntry` or `nil` if the rule cannot be converted.
    func createBlockerEntry(rule: Rule) -> BlockerEntry? {
        do {
            if (rule is NetworkRule) {
                return try convertNetworkRule(rule: rule as! NetworkRule)
            } else {
                if (self.advancedBlockingEnabled) {
                    if (rule.isScriptlet) {
                        return try convertScriptletRule(rule: rule as! CosmeticRule)
                    } else if (rule.isScript) {
                        return try convertScriptRule(rule: rule as! CosmeticRule)
                    }
                }

                if (!rule.isScript && !rule.isScriptlet) {
                    return try convertCssRule(rule: rule as! CosmeticRule)
                }
            }
        } catch {
            self.errorsCounter.add()
            Logger.log("(BlockerEntryFactory) - Unexpected error: \(error) while converting \(rule.ruleText)")
        }

        return nil
    }

    /// Converts a network rule into a Safari content blocking rule.
    private func convertNetworkRule(rule: NetworkRule) throws -> BlockerEntry? {
        let urlFilter = try createUrlFilterString(rule: rule)

        var trigger = BlockerEntry.Trigger(urlFilter: urlFilter)
        var action = BlockerEntry.Action(type: "block")

        setWhiteList(rule: rule, action: &action)
        try addResourceType(rule: rule, trigger: &trigger)
        addLoadContext(rule: rule, trigger: &trigger)
        addThirdParty(rule: rule, trigger: &trigger)
        addMatchCase(rule: rule, trigger: &trigger)
        try addDomainOptions(rule: rule, trigger: &trigger)

        try updateTriggerForDocumentLevelExceptionRules(rule: rule, trigger: &trigger)

        let result = BlockerEntry(trigger: trigger, action: action)

        return result
    };

    /**
     * Creates blocker entry object from source Cosmetic script rule.
     * The result entry could be used in advanced blocking json only.
     */
    private func convertScriptRule(rule: CosmeticRule) throws -> BlockerEntry? {
        var trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_COSMETIC_RULES);
        var action = BlockerEntry.Action(type: "script", script: rule.content);

        setWhiteList(rule: rule, action: &action);
        try addDomainOptions(rule: rule, trigger: &trigger);

        return BlockerEntry(trigger: trigger, action: action);
    }

    /**
    * Creates blocker entry object from source Cosmetic scriptlet rule.
    * Scriptetlets are functions those will be inserted to page content scripts and could be accessed by name with parameters.
    * The result entry could be used in advanced blocking json only.
    */
    private func convertScriptletRule(rule: CosmeticRule) throws -> BlockerEntry? {
        var trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_COSMETIC_RULES);
        var action = BlockerEntry.Action(type: "scriptlet", scriptlet: rule.scriptlet, scriptletParam: rule.scriptletParam);

        setWhiteList(rule: rule, action: &action);
        try addDomainOptions(rule: rule, trigger: &trigger);

        return BlockerEntry(trigger: trigger, action: action);
    }

    /// Creates a blocker entry object from the source cosmetic rule.
    ///
    /// In the case the rule selector contains extended css or rule is an inject-style rule,
    /// the result entry could be used in advanced blocking json only.
    private func convertCssRule(rule: CosmeticRule) throws -> BlockerEntry? {
        let urlFilter = try createUrlFilterStringForCosmetic(rule: rule)
        var trigger = BlockerEntry.Trigger(urlFilter: urlFilter)
        var action = BlockerEntry.Action(type:"css-display-none")

        if (rule.isExtendedCss) {
            action.type = "css-extended"
            action.css = rule.content
        } else if (rule.isInjectCss) {
            action.type = "css-inject"
            action.css = rule.content
        } else {
            action.selector = rule.content
        }

        setWhiteList(rule: rule, action: &action)
        try addDomainOptions(rule: rule, trigger: &trigger)

        let result = BlockerEntry(trigger: trigger, action: action)

        return result
    }
    
    /// Builds the "url-filter" property of a Safari content blocking rule from a cosmetic rule.
    private func createUrlFilterStringForCosmetic(rule: CosmeticRule) throws -> String {
        if rule.pathRegExpSource == nil || rule.pathModifier == nil {
            return BlockerEntryFactory.URL_FILTER_COSMETIC_RULES
        }
        
        // Special treatment for $path
        let pathRegex = rule.pathRegExpSource!
        let path = rule.pathModifier!
        
        // First, validate custom regular expressions.
        if path.utf8.first == Chars.SLASH && path.utf8.last == Chars.SLASH {
            let result = SafariRegex.isSupported(pattern: pathRegex)
            
            switch result {
            case .success: break
            case .failure(let error): throw ConversionError.unsupportedRegExp(message: "Unsupported regexp in $path: \(error)")
            }
        }

        if pathRegex.utf8.first == Chars.CARET {
            // If $path regular expression starts with '^', we need to prepend a regular expression
            // that will match the beginning of the URL as we'll put the result into 'url-filter'
            // which is applied to the full URL and not just to path.
            return BlockerEntryFactory.URL_FILTER_PREFIX_CSS_RULES_PATH_START_STRING + pathRegex.dropFirst()
        }
        
        // In other cases just prepend "any URL" pattern.
        return BlockerEntryFactory.URL_FILTER_COSMETIC_RULES + pathRegex
    }

    /// Builds the "url-filter" property of a Safari content blocking rule.
    ///
    /// "url-filter" supports a limited set of regular expressions syntax.
    private func createUrlFilterString(rule: NetworkRule) throws -> String {
        let isWebSocket = rule.isWebSocket

        // Use a single standard regex for rules that are supposed to match every URL.
        for anyUrlTmpl in BlockerEntryFactory.ANY_URL_TEMPLATES {
            if rule.urlRuleText == anyUrlTmpl {
                if isWebSocket {
                    return BlockerEntryFactory.URL_FILTER_WS_ANY_URL
                }
                return BlockerEntryFactory.URL_FILTER_ANY_URL
            }
        }
        
        if rule.urlRegExpSource == nil {
            // Rule with empty regexp, matches any URL.
            return BlockerEntryFactory.URL_FILTER_ANY_URL
        }

        let urlFilter = rule.urlRegExpSource!

        // Regex that we generate for basic non-regex rules are okay.
        // But if this is a regex rule, we can't be sure.
        if rule.isRegexRule() {
            let result = SafariRegex.isSupported(pattern: urlFilter)
            
            switch result {
            case .success: break
            case .failure(let error): throw ConversionError.unsupportedRegExp(message: "Unsupported regexp rule: \(error)")
            }
        }

        // Prepending WebSocket protocol to resolve this:
        // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/957
        if (isWebSocket && !urlFilter.hasPrefix("^") && !urlFilter.hasPrefix("ws")) {
            return BlockerEntryFactory.URL_FILTER_WS_ANY_URL + ".*" + urlFilter
        }

        return urlFilter
    };

    /// Changes the rule action to "ignore-previous-rules".
    private func setWhiteList(rule: Rule, action: inout BlockerEntry.Action) -> Void {
        if (rule.isWhiteList) {
            action.type = "ignore-previous-rules";
        }
    }

    /// Adds resource type based on the content types specified in the network rule.
    ///
    /// Read more about it here:
    /// https://developer.apple.com/documentation/safariservices/creating-a-content-blocker#:~:text=if%2Ddomain.-,resource%2Dtype,-An%20array%20of
    private func addResourceType(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) throws -> Void {
        // Using String array instead of Set makes the code a bit more clunkier, but saves time.
        var types: [String] = []

        if (rule.isContentType(contentType:.all) && rule.restrictedContentType.isEmpty) {
            // Safari does not support all other default content types, like subdocument etc.
            // So we can use default safari content types instead.
            return
        }

        if rule.hasContentType(contentType: .image) {
            types.append("image")
        }

        if rule.hasContentType(contentType: .stylesheet) {
            types.append("style-sheet")
        }

        if rule.hasContentType(contentType: .script) {
            types.append("script")
        }

        if rule.hasContentType(contentType: .media) {
            types.append("media")
        }

        var rawAdded = false
        if rule.hasContentType(contentType: .xmlHttpRequest) {
            // `fetch` resource type is supported since Safari 15
            if self.version.isSafari15orGreater() {
                types.append("fetch")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: .other) {
            // `other` resource type is supported since Safari 15
            if self.version.isSafari15orGreater() {
                types.append("other")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: .websocket) {
            // `websocket` resource type is supported since Safari 15
            if self.version.isSafari15orGreater() {
                types.append("websocket")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: .font) {
            types.append("font")
        }

        if rule.hasContentType(contentType: .ping) {
            // `ping` resource type is supported since Safari 14
            if self.version.isSafari14orGreater() {
                types.append("ping")
            }
        }

        var documentAdded = false
        if !documentAdded && rule.hasContentType(contentType: .document) {
            documentAdded = true
            types.append("document")
        }

        if !documentAdded && rule.hasContentType(contentType: .subdocument) {
            if !self.version.isSafari15orGreater() {
                documentAdded = true
                types.append("document")
            }
        }

        if (rule.isBlockPopups) {
            types = ["document"]
        }

        if (types.count > 0) {
            trigger.resourceType = types
        }
    }

    /// Adds "load-context" to the content blocker action.
    ///
    /// You can read more about it in the documentation: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker#:~:text=top%2Durl.-,load%2Dcontext,-An%20array%20of
    ///
    /// We use this to apply $subdocument correctly in Safari, i.e. only apply it
    /// on the child frame level.
    private func addLoadContext(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        var context = [String]()

        // `child-frame` and `top-frame` contexts are supported since Safari 15
        if self.version.isSafari15orGreater() {
            if rule.hasContentType(contentType: .subdocument)
                && !rule.isContentType(contentType: .all) {
                context.append("child-frame")
            }
            if rule.hasRestrictedContentType(contentType: .subdocument) {
                context.append("top-frame")
            }
        }

        if context.count > 0 {
            trigger.loadContext = context
        }
    }

    /// Adds load-type property to the rule if required.
    private func addThirdParty(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        if (rule.isCheckThirdParty) {
            trigger.loadType = rule.isThirdParty ? ["third-party"] : ["first-party"]
        }
    }

    /// Makes the url-filter case sensitive if required.
    private func addMatchCase(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        if (rule.isMatchCase) {
            trigger.caseSensitive = true
        }
    }

    /// Adds domain limitations to the rule's trigger block.
    ///
    /// Domain limitations are controlled by the "if-domain" and "unless-domain" arrays.
    private func addDomainOptions(rule: Rule, trigger: inout BlockerEntry.Trigger) throws -> Void {
        let included = resolveDomains(domains: rule.permittedDomains)
        var excluded = resolveDomains(domains: rule.restrictedDomains)

        addUnlessDomainForThirdParty(rule: rule, domains: &excluded)

        if (included.count > 0 && excluded.count > 0) {
            throw ConversionError.invalidDomains(message: "Safari does not support both permitted and restricted domains")
        }

        if (included.count > 0) {
            trigger.ifDomain = included
        }

        if (excluded.count > 0) {
            trigger.unlessDomain = excluded
        }
    }

    /// Adds domain to unless-domains for third-party rules
    ///
    /// This is an attempt to fix this issue:
    /// https://github.com/AdguardTeam/AdGuardForSafari/issues/104
    ///
    /// The issue was fixed later in WebKit so we only need it for older Safari versions.
    private func addUnlessDomainForThirdParty(rule: Rule, domains: inout [String]) {
        if self.version.isSafari16_4orGreater() {
            return
        }

        if !(rule is NetworkRule) {
            return
        }

        let networkRule = rule as! NetworkRule;
        if (networkRule.isThirdParty) {
            if (networkRule.permittedDomains.count == 0) {
                let res = NetworkRuleParser.extractDomain(pattern: networkRule.urlRuleText)
                if (res.domain == "") {
                    return
                }

                // Prepend wildcard to cover subdomains.
                domains.append("*" + res.domain)
            }
        }
    }

    /// Applies additional post-processing to document-level whitelist rules ($document, $elemhide, $jsinject, $urlblock).
    ///
    /// The idea is that when such a rule targets a single domain, i.e. looks like "@@||example.org^$elemhide",
    /// it would be much better from the performance point of view to use "if-domain" instead of "url-filter".
    ///
    /// So instead of:
    /// ```
    /// {
    ///     "url-filter": "regex"
    /// }
    /// ```
    ///
    /// We will use something like this:
    ///
    /// ```
    /// {
    ///     "url-filter": ".*",
    ///     "if-domain": ["*example.org*"]
    /// }
    /// ```
    private func updateTriggerForDocumentLevelExceptionRules(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) throws -> Void {
        if (!rule.isWhiteList) {
            return
        }

        if (rule.isDocumentWhiteList || rule.isUrlBlock || rule.isCssExceptionRule || rule.isJsInject) {
            if (rule.isDocumentWhiteList) {
                // $document rules unblock everything so remove resourceType limitation.
                trigger.resourceType = nil
            }

            let ruleDomain = NetworkRuleParser.extractDomain(pattern: rule.urlRuleText)
            if ruleDomain.domain == "" || ruleDomain.patternMatchesPath {
                // Do not add if-domain limitation when the rule domain cannot be extracted
                // or when the rule is more specific than just a domain, i.e. in the case
                // of "@@||example.org/path" keep using "url-filter".
                return
            }

            rule.permittedDomains.append(ruleDomain.domain)
            try addDomainOptions(rule: rule, trigger: &trigger)

            // Note, that for some domains it is crucial to use `.*` pattern as otherwise
            // Safari fails to match the page URL.
            //
            // Here's the example:
            // https://github.com/AdguardTeam/AdGuardForSafari/issues/285
            trigger.urlFilter = BlockerEntryFactory.URL_FILTER_ANY_URL
            trigger.resourceType = nil
        }
    }
    
    /// Resolve domains prepares a list of domains to be used in the "if-domain" and "unless-domain"
    /// Safari rule properties.
    ///
    /// This includes several things.
    ///
    /// - First of all, we apply special handling for `domain.*` values. Since we cannot fully support it yet,
    ///     we replace `.*` with a list of the most popular TLD domains.
    /// - In the case of AdGuard, $domain modifier includes all subdomains. For Safari these rules should be
    ///     transformed to `*domain.com` to signal that subdomains are included.
    private func resolveDomains(domains: [String]) -> [String] {
        var result = [String]()
        
        for domain in domains {
            if domain.utf8.last == Chars.WILDCARD {
                // This is most likely a TLD domain, replace '.*' with popular TLDs.
                let prefix = domain.dropLast(2)
                for tld in BlockerEntryFactory.POPULAR_TLDS {
                    result.append("*" + prefix + "." + tld)
                }
            } else {
                // Prepend * to include subdomains.
                result.append("*" + domain)
            }
        }
        
        return result
    }

    enum ConversionError: Error {
        case unsupportedRule(message: String)
        case unsupportedRegExp(message: String)
        case invalidDomains(message: String)
    }
}
