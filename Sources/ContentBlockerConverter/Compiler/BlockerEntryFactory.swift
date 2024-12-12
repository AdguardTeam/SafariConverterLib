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
    static let ANY_URL_TEMPLATES = ["||*", "", "*", "|*"];
    static let URL_FILTER_ANY_URL = "^[htpsw]+:\\/\\/";
    static let URL_FILTER_WS_ANY_URL = "^wss?:\\/\\/";

    /**
     * Using .* for the css-display-none rules trigger.url-filter.
     * Please note, that this is important to use ".*" for this kind of rules, otherwise performance is degraded:
     * https://github.com/AdguardTeam/AdguardForiOS/issues/662
     */
    static let URL_FILTER_CSS_RULES = ".*";
    static let URL_FILTER_SCRIPT_RULES = ".*";
    static let URL_FILTER_SCRIPTLET_RULES = ".*";

    /**
     * url-filter prefix for path modifier of css rule starting from start of string symbol (^)
     */
    static let URL_FILTER_PREFIX_CSS_RULES_PATH_START_STRING = "^(https?:\\/\\/)([^\\/]+)";
    static let START_OF_STRING = "^";

    /**
     * In some cases URL_FILTER_ANY_URL doesn't work for domain-specific url exceptions
     * https://github.com/AdguardTeam/AdGuardForSafari/issues/285
     */
    static let URL_FILTER_URL_RULES_EXCEPTIONS = ".*";

    /**
     * Popular top level domains list
     */
    static let TOP_LEVEL_DOMAINS_LIST = [
        "com", "ru", "net", "org", "ir", "in", "com.au", "com.tr", "co.uk", "io", "co", "gr", "ca", "com.ua", "vn", "info", "de", "fr", "me", "by", "jp",
        "xyz", "ua", "com.tw", "co.za", "co.il", "online", "eu", "it", "tv", "id", "xn--p1ai", "edu", "com.br", "es", "ch", "co.in", "kz", "com.vn", "biz",
        "app", "co.id", "nl", "pro", "us", "pl", "cl", "com.mx", "ro", "club", "co.jp", "co.nz", "ma", "com.ar", "su", "site", "cc", "rs", "cn", "ae", "co.kr",
        "mx", "pk", "se", "gov.in", "com.my", "cz", "shop", "lk", "live", "tw", "ai", "com.sg", "top", "gov", "ac.id", "com.co", "co.th", "ac.in", "be",
        "in.ua", "store", "org.ua", "org.tr", "dk", "hu", "az", "gov.ua", "edu.vn", "am", "uz", "com.pk", "news", "md", "tech", "nic.in", "go.id", "com.hk",
        "ge", "com.cn", "ac.ir", "sg", "org.uk", "my", "no", "go.th", "pw", "com.bd", "to", "gov.tr", "dev", "kiev.ua", "mk", "com.ng", "ie", "asia", "at",
        "co.ke", "com.np", "ph", "sch.id", "fi", "tk", "lv", "space", "life", "pe", "sk", "ng", "lt", "tn", "hk", "link", "vip", "cloud", "gov.bd", "website",
        "kr", "sa", "media", "edu.in", "pt", "gg", "blog", "com.ph", "hr", "mobi", "org.au", "fun", "bg", "com.sa", "ac.th", "mn", "ws", "ee", "one", "uk",
        "kg", "ba", "com.pe", "al", "today", "fm", "ml", "edu.tr", "bel.tr", "ac.uk", "net.ua", "dz", "win", "org.tw", "gov.co", "guru", "org.il", "edu.pk",
        "world", "gov.vn", "is", "com.uy", "gov.np", "gob.mx", "or.id", "gov.my", "edu.co", "si", "in.th", "gen.tr", "network", "org.in", "ga", "digital",
        "edu.au", "web.id", "work", "best", "agency", "edu.ua", "net.au", "icu", "sh"
    ];

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

    /**
    * Creates blocker entry object from source Cosmetic script rule.
    * In case the rule selector contains extended css or rule is an inject-style rule, then the result entry could be used in advanced blocking json only.
    */
    private func convertCssRule(rule: CosmeticRule) throws -> BlockerEntry? {
        var trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_CSS_RULES)

        if rule.pathModifier != nil {
            var pathRegex: String
            
            // TODO(ameshkov): !!! Change this.
            if rule.pathModifier!.hasPrefix(BlockerEntryFactory.REGEXP_SLASH) && rule.pathModifier!.hasSuffix(BlockerEntryFactory.REGEXP_SLASH) {
                pathRegex = String(String(rule.pathModifier!.dropFirst()).dropLast())

                let result = SafariRegex.isSupported(pattern: pathRegex)
                switch result {
                case .success: break
                case .failure(let error): throw ConversionError.unsupportedRegExp(message: "Unsupported regexp in $path: \(error.localizedDescription)")
                }
            } else {
                pathRegex = SimpleRegex2.createRegexText(str: rule.pathModifier!)
            }

            if pathRegex.starts(with: BlockerEntryFactory.START_OF_STRING) {
                // if path modifier starts from start of string symbol,
                // remove start of string symbol and add prefix to match path right after domain
                pathRegex = String(pathRegex.dropFirst())
                trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_PREFIX_CSS_RULES_PATH_START_STRING + pathRegex)
            } else {
                trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_CSS_RULES + pathRegex)
            }
        }

        var action = BlockerEntry.Action(type:"css-display-none");

        if (rule.isExtendedCss) {
            action.type = "css-extended";
            action.css = rule.content;
        } else if (rule.isInjectCss) {
            action.type = "css-inject";
            action.css = rule.content;
        } else {
            action.selector = rule.content;
        }

        setWhiteList(rule: rule, action: &action);
        try addDomainOptions(rule: rule, trigger: &trigger);

        let result = BlockerEntry(trigger: trigger, action: action)
        try validateCssFilterRule(entry: result);

        return result;
    }

    /// Builds the "url-filter" property of a Safari content blocking rule.
    ///
    /// "url-filter" supports a limited set of regular expressions syntax.
    private func createUrlFilterString(rule: NetworkRule) throws -> String {
        let isWebSocket = rule.isWebSocket

        // Use a single standard regex for rules that are supposed to match every URL
        for anyUrlTmpl in BlockerEntryFactory.ANY_URL_TEMPLATES {
            if rule.urlRuleText == anyUrlTmpl {
                if isWebSocket {
                    return BlockerEntryFactory.URL_FILTER_WS_ANY_URL
                }
                return BlockerEntryFactory.URL_FILTER_ANY_URL
            }
        }

        let urlRegExpSource = rule.urlRegExpSource
        if (urlRegExpSource == nil) {
            // Rule with empty regexp, matches any URL.
            return BlockerEntryFactory.URL_FILTER_ANY_URL
        }

        // Regex that we generate for basic non-regex rules are okay.
        // But if this is a regex rule, we can't be sure.
        if rule.isRegexRule() {
            let result = SafariRegex.isSupported(pattern: urlRegExpSource!)
            
            switch result {
            case .success: break
            case .failure(let error): throw ConversionError.unsupportedRegExp(message: "Unsupported regexp rule: \(error.localizedDescription)")
            }
        }

        // Prepending WebSocket protocol to resolve this:
        // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/957
        if (isWebSocket && !urlRegExpSource!.hasPrefix("^") && !urlRegExpSource!.hasPrefix("ws")) {
            // TODO: convert to NSString
            return BlockerEntryFactory.URL_FILTER_WS_ANY_URL + ".*" + (urlRegExpSource! as String)
        }

        return urlRegExpSource! as String;
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

    /**
     * Throws error if provided rule contains regexp in permitted or restricted domains
     */
    // TODO(ameshkov): !!! Remove this
    private func excludeRegexpDomainRule(_ rule: Rule) throws -> Void {
        let domains = rule.restrictedDomains + rule.permittedDomains
        try domains.forEach { item in
            if item.hasPrefix("/") && item.hasSuffix("/") {
                throw ConversionError.invalidDomains(message: "Safari does not support regular expressions in permitted or restricted domains");
            }
        }
    }

    /// Adds domain limitations to the rule's trigger block.
    ///
    /// Domain limitations are controlled by the "if-domain" and "unless-domain" arrays.
    private func addDomainOptions(rule: Rule, trigger: inout BlockerEntry.Trigger) throws -> Void {
        var excludedDomains = rule.restrictedDomains
        let includedDomains = rule.permittedDomains

        // Discard rules that contains regexp in if-domain or unless-domain
        // https://github.com/AdguardTeam/SafariConverterLib/issues/53
        try excludeRegexpDomainRule(rule)
        
        let included = resolveTopLevelDomainWildcards(domains: includedDomains)
        addUnlessDomainForThirdParty(rule: rule, domains: &excludedDomains)

        let excluded = resolveTopLevelDomainWildcards(domains: excludedDomains)

        try writeDomainOptions(included: included, excluded: excluded, trigger: &trigger)
    }

    /// Adds domain to unless-domains for third-party rules
    ///
    /// https://github.com/AdguardTeam/AdGuardForSafari/issues/104
    ///
    /// TODO(ameshkov): !!! As of Safari 18 this is not required anymore, check other versions
    private func addUnlessDomainForThirdParty(rule: Rule, domains: inout [String]) {
        if !(rule is NetworkRule) {
            return
        }

        let networkRule = rule as! NetworkRule;
        if (networkRule.isThirdParty) {
            if (networkRule.permittedDomains.count == 0) {
                let res = NetworkRuleParser.extractDomain(pattern: networkRule.urlRuleText)
                if (res.domain == "") {
                    return;
                }

                domains.append(res.domain);
            }
        }
    }

    private func writeDomainOptions(included: [String], excluded: [String], trigger: inout BlockerEntry.Trigger) throws -> Void {

        if (included.count > 0 && excluded.count > 0) {
            throw ConversionError.invalidDomains(message: "Safari does not support both permitted and restricted domains");
        }

        if (included.count > 0) {
            trigger.ifDomain = included;
        }
        if (excluded.count > 0) {
            trigger.unlessDomain = excluded;
        }
    };

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

    /**
     * As a limited solution to support wildcard in tld, as there is no support for wildcards in "if-domain" property in CB
     * we are going to use a list of popular domains.
     * https://github.com/AdguardTeam/AdGuardForSafari/issues/248
     *
     * @param domains
     */
    private func resolveTopLevelDomainWildcards(domains: [String]) -> [String] {
        var result = [String]()

        for domain in domains {
            let nsDomain = domain as NSString
            if (nsDomain.hasSuffix(".*")) {
                for tld in BlockerEntryFactory.TOP_LEVEL_DOMAINS_LIST {
                    var modified = nsDomain.substring(to: nsDomain.length - 2)
                    modified = modified + "." + tld
                    result.append(modified.lowercased())
                }
            } else {
                result.append(domain.lowercased())
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

                // Due to https://github.com/AdguardTeam/AdguardBrowserExtension/issues/145
                throw ConversionError.unsupportedContentType(message: "Subdocument blocking rules are allowed only along with third-party or if-domain modifiers");
            }
        }

        if (entry.trigger.resourceType?.firstIndex(of: "popup") != nil) {
            throw ConversionError.unsupportedRule(message: "$popup rules are not supported");
        }
    }

    /**
     * Validates css rule and discards rules considered dangerous or invalid.
     */
    private func validateCssFilterRule(entry: BlockerEntry) throws -> Void {
        if (entry.action.type != "css-extended" && entry.action.type != "css-inject") {
            return;
        }

        if (entry.action.css!.indexOf(target: "url(") >= 0) {
            throw ConversionError.dangerousCss(message: "Urls are not allowed in css styles");
        }
    };

    enum ConversionError: Error {
        case unsupportedRule(message: String)
        case unsupportedRegExp(message: String)
        case unsupportedContentType(message: String)
        case invalidDomains(message: String)
        case dangerousCss(message: String)
    }
}
