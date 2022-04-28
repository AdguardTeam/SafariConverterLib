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

    /**
     * Precompiled validate regexps
     */
    private static let VALIDATE_REGEXP_DIGITS    = try! NSRegularExpression(pattern: "\\{[0-9,]+\\}", options: [.caseInsensitive]);
    private static let VALIDATE_REGEXP_OR        = try! NSRegularExpression(pattern: #"[^\\]+\|+\S*"#, options: [.caseInsensitive]);
    private static let VALIDATE_REGEXP_LOOKAHEAD = try! NSRegularExpression(pattern: "\\(\\?!.*\\)", options: [.caseInsensitive]);
    private static let VALIDATE_REGEXP_METACHARS = try! NSRegularExpression(pattern: #"[^\\]\\[bdfnrstvw]"#, options: [.caseInsensitive]);
    
    private static let REGEXP_SLASH = "/"

    let advancedBlockingEnabled: Bool;
    let errorsCounter: ErrorsCounter;

    init(advancedBlockingEnabled: Bool, errorsCounter: ErrorsCounter) {
        self.advancedBlockingEnabled = advancedBlockingEnabled;
        self.errorsCounter = errorsCounter;
    }

    /**
     * Converts rule object to blocker entry object
     */
    func createBlockerEntry(rule: Rule) -> BlockerEntry? {
        do {
            if (rule is NetworkRule) {
                return try convertNetworkRule(rule: rule as! NetworkRule);
            } else {
                if (self.advancedBlockingEnabled) {
                    if (rule.isScriptlet) {
                        return try convertScriptletRule(rule: rule as! CosmeticRule);
                    } else if (rule.isScript) {
                        return try convertScriptRule(rule: rule as! CosmeticRule);
                    }
                }

                if (!rule.isScript && !rule.isScriptlet) {
                    return try convertCssRule(rule: rule as! CosmeticRule);
                }
            }
        } catch {
            self.errorsCounter.add();
            Logger.log("(BlockerEntryFactory) - Unexpected error: \(error) while converting \(rule.ruleText)");
        }

        return nil;
    }

    /**
     * Creates blocker entry object from source Network rule.
     */
    private func convertNetworkRule(rule: NetworkRule) throws -> BlockerEntry? {
        if (rule.isCspRule) {
            throw ConversionError.unsupportedRule(message: "CSP rules are not supported");
        }

        let urlFilter = try createUrlFilterString(rule: rule);

        var trigger = BlockerEntry.Trigger(urlFilter: urlFilter);
        var action = BlockerEntry.Action(type: "block");

        setWhiteList(rule: rule, action: &action);
        try addResourceType(rule: rule, trigger: &trigger);
        addLoadContext(rule: rule, trigger: &trigger);
        addThirdParty(rule: rule, trigger: &trigger);
        addMatchCase(rule: rule, trigger: &trigger);
        try addDomainOptions(rule: rule, trigger: &trigger);

        try checkWhiteListExceptions(rule: rule, trigger: &trigger);

        let result = BlockerEntry(trigger: trigger, action: action)
        try validateUrlBlockingRule(rule: rule, entry: result);

        return result;
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
        var trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_CSS_RULES);

        if rule.pathModifier != nil {
            var pathRegex: String
            if rule.pathModifier!.hasPrefix(BlockerEntryFactory.REGEXP_SLASH) && rule.pathModifier!.hasSuffix(BlockerEntryFactory.REGEXP_SLASH) {
                pathRegex = String(String(rule.pathModifier!.dropFirst()).dropLast())

                try validateRegExp(urlRegExp: pathRegex as NSString)

                // Safari doesn't support non-ASCII characters in regular expressions
                if !pathRegex.canBeConverted(to: String.Encoding.ascii) {
                    throw ConversionError.unsupportedRegExp(message: "Safari doesn't support non-ASCII characters in regular expressions")
                }
            } else {
                pathRegex = SimpleRegex.createRegexText(str: rule.pathModifier! as NSString)! as String
            }
            trigger = BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_CSS_RULES + pathRegex)
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

    private func createUrlFilterString(rule: NetworkRule) throws -> String {
        let isWebSocket = rule.isWebSocket

        // Use a single standard regex for rules that are supposed to match every URL
        for anyUrlTmpl in BlockerEntryFactory.ANY_URL_TEMPLATES {
            if rule.urlRuleText.compare(anyUrlTmpl, options: NSString.CompareOptions.literal) == ComparisonResult.orderedSame {
                if isWebSocket {
                    return BlockerEntryFactory.URL_FILTER_WS_ANY_URL
                }
                return BlockerEntryFactory.URL_FILTER_ANY_URL
            }
        }

        let urlRegExpSource = rule.urlRegExpSource;
        if (urlRegExpSource == nil) {
            // Rule with empty regexp
            return BlockerEntryFactory.URL_FILTER_ANY_URL;
        }

        // Safari doesn't support non-ASCII characters in regular expressions
        if !urlRegExpSource!.canBeConverted(to: String.Encoding.ascii.rawValue) {
            throw ConversionError.unsupportedRegExp(message: "Safari doesn't support non-ASCII characters in regular expressions")
        }

        // Regex that we generate for basic non-regex rules are okay
        // But if this is a regex rule, we can't be sure
        if rule.isRegexRule() {
            try validateRegExp(urlRegExp: urlRegExpSource!);
        }

        // Prepending WebSocket protocol to resolve this:
        // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/957
        if (isWebSocket && !urlRegExpSource!.hasPrefix("^") && !urlRegExpSource!.hasPrefix("ws")) {
            // TODO: convert to NSString
            return BlockerEntryFactory.URL_FILTER_WS_ANY_URL + ".*" + (urlRegExpSource! as String);
        }

        return urlRegExpSource! as String;
    };

    private func setWhiteList(rule: Rule, action: inout BlockerEntry.Action) -> Void {
        if (rule.isWhiteList) {
            action.type = "ignore-previous-rules";
        }
    }

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
            // `fetch` resource type is supported since Safari 15, but not supported in macOS 11 (Big Sur)
            if SafariService.current.version.isSafari15() && !isMacOS11() {
                types.append("fetch")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.OTHER) {
            // `other` resource type is supported since Safari 15, but not supported in macOS 11 (Big Sur)
            if SafariService.current.version.isSafari15() && !isMacOS11() {
                types.append("other")
            } else if !rawAdded {
                rawAdded = true
                types.append("raw")
            }
        }

        if rule.hasContentType(contentType: NetworkRule.ContentType.WEBSOCKET) {
            // `websocket` resource type is supported since Safari 15, but not supported in macOS 11 (Big Sur)
            if SafariService.current.version.isSafari15() && !isMacOS11() {
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
            if SafariService.current.version.rawValue >= SafariVersion.safari14.rawValue {
                types.append("ping")
            }
        }

        var documentAdded = false
        if !documentAdded && rule.hasContentType(contentType: NetworkRule.ContentType.DOCUMENT) {
            documentAdded = true
            types.append("document")
        }
        if !documentAdded && rule.hasContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT) {
            if !SafariService.current.version.isSafari15() {
                documentAdded = true
                types.append("document")
            }
        }

        if (rule.isBlockPopups) {
            types = ["document"]
        }

        // Not supported modificators
        if (rule.isContentType(contentType: NetworkRule.ContentType.OBJECT)) {
            throw ConversionError.unsupportedContentType(message: "$object content type is not yet supported")
        }
        if (rule.isContentType(contentType: NetworkRule.ContentType.OBJECT_SUBREQUEST)) {
            throw ConversionError.unsupportedContentType(message: "$object_subrequest content type is not yet supported")
        }
        if (rule.isContentType(contentType: NetworkRule.ContentType.WEBRTC)) {
            throw ConversionError.unsupportedContentType(message: "$webrtc content type is not yet supported")
        }
        if (rule.isReplace) {
            throw ConversionError.unsupportedContentType(message: "$replace rules are ignored.")
        }

        if (types.count > 0) {
            trigger.resourceType = types
        }
    }
    
    private func addLoadContext(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        var context = [String]();
        // `child-frame` and `top-frame` contexts are supported since Safari 15
        if SafariService.current.version.isSafari15() {
            if rule.hasContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT)
                && !rule.isContentType(contentType:NetworkRule.ContentType.ALL) {
                context.append("child-frame");
            }
            if rule.hasRestrictedContentType(contentType: NetworkRule.ContentType.SUBDOCUMENT) {
                context.append("top-frame");
            }
        }
        if context.count > 0 {
            trigger.loadContext = context;
        }
    };

    private func addThirdParty(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        if (rule.isCheckThirdParty) {
            trigger.loadType = rule.isThirdParty ? ["third-party"] : ["first-party"];
        }
    };

    private func addMatchCase(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) -> Void {
        if (rule.isMatchCase) {
            trigger.caseSensitive = true;
        }
    };

    private func addDomainOptions(rule: Rule, trigger: inout BlockerEntry.Trigger)  throws -> Void {
        let included = resolveTopLevelDomainWildcards(domains: rule.permittedDomains);

        var excludedDomains = rule.restrictedDomains;
        addUnlessDomainForThirdParty(rule: rule, domains: &excludedDomains);
        let excluded = resolveTopLevelDomainWildcards(domains: excludedDomains);

        try writeDomainOptions(included: included, excluded: excluded, trigger: &trigger);
    }

    /**
     * Adds domain to unless-domains for third-party rules
     * https://github.com/AdguardTeam/AdGuardForSafari/issues/104
     */
    private func addUnlessDomainForThirdParty(rule: Rule, domains: inout [String]) {
        if !(rule is NetworkRule) {
            return;
        }

        let networkRule = rule as! NetworkRule;
        if (networkRule.isThirdParty) {
            if (networkRule.permittedDomains.count == 0) {
                let parseDomainResult = networkRule.parseRuleDomain();
                if (parseDomainResult == nil || parseDomainResult!.domain == nil) {
                    return;
                }

                let domain = parseDomainResult!.domain!;
                domains.append(domain);
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

    private func checkWhiteListExceptions(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) throws -> Void {
        if (!rule.isWhiteList) {
            return;
        }

        if (rule.isDocumentWhiteList || rule.isUrlBlock || rule.isCssExceptionRule || rule.isJsInject) {
            if (rule.isDocumentWhiteList) {
                trigger.resourceType = nil;
            }

            let parseDomainResult = rule.parseRuleDomain();
            if (parseDomainResult != nil &&
                parseDomainResult!.path != nil &&
                parseDomainResult!.path != "^" &&
                parseDomainResult!.path != "/") {
                // https://jira.adguard.com/browse/AG-8664
                return;
            }

            if (parseDomainResult == nil || parseDomainResult!.domain == nil) {
                return;
            }

            let domain = parseDomainResult!.domain!;
            rule.permittedDomains.append(domain);
            try addDomainOptions(rule: rule, trigger: &trigger);

            trigger.urlFilter = BlockerEntryFactory.URL_FILTER_URL_RULES_EXCEPTIONS;
            trigger.resourceType = nil;
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

    /**
     * Safari doesn't support some regular expressions
     * Supporeted expressions:
     * .* - Matches all strings with a dot appearing zero or more times. Use this syntax to match every URL.
     * . - Matches any character.
     * \. - Explicitly matches the dot character.
     * [a-b] - Matches a range of alphabetic characters.
     * (abc) - Matches groups of the specified characters.
     * + - Matches the preceding term one or more times.
     * * - Matches the preceding character zero or more times.
     * ? - Matches the preceding character zero or one time.
     */
    private func validateRegExp(urlRegExp: NSString) throws -> Void {
        // Safari doesn't support {digit} in regular expressions
        if (urlRegExp.contains("{")) {
            if (SimpleRegex.isMatch(regex: BlockerEntryFactory.VALIDATE_REGEXP_DIGITS, target: urlRegExp)) {
                throw ConversionError.unsupportedRegExp(message: "Safari doesn't support '{digit}' in regular expressions");
            }
        }

        // Safari doesn't support | in regular expressions
        if (urlRegExp.contains("|")) {
            if (SimpleRegex.isMatch(regex: BlockerEntryFactory.VALIDATE_REGEXP_OR, target: urlRegExp)) {
                throw ConversionError.unsupportedRegExp(message: "Safari doesn't support '|' in regular expressions");
            }
        }

        // Safari doesn't support negative lookahead (?!...) in regular expressions
        if (urlRegExp.contains("(?!")) {
            if (SimpleRegex.isMatch(regex: BlockerEntryFactory.VALIDATE_REGEXP_LOOKAHEAD, target: urlRegExp)) {
                throw ConversionError.unsupportedRegExp(message: "Safari doesn't support negative lookahead in regular expressions");
            }
        }

        // Safari doesn't support metacharacters in regular expressions
        if (urlRegExp.contains("\\")) {
            if (SimpleRegex.isMatch(regex: BlockerEntryFactory.VALIDATE_REGEXP_METACHARS, target: urlRegExp)) {
                throw ConversionError.unsupportedRegExp(message: "Safari doesn't support metacharacters in regular expressions");
            }
        }
    };

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
