import Foundation

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
        "co.nz", "rs", "ai", "website", "bg", "ua", "ma", "world", "pe", "link",
    ]

    private let errorsCounter: ErrorsCounter
    private let version: SafariVersion

    /// Creates a new instance of BlockerEntryFactory.
    ///
    /// - Parameters:
    ///   - errorsCounter: object where we count the total number of conversion
    ///                    errors though the whole conversion process.
    ///   - version: version of Safari for which the rules are being built.
    init(errorsCounter: ErrorsCounter, version: SafariVersion) {
        self.errorsCounter = errorsCounter
        self.version = version
    }

    /// Converts an AdGuard rule into one or several Safari content blocking rules.
    ///
    /// - Parameters:
    ///   - rule: Source AdGuard rule (either `NetworkRule` or `CosmeticRule`).
    /// - Returns: Array of Safari content blocker rules or `nil` if it fails to convert the source rule.
    func createBlockerEntries(rule: Rule) -> [BlockerEntry]? {
        do {
            if let rule = rule as? NetworkRule {
                return try convertNetworkRuleEntries(rule: rule)
            }

            if let rule = rule as? CosmeticRule {
                if !rule.permittedDomains.isEmpty && !rule.restrictedDomains.isEmpty {
                    // The rule has mixed permitted/restricted domains,
                    // it requires special handling.
                    return try convertCosmeticRuleMixedDomains(rule: rule)
                }

                return try convertCosmeticRuleEntries(rule: rule)
            }
        } catch {
            self.errorsCounter.add()
            Logger.log(
                "(BlockerEntryFactory) - Unexpected error: \(error) while converting \(rule.ruleText)"
            )
        }

        return nil
    }

    /// Converts a network rule into one or more Safari content blocking rules.
    /// Depending on the rule modifiers, this may create multiple Safari CB
    /// rules for a single network rule (example: $method modifier).
    ///
    /// - Parameter rule: The network rule to convert.
    /// - Returns: An array of Safari content blocking rules.
    /// - Throws: `ConversionError` if the rule cannot be converted.
    private func convertNetworkRuleEntries(rule: NetworkRule) throws -> [BlockerEntry] {
        if rule.requestMethods.isEmpty {
            return try convertNetworkRuleEntries(rule: rule, requestMethod: nil)
        }

        if !self.version.isSafari26orGreater() {
            throw ConversionError.unsupportedRule(message: "$method is not supported")
        }

        var entries: [BlockerEntry] = []
        entries.reserveCapacity(rule.requestMethods.count)

        for method in rule.requestMethods {
            entries.append(
                contentsOf: try convertNetworkRuleEntries(
                    rule: rule,
                    requestMethod: method
                )
            )
        }
        return entries
    }

    /// Converts a network rule into one or more Safari content blocking rules with a fixed request method.
    ///
    /// - Parameters:
    ///   - rule: Network rule to convert.
    ///   - requestMethod: HTTP request method to match, if any.
    /// - Returns: Array of Safari content blocker entries.
    /// - Throws: `ConversionError` if the rule cannot be converted.
    private func convertNetworkRuleEntries(
        rule: NetworkRule,
        requestMethod: String?
    ) throws -> [BlockerEntry] {
        let urlFilter = try createUrlFilterString(rule: rule)

        var baseTrigger = BlockerEntry.Trigger(urlFilter: urlFilter)
        let action = BlockerEntry.Action(type: rule.isWhiteList ? "ignore-previous-rules" : "block")

        try addResourceType(rule: rule, trigger: &baseTrigger)
        addLoadContext(rule: rule, trigger: &baseTrigger)
        addThirdParty(rule: rule, trigger: &baseTrigger)
        addMatchCase(rule: rule, trigger: &baseTrigger)

        updateTriggerForDocumentLevelExceptionRules(rule: rule, trigger: &baseTrigger)

        var triggers = try createTriggersWithDomainOptions(rule: rule, baseTrigger: baseTrigger)
        if let requestMethod {
            for index in triggers.indices {
                triggers[index].requestMethod = requestMethod
            }
        }

        return triggers.map { BlockerEntry(trigger: $0, action: action) }
    }
    /// Validates if the cosmetic rule can be converted into a content blocker rule.
    ///
    /// - Parameters:
    ///   - rule: Cosmetic rule to check.
    /// - Throws: `ConversionError` if the cosmetic rule cannot be converted.
    private func validateCosmeticRule(rule: CosmeticRule) throws {
        if rule.isScript || rule.isScriptlet || rule.isInjectCss || rule.isExtendedCss {
            throw ConversionError.unsupportedRule(
                message: "Cannot convert advanced rule: \(rule.ruleText)"
            )
        }

        if rule.isWhiteList {
            throw ConversionError.unsupportedRule(
                message: "Cannot convert cosmetic exception: \(rule.ruleText)"
            )
        }
    }

    /// Creates a `css-display-none` blocker entry object from the source cosmetic rule.
    ///
    /// Note, that this function does not support the following cosmetic rules:
    /// - Extended CSS rules and CSS injection rules (must be handled by advanced blocking, i.e. web extension)
    /// - Rules with mixed permitted/restricted domains.
    ///
    /// - Parameters:
    ///   - rule: Cosmetic rule to convert.
    /// - Returns: Content blocker entry.
    /// - Throws: `ConversionError` if the rule cannot be converted.
    private func convertCosmeticRuleEntries(rule: CosmeticRule) throws -> [BlockerEntry] {
        try validateCosmeticRule(rule: rule)

        let urlFilter = try createUrlFilterStringForCosmetic(rule: rule)
        let action = BlockerEntry.Action(type: "css-display-none", selector: rule.content)

        let baseTrigger = BlockerEntry.Trigger(urlFilter: urlFilter)
        let triggers = try createTriggersWithDomainOptions(rule: rule, baseTrigger: baseTrigger)
        return triggers.map { BlockerEntry(trigger: $0, action: action) }
    }

    /// Creates several `css-display-none` entries for a cosmetic rule that has
    /// mixed permitted/restricted domains, i.e. `example.org,~sub.example.org##.banner`.
    ///
    /// ### Example
    ///
    /// The rule below has mixed permitted/restricted domains:
    /// `example.org,example.com,~sub.example.org,~sub.example.com##.banner`
    ///
    /// It will be converted to two different `css-display-rules`:
    ///
    /// ```
    /// "trigger": {
    ///   "url-filter": "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.org([\/:&\?].*)?",
    ///   "unless-domain": [ "*sub.example.org*" ]
    /// }
    /// ...
    /// "trigger": {
    ///   "url-filter": "^[htpsw]+:\\/\\/([a-z0-9-]+\\.)?example\\.com([\/:&\?].*)?",
    ///   "unless-domain": [ "*sub.example.com*" ]
    /// }
    /// ```
    ///
    /// ### Limitations
    ///
    /// - This conversion cannot be supported for cosmetic rules with `$path` or `$url` modifiers.
    /// - Limited to Safari 16.4 or newer.
    ///
    /// - Parameters:
    ///   - rule: Cosmetic rule to convert
    /// - Returns: Array of content blocker rules
    /// - Throws: `ConversionError` or `SyntaxError` if it fails to convert for some reason.
    private func convertCosmeticRuleMixedDomains(rule: CosmeticRule) throws -> [BlockerEntry] {
        // Just in case, we limit this functionality to Safari 16.4 or newer.
        if !self.version.isSafari16_4orGreater() {
            throw ConversionError.invalidDomains(
                message: "Mixed permitted/restricted domains aren't supported"
            )
        }

        if rule.pathModifier != nil {
            throw ConversionError.invalidDomains(
                message: "Mixing permitted/restricted domains with $path is not supported"
            )
        }

        try validateCosmeticRule(rule: rule)

        var entries: [BlockerEntry] = []

        for domain in rule.permittedDomains {
            let urlFilter = try SimpleRegex.createRegexText(pattern: "||\(domain)^")

            var trigger = BlockerEntry.Trigger(urlFilter: urlFilter)
            let restricted = resolveDomains(domains: rule.restrictedDomains)
            trigger.unlessDomain = restricted

            let action = BlockerEntry.Action(type: "css-display-none", selector: rule.content)
            let result = BlockerEntry(trigger: trigger, action: action)

            entries.append(result)
        }

        return entries
    }

    /// Builds the `url-filter` property of a Safari content blocking rule from a cosmetic rule.
    ///
    /// - Parameters:
    ///   - rule: Cosmetic rule for which we're creating `url-filter`.
    /// - Returns: Regular expression for `url-filter`.
    /// - Throws: Throws `ConversionError` for unsupported regular expressions.
    private func createUrlFilterStringForCosmetic(rule: CosmeticRule) throws -> String {
        if rule.pathRegExpSource == nil || rule.pathModifier == nil {
            return BlockerEntryFactory.URL_FILTER_COSMETIC_RULES
        }

        // Special treatment for $path
        guard let pathRegex = rule.pathRegExpSource,
            let path = rule.pathModifier
        else {
            return BlockerEntryFactory.URL_FILTER_COSMETIC_RULES
        }

        // First, validate custom regular expressions.
        if SimpleRegex.isRegexPattern(path) {
            let result = SafariRegex.isSupported(pattern: pathRegex)

            switch result {
            case .success: break
            case .failure(let error):
                throw ConversionError.unsupportedRegExp(
                    message: "Unsupported regexp in $path: \(error)"
                )
            }
        }

        if pathRegex.utf8.first == Chars.CARET {
            // If $path regular expression starts with '^', we need to prepend a regular expression
            // that will match the beginning of the URL as we'll put the result into 'url-filter'
            // which is applied to the full URL and not just to path.
            let prefix = BlockerEntryFactory.URL_FILTER_PREFIX_CSS_RULES_PATH_START_STRING
            return prefix + pathRegex.dropFirst()
        }

        // In other cases just prepend "any URL" pattern.
        return BlockerEntryFactory.URL_FILTER_COSMETIC_RULES + pathRegex
    }

    /// Builds the `url-filter` property of a Safari content blocking rule.
    ///
    /// - Parameters:
    ///   - rule: Network rule for which we're creating `url-filter`.
    /// - Returns: Regular expression for `url-filter`.
    /// - Throws: Throws `ConversionError` for unsupported regular expressions.
    private func createUrlFilterString(rule: NetworkRule) throws -> String {
        let isWebSocket = rule.isWebSocket

        // Use a single standard regex for rules that are supposed to match every URL.
        for anyUrlTmpl in BlockerEntryFactory.ANY_URL_TEMPLATES where rule.urlRuleText == anyUrlTmpl
        {
            if isWebSocket {
                return BlockerEntryFactory.URL_FILTER_WS_ANY_URL
            }
            return BlockerEntryFactory.URL_FILTER_ANY_URL
        }

        if rule.urlRegExpSource == nil {
            // Rule with empty regexp, matches any URL.
            return BlockerEntryFactory.URL_FILTER_ANY_URL
        }

        guard let urlFilter = rule.urlRegExpSource else {
            return BlockerEntryFactory.URL_FILTER_ANY_URL
        }

        // Regex that we generate for basic non-regex rules are okay.
        // But if this is a regex rule, we can't be sure.
        if rule.isRegexRule() {
            let result = SafariRegex.isSupported(pattern: urlFilter)

            switch result {
            case .success: break
            case .failure(let error):
                throw ConversionError.unsupportedRegExp(
                    message: "Unsupported regexp rule: \(error)"
                )
            }
        }

        // Prepending WebSocket protocol to resolve this:
        // https://github.com/AdguardTeam/AdguardBrowserExtension/issues/957
        if isWebSocket && !urlFilter.hasPrefix("^") && !urlFilter.hasPrefix("ws") {
            return BlockerEntryFactory.URL_FILTER_WS_ANY_URL + ".*" + urlFilter
        }

        return urlFilter
    }

    /// Adds resource type based on the content types specified in the network rule.
    ///
    /// Read more about it here:
    /// https://developer.apple.com/documentation/safariservices/creating-a-content-blocker#:~:text=if%2Ddomain.-,resource%2Dtype,-An%20array%20of
    private func addResourceType(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) throws {
        // Using String array instead of Set makes the code a bit more clunkier, but saves time.
        var types: [String] = []

        if rule.isContentType(contentType: .all) && rule.restrictedContentType.isEmpty {
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

        if rule.isOptionEnabled(option: .popup) {
            // Make sure that $popup only target document to avoid false positive blocking.
            types = ["document"]
        }

        if !types.isEmpty {
            trigger.resourceType = types
        }
    }

    /// Adds "load-context" to the content blocker action.
    ///
    /// You can read more about it in the documentation: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker#:~:text=top%2Durl.-,load%2Dcontext,-An%20array%20of
    ///
    /// We use this to apply $subdocument correctly in Safari, i.e. only apply it
    /// on the child frame level.
    private func addLoadContext(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) {
        var context: [String] = []

        // `child-frame` and `top-frame` contexts are supported since Safari 15
        if self.version.isSafari15orGreater() {
            if rule.hasContentType(contentType: .subdocument)
                && !rule.isContentType(contentType: .all)
            {
                context.append("child-frame")
            }
            if rule.hasRestrictedContentType(contentType: .subdocument) {
                context.append("top-frame")
            }
        }

        if !context.isEmpty {
            trigger.loadContext = context
        }
    }

    /// Adds load-type property to the rule if required.
    private func addThirdParty(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) {
        if rule.isCheckThirdParty {
            trigger.loadType = rule.isThirdParty ? ["third-party"] : ["first-party"]
        }
    }

    /// Makes the url-filter case sensitive if required.
    private func addMatchCase(rule: NetworkRule, trigger: inout BlockerEntry.Trigger) {
        if rule.isMatchCase {
            trigger.caseSensitive = true
        }
    }

    /// Applies domain limitations to the rule's trigger block.
    ///
    /// For older Safari versions we use `if-domain`/`unless-domain`.
    /// Starting from Safari 26, to support `domain.*` and domain regexes we use a hybrid approach:
    /// prefer `if-domain`/`unless-domain` where possible and fall back to
    /// `if-frame-url`/`unless-frame-url` for `domain.*` and regex domains.
    ///
    /// - Parameters:
    ///   - rule: Rule for which we apply domain limitations.
    ///   - baseTrigger: Trigger without domain-related fields.
    /// - Returns: One or more triggers (for Safari 26+ we may need to split domain limitations).
    /// - Throws: `ConversionError` if the domain limitations cannot be represented.
    private func createTriggersWithDomainOptions(
        rule: Rule,
        baseTrigger: BlockerEntry.Trigger
    ) throws -> [BlockerEntry.Trigger] {
        let included = rule.permittedDomains
        let excluded = rule.restrictedDomains

        if !included.isEmpty && !excluded.isEmpty {
            throw ConversionError.invalidDomains(
                message: "Safari does not support both permitted and restricted domains"
            )
        }

        if !self.version.isSafari26orGreater() {
            return [createLegacyDomainTrigger(rule: rule, baseTrigger: baseTrigger)]
        }

        // No domain limitations.
        if included.isEmpty && excluded.isEmpty {
            return [baseTrigger]
        }

        let domains = included.isEmpty ? excluded : included
        let (plain, special) = splitDomainsForSafari26(domains: domains)

        return try createTriggersWithFrameUrlSupport(
            included: included,
            plain: plain,
            special: special,
            baseTrigger: baseTrigger
        )
    }

    /// Creates a trigger using the legacy domain fields (`if-domain`/`unless-domain`).
    ///
    /// This path is used for Safari versions earlier than Safari 26, where we cannot
    /// fall back to `if-frame-url`/`unless-frame-url` for advanced domain patterns.
    private func createLegacyDomainTrigger(
        rule: Rule,
        baseTrigger: BlockerEntry.Trigger
    ) -> BlockerEntry.Trigger {
        var trigger = baseTrigger

        let resolvedIncluded = resolveDomains(domains: rule.permittedDomains)
        var resolvedExcluded = resolveDomains(domains: rule.restrictedDomains)
        addUnlessDomainForThirdParty(rule: rule, domains: &resolvedExcluded)

        if !resolvedIncluded.isEmpty {
            trigger.ifDomain = resolvedIncluded
        }

        if !resolvedExcluded.isEmpty {
            trigger.unlessDomain = resolvedExcluded
        }

        return trigger
    }

    private func createTriggersWithFrameUrlSupport(
        included: [String],
        plain: [String],
        special: [String],
        baseTrigger: BlockerEntry.Trigger
    ) throws -> [BlockerEntry.Trigger] {
        var triggers: [BlockerEntry.Trigger] = []
        triggers.reserveCapacity((plain.isEmpty ? 0 : 1) + (special.isEmpty ? 0 : 1))

        if !plain.isEmpty {
            var trigger = baseTrigger
            // Prepend * to include subdomains.
            let wildcardDomains = plain.map { "*" + $0 }
            if included.isEmpty {
                trigger.unlessDomain = wildcardDomains
            } else {
                trigger.ifDomain = wildcardDomains
            }
            triggers.append(trigger)
        }

        if !special.isEmpty {
            var trigger = baseTrigger
            let frameUrlPatterns = try createFrameUrlPatterns(domains: special)
            if included.isEmpty {
                trigger.unlessFrameUrl = frameUrlPatterns
            } else {
                trigger.ifFrameUrl = frameUrlPatterns
            }
            triggers.append(trigger)
        }

        return triggers
    }

    private func splitDomainsForSafari26(
        domains: [String]
    ) -> (
        plain: [String],
        special: [String]
    ) {
        var plain: [String] = []
        var special: [String] = []
        plain.reserveCapacity(domains.count)

        for domain in domains {
            if SimpleRegex.isRegexPattern(domain) || isTldWildcardDomain(domain) {
                special.append(domain)
            } else {
                plain.append(domain)
            }
        }

        return (plain, special)
    }

    private func isTldWildcardDomain(_ domain: String) -> Bool {
        return domain.hasSuffix(".*")
    }

    private func createFrameUrlPatterns(domains: [String]) throws -> [String] {
        return try domains.map { domain in
            if isTldWildcardDomain(domain) {
                return try createTldWildcardFrameUrlPattern(domain: domain)
            } else if SimpleRegex.isRegexPattern(domain) {
                return try createRegexFrameUrlPattern(domain: domain)
            }

            throw ConversionError.invalidDomains(
                message: "Unsupported frame-url domain pattern: \(domain)"
            )
        }
    }

    private func createTldWildcardFrameUrlPattern(domain: String) throws -> String {
        // Convert `example.*` to a regex that matches `example.<any suffix>`.
        let prefix = String(domain.dropLast(2))
        let escaped = prefix.replacingOccurrences(of: ".", with: #"\."#)
        let pattern = #"^[^:]+://+([^:/]+\.)?\#(escaped)\.[^/:]+([/:?#].*)?$"#
        try validateSafariRegex(pattern: pattern, context: domain)
        return pattern
    }

    private func createRegexFrameUrlPattern(domain: String) throws -> String {
        guard var inner = SimpleRegex.extractRegex(domain) else {
            throw ConversionError.invalidDomains(
                message: "Invalid regular expression in domain: \(domain)"
            )
        }

        inner = SimpleRegex.unescapeDomainRegex(inner)

        var hostAnchored = false
        if inner.utf8.first == Chars.CARET {
            hostAnchored = true
            inner = String(inner.dropFirst())
        }

        if inner.utf8.last == Chars.DOLLAR {
            inner = String(inner.dropLast())
        }

        if inner.isEmpty {
            throw ConversionError.invalidDomains(
                message: "Empty regular expression in domain"
            )
        }

        let pattern: String
        if hostAnchored {
            pattern = #"^[^:]+://+\#(inner)([/:?#].*)?$"#
        } else {
            pattern = #"^[^:]+://+([^:/]+\.)?\#(inner)([/:?#].*)?$"#
        }

        try validateSafariRegex(pattern: pattern, context: domain)
        return pattern
    }

    private func validateSafariRegex(pattern: String, context: String) throws {
        let support = SafariRegex.isSupported(pattern: pattern)
        switch support {
        case .success:
            return
        case .failure(let error):
            throw ConversionError.unsupportedRegExp(
                message: "Unsupported regexp in domain \(context): \(error)"
            )
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

        guard let networkRule = rule as? NetworkRule else { return }
        guard networkRule.isThirdParty else { return }

        if networkRule.permittedDomains.isEmpty {
            let res = NetworkRuleParser.extractDomain(pattern: networkRule.urlRuleText)
            if res.domain.isEmpty {
                return
            }

            // Prepend wildcard to cover subdomains.
            domains.append("*" + res.domain)
        }
    }

    /// Applies additional post-processing to document-level whitelist rules
    /// (`$document`, `$elemhide`, `$jsinject`, `$urlblock`).
    ///
    /// The idea is that when such a rule targets a single domain, i.e. looks
    /// like `@@||example.org^$elemhide`, it would be much better from the
    /// performance point of view to use `if-domain` instead of `url-filter`.
    ///
    /// So instead of:
    ///
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
    private func updateTriggerForDocumentLevelExceptionRules(
        rule: NetworkRule,
        trigger: inout BlockerEntry.Trigger
    ) {
        if !rule.isWhiteList {
            return
        }

        if rule.isDocumentWhiteList || rule.isUrlBlock || rule.isCssExceptionRule || rule.isJsInject
        {
            if rule.isDocumentWhiteList {
                // $document rules unblock everything so remove resourceType limitation.
                trigger.resourceType = nil
            }

            let ruleDomain = NetworkRuleParser.extractDomain(pattern: rule.urlRuleText)
            if ruleDomain.domain.isEmpty || ruleDomain.patternMatchesPath {
                // Do not add if-domain limitation when the rule domain cannot be extracted
                // or when the rule is more specific than just a domain, i.e. in the case
                // of "@@||example.org/path" keep using "url-filter".
                return
            }

            if !rule.permittedDomains.contains(ruleDomain.domain) {
                rule.permittedDomains.append(ruleDomain.domain)
            }

            // Note, that for some domains it is crucial to use `.*` pattern as otherwise
            // Safari fails to match the page URL.
            //
            // Here's the example:
            // https://github.com/AdguardTeam/AdGuardForSafari/issues/285
            trigger.urlFilter = BlockerEntryFactory.URL_FILTER_ANY_URL
            trigger.resourceType = nil
        }
    }

    /// Resolve domains prepares a list of domains to be used in the `if-domain` and `unless-domain`
    /// Safari rule properties.
    ///
    /// This includes several things.
    ///
    /// - First of all, we apply special handling for `domain.*` values. Since we cannot fully support it yet,
    ///     we replace `.*` with a list of the most popular TLD domains.
    /// - In the case of AdGuard, `$domain` modifier includes all subdomains. For Safari these rules should be
    ///     transformed to `*domain.com` to signal that subdomains are included.
    private func resolveDomains(domains: [String]) -> [String] {
        var result: [String] = []

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
