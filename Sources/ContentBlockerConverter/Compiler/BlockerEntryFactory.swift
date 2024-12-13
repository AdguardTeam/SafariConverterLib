import Foundation
import Shared

/**
 * Blocker entries factory class
 */
class BlockerEntryFactory {
    /**
     * It's important to mention why do we need these regular expressions.
     * The thing is that on iOS it is crucial to use regexes as simple as possible.
     * Otherwise, Safari takes too much memory on compiling a content blocker, and iOS simply kills the process.
     *
     * Angry users are here:
     * https://github.com/AdguardTeam/AdguardForiOS/issues/550
     */
    static let ANY_URL_TEMPLATES = ["||*", "", "*", "|*"]
    static let URL_FILTER_ANY_URL = ".*"
    static let URL_FILTER_WS_ANY_URL = "^wss?:\\/\\/"

    /**
     * Using .* for the css-display-none rules trigger.url-filter.
     * Please note, that this is important to use ".*" for this kind of rules, otherwise performance is degraded:
     * https://github.com/AdguardTeam/AdguardForiOS/issues/662
     */
    static let URL_FILTER_CSS_RULES = ".*"
    static let URL_FILTER_SCRIPT_RULES = ".*"
    static let URL_FILTER_SCRIPTLET_RULES = ".*"
    
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

    private static let REGEXP_SLASH = "/"

    let advancedBlockingEnabled: Bool
    let errorsCounter: ErrorsCounter

    init(advancedBlockingEnabled: Bool, errorsCounter: ErrorsCounter) {
        self.advancedBlockingEnabled = advancedBlockingEnabled
        self.errorsCounter = errorsCounter
    }

    /// Converts an AdGuard rule into a Safari content blocking rule.
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

        try checkWhiteListExceptions(rule: rule, trigger: &trigger)

        let result = BlockerEntry(trigger: trigger, action: action)
        try validateUrlBlockingRule(rule: rule, entry: result)

        return result
    };

    /**
     * Creates blocker entry object from source Cosmetic script rule.
     * The result entry could be used in advanced blocking json only.
     */
    private func convertScriptRule(rule: CosmeticRule) throws -> BlockerEntry? {
        var trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_SCRIPT_RULES);
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
        var trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_SCRIPTLET_RULES);
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
        return BlockerEntryFactory.URL_FILTER_CSS_RULES + pathRegex
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

        if (rule.isContentType(contentType:NetworkRule.ContentType.ALL) && rule.restrictedContentType.count == 0) {
            // Safari does not support all other default content types, like subdocument etc.
            // So we can use default safari content types instead.
            return
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.IMAGE) {
            types.append("image")
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.STYLESHEET) {
            types.append("style-sheet")
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.SCRIPT) {
            types.append("script")
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.MEDIA) {
            types.append("media")
        }

        var rawAdded = false
        if rule.hasContentType(contentType: NetworkRule.ContentType.XMLHTTPREQUEST) {
            // `fetch` resource type is supported since Safari 15
            if SafariService.current.version.isSafari15orGreater() {
                types.append("fetch")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.OTHER) {
            // `other` resource type is supported since Safari 15
            if SafariService.current.version.isSafari15orGreater() {
                types.append("other")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.WEBSOCKET) {
            // `websocket` resource type is supported since Safari 15
            if SafariService.current.version.isSafari15orGreater() {
                types.append("websocket")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.FONT) {
            types.append("font")
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.PING) {
            // `ping` resource type is supported since Safari 14
            if SafariService.current.version.isSafari14orGreater() {
                types.append("ping")
            }
        }

        var documentAdded = false
        if !documentAdded && rule.hasContentType(contentType: NetworkRule.ContentType.DOCUMENT) {
            documentAdded = true
            types.append("document")
        }

        if !documentAdded && rule.hasContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT) {
            if !SafariService.current.version.isSafari15orGreater() {
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
        if SafariService.current.version.isSafari15orGreater() {
            if rule.hasContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT)
                && !rule.isContentType(contentType:NetworkRule.ContentType.ALL) {
                context.append("child-frame")
            }
            if rule.hasRestrictedContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT) {
                context.append("top-frame")
            }
        }

        if context.count > 0 {
            trigger.loadContext = context
        }
    }

    private func addThirdParty(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        if (rule.isCheckThirdParty) {
            trigger.loadType = rule.isThirdParty ? ["third-party"] : ["first-party"]
        }
    }

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
        if SafariService.current.version.isSafari16_4orGreater() {
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

    // TODO(ameshkov): !!! Add normal comment here.
    private func checkWhiteListExceptions(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) throws -> Void {
        if (!rule.isWhiteList) {
            return
        }

        if (rule.isDocumentWhiteList || rule.isUrlBlock || rule.isCssExceptionRule || rule.isJsInject) {
            if (rule.isDocumentWhiteList) {
                trigger.resourceType = nil
            }

            let ruleDomain = NetworkRuleParser.extractDomain(pattern: rule.urlRuleText)
            if ruleDomain.domain == "" || ruleDomain.patternMatchesPath {
                // Do not add exceptions when the rule does not target any domain.
                // TODO(ameshkov): !!! Add test for that.
                return
            }

            // TODO(ameshkov): !!! Bad pattern, modifies state
            rule.permittedDomains.append(ruleDomain.domain)
            try addDomainOptions(rule: rule, trigger: &trigger)

            trigger.urlFilter = BlockerEntryFactory.URL_FILTER_URL_RULES_EXCEPTIONS
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

    private func validateUrlBlockingRule(rule: NetworkRule, entry: BlockerEntry) throws -> Void {
        if rule.hasContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT)
                && !rule.isContentType(contentType:NetworkRule.ContentType.ALL) {
            if (entry.action.type == "block" &&
                entry.trigger.resourceType?.firstIndex(of: "document") != nil &&
                entry.trigger.ifDomain == nil &&
                entry.trigger.loadType?.firstIndex(of: "third-party") == nil) {

                // TODO(ameshkov): !!! This limitation looks wrong and can be lifted for newer Safari versions

                // Due to https://github.com/AdguardTeam/AdguardBrowserExtension/issues/145
                throw ConversionError.unsupportedContentType(message: "Subdocument blocking rules are allowed only along with third-party or if-domain modifiers")
            }
        }

        // TODO(ameshkov): !!! What? Where would it get here?
        if (entry.trigger.resourceType?.firstIndex(of: "popup") != nil) {
            throw ConversionError.unsupportedRule(message: "$popup rules are not supported")
        }
    }

    enum ConversionError: Error {
        case unsupportedRule(message: String)
        case unsupportedRegExp(message: String)
        case unsupportedContentType(message: String)
        case invalidDomains(message: String)
    }
}
