import Foundation

/// Represents a network rule.
///
/// Note, that this implementations supports limited set of modifiers, it does not support
/// the ones that are not supported by Safari content blocking and cannot be implemented
/// using WebExtensions API.
///
/// Not supported:
/// - $replace
/// - $redirect
/// - $csp
/// - $object
///
/// TODO(ameshkov): !!! Add tests for not supported rules.
class NetworkRule: Rule {
    var isUrlBlock = false
    var isCssExceptionRule = false
    var isJsInject = false

    var isCheckThirdParty = false
    var isThirdParty = false
    var isMatchCase = false
    var isBlockPopups = false
    var isWebSocket = false
    var badfilter = false

    var permittedContentType: [ContentType] = [ContentType.ALL]
    var restrictedContentType: [ContentType] = []

    var enabledOptions: [NetworkRuleOption] = []
    var disabledOptions: [NetworkRuleOption] = []

    /// Network rule pattern.
    var urlRuleText = ""

    /// Regular expression that's converted from the rule pattern.
    var urlRegExpSource: String? = nil

    override init() {
        super.init()
    }

    override init(ruleText: String) throws {
        try super.init(ruleText: ruleText)

        let ruleParts = try NetworkRuleParser.parseRuleText(ruleText: ruleText)
        isWhiteList = ruleParts.whitelist

        if (ruleParts.options != nil && ruleParts.options != "") {
            try loadOptions(options: ruleParts.options!)
        }

        if (ruleParts.pattern == "||"
                || ruleParts.pattern == "*"
                || ruleParts.pattern == ""
                || ruleParts.pattern.utf8.count < 3
           ) {
            if (permittedDomains.count < 1) {
                // Rule matches too much and does not have any domain restriction
                // We should not allow this kind of rules
                throw SyntaxError.invalidPattern(message: "The rule is too wide, add domain restriction or make the pattern more specific")
            }
        }

        if (ruleParts.options == "specifichide" && ruleParts.whitelist == false) {
            throw SyntaxError.invalidModifier(message: "$pecifichide modifier must be used for exception rules only")
        }
        
        urlRuleText = ruleParts.pattern

        if (isRegexRule()) {
            let startIndex = urlRuleText.utf8.index(after: urlRuleText.utf8.startIndex)
            let endIndex = urlRuleText.utf8.index(before: urlRuleText.utf8.endIndex)
            
            urlRegExpSource = String(urlRuleText[startIndex..<endIndex])
        } else {
            urlRuleText = NetworkRuleParser.encodeDomainIfRequired(pattern: urlRuleText)!

            if (!urlRuleText.isEmpty) {
                urlRegExpSource = try SimpleRegex.createRegexText(pattern: urlRuleText)
            }
        }

        isDocumentWhiteList = isOptionEnabled(option: .Document);
        isUrlBlock = isSingleOption(option: .Urlblock) || isSingleOption(option: .Genericblock);
        isCssExceptionRule = isSingleOption(option: .Elemhide) || isSingleOption(option: .Generichide);
        isJsInject = isSingleOption(option: .Jsinject);
    }

    func isRegexRule() -> Bool {
        urlRuleText.utf8.first == Chars.SLASH && urlRuleText.utf8.last == Chars.SLASH
    }

    func isSingleOption(option: NetworkRuleOption) -> Bool {
        enabledOptions.count == 1 && enabledOptions.firstIndex(of: option) != nil
    }

    /// Checks if rule targets specified content type.
    ///
    /// TODO(ameshkov): Improve performance by changing permittedContentType/restrictedContentType to byte masks.
    func hasContentType(contentType: ContentType) -> Bool {
        if (permittedContentType == [ContentType.ALL] &&
                restrictedContentType.count == 0) {
            // Rule does not contain any constraint.
            return true
        }

        // Checking that either all content types are permitted or request content type is in the permitted list.
        let matchesPermitted = permittedContentType == [ContentType.ALL] ||
                permittedContentType.firstIndex(of: contentType) ?? -1 >= 0

        // Checking that either no content types are restricted or request content type is not in the restricted list.
        let notMatchesRestricted = restrictedContentType.count == 0 ||
                restrictedContentType.firstIndex(of: contentType) == nil

        return matchesPermitted && notMatchesRestricted
    }

    /// Returns true if the rule targets only the specified content type and nothing else.
    func isContentType(contentType: ContentType) -> Bool {
        permittedContentType.count == 1 && permittedContentType[0] == contentType
    }

    /// Returns true if the specified content type is restricted for this rule.
    func hasRestrictedContentType(contentType: ContentType) -> Bool {
        restrictedContentType.contains(contentType)
    }

    /// Checks if this rule negates the other rule.
    /// Only makes sense when this rule has a `$badfilter` modifier.
    func negatesBadfilter(specifiedRule: NetworkRule) -> Bool {
        if (isWhiteList != specifiedRule.isWhiteList) {
            return false
        }

        if (urlRuleText != specifiedRule.urlRuleText) {
            return false
        }

        if (permittedContentType != specifiedRule.permittedContentType) {
            return false
        }

        if (restrictedContentType != specifiedRule.restrictedContentType) {
            return false
        }

        if (enabledOptions != specifiedRule.enabledOptions) {
            return false
        }

        if (disabledOptions != specifiedRule.disabledOptions) {
            return false
        }

        if (restrictedDomains != specifiedRule.restrictedDomains) {
            return false
        }

        if (!NetworkRule.stringArraysHaveIntersection(left: permittedDomains, right: specifiedRule.permittedDomains)) {
            return false
        }

        return true
    }

    /// Checks if two string arrays have at least 1 element in intersection.
    private static func stringArraysHaveIntersection(left: [String], right: [String]) -> Bool {
        if (left.count == 0 && right.count == 0) {
            return true
        }

        for elem in left {
            if (right.contains(elem)) {
                return true
            }
        }

        return false
    }
    
    /// Sets rule domains from the $domain modifier.
    private func setNetworkRuleDomains(domains: String) throws -> Void {
        if (domains == "") {
            throw SyntaxError.invalidModifier(message: "$domain cannot be empty")
        }
        
        try setDomains(domainsStr: domains, separator: Chars.PIPE)
    }

    /// Parses network rule options from the options string.
    private func loadOptions(options: String) throws -> Void {
        let optionParts = options.split(delimiter: Chars.COMMA, escapeChar: Chars.BACKSLASH);
        
        for option in optionParts {
            var optionName = option
            var optionValue = ""
            
            let valueIndex = option.utf8.firstIndex(of: Chars.EQUALS_SIGN)
            if valueIndex != nil {
                optionName = String(option[..<valueIndex!])
                optionValue = String(option[option.utf8.index(after: valueIndex!)...])
            }
            
            try loadOption(optionName: optionName, optionValue: optionValue);
        }
        
        // Rules of these types can be applied to documents only
        // $jsinject, $elemhide, $urlblock, $genericblock, $generichide and $content for whitelist rules.
        // $popup - for url blocking
        if (
            isOptionEnabled(option: NetworkRuleOption.Document)
            || isOptionEnabled(option: NetworkRuleOption.Jsinject)
            || isOptionEnabled(option: NetworkRuleOption.Elemhide)
            || isOptionEnabled(option: NetworkRuleOption.Content)
            || isOptionEnabled(option: NetworkRuleOption.Urlblock)
            || isOptionEnabled(option: NetworkRuleOption.Genericblock)
            || isOptionEnabled(option: NetworkRuleOption.Generichide)
            || isBlockPopups
        ) {
            self.permittedContentType = [ContentType.DOCUMENT];
        }
    }

    /// Attempts to parse a single network rule option.
    private func loadOption(optionName: String, optionValue: String) throws -> Void {
        if optionName.utf8.first == Chars.UNDERSCORE {
            // A noop modifier does nothing and can be used to increase some rules readability.
            // It consists of the sequence of underscore characters (_) of any length
            // and can appear in a rule as many times as it's needed.
            if optionName.utf8.allSatisfy({$0 == Chars.UNDERSCORE}) {
                return
            }
        }

        switch (optionName) {
        case "all":
            // A normal blocking rule in the case of Safari is almost the same as $all,
            // i.e. it blocks all requests including main frame ones.
            // So we're doing nothing here.
            break
        case "third-party","~first-party","3p","~1p":
            isCheckThirdParty = true
            isThirdParty = true
        case "~third-party","first-party","1p","~3p":
            isCheckThirdParty = true
            isThirdParty = false
        case "match-case":
            isMatchCase = true
        case "~match-case":
            isMatchCase = false
        case "important":
            isImportant = true
        case "popup":
            isBlockPopups = true
        case "badfilter":
            badfilter = true
        case "domain":
            try setNetworkRuleDomains(domains: optionValue)
        case "elemhide", "ehide":
            try setOptionEnabled(option: NetworkRuleOption.Elemhide, value: true)
        case "generichide", "ghide":
            try setOptionEnabled(option: NetworkRuleOption.Generichide, value: true)
        case "genericblock":
            try setOptionEnabled(option: NetworkRuleOption.Genericblock, value: true)
        case "specifichide", "shide":
            try setOptionEnabled(option: NetworkRuleOption.Specifichide, value: true)
        case "jsinject":
            try setOptionEnabled(option: NetworkRuleOption.Jsinject, value: true)
        case "urlblock":
            try setOptionEnabled(option: NetworkRuleOption.Urlblock, value: true)
        case "content":
            try setOptionEnabled(option: NetworkRuleOption.Content, value: true)
        case "document", "doc":
            try setOptionEnabled(option: NetworkRuleOption.Document, value: true)
        case "script":
            setRequestType(contentType: ContentType.SCRIPT, enabled: true)
        case "~script":
            setRequestType(contentType: ContentType.SCRIPT, enabled: false)
        case "stylesheet", "css":
            setRequestType(contentType: ContentType.STYLESHEET, enabled: true)
        case "~stylesheet", "~css":
            setRequestType(contentType: ContentType.STYLESHEET, enabled: false)
        case "subdocument", "frame":
            setRequestType(contentType: ContentType.SUBDOCUMENT, enabled: true)
        case "~subdocument", "~frame":
            setRequestType(contentType: ContentType.SUBDOCUMENT, enabled: false)
        case "image":
            setRequestType(contentType: ContentType.IMAGE, enabled: true)
        case "~image":
            setRequestType(contentType: ContentType.IMAGE, enabled: false)
        case "xmlhttprequest", "xhr":
            setRequestType(contentType: ContentType.XMLHTTPREQUEST, enabled: true)
        case "~xmlhttprequest", "~xhr":
            setRequestType(contentType: ContentType.XMLHTTPREQUEST, enabled: false)
        case "media":
            setRequestType(contentType: ContentType.MEDIA, enabled: true)
        case "~media":
            setRequestType(contentType: ContentType.MEDIA, enabled: false)
        case "font":
            setRequestType(contentType: ContentType.FONT, enabled: true)
        case "~font":
            setRequestType(contentType: ContentType.FONT, enabled: false)
        case "websocket":
            self.isWebSocket = true
            setRequestType(contentType: ContentType.WEBSOCKET, enabled: true)
        case "~websocket":
            setRequestType(contentType: ContentType.WEBSOCKET, enabled: false)
        case "other":
            setRequestType(contentType: ContentType.OTHER, enabled: true)
        case "~other":
            setRequestType(contentType: ContentType.OTHER, enabled: false)
        case "ping":
            // `ping` resource type is supported since Safari 14
            if SafariService.current.version.isSafari14orGreater() {
                setRequestType(contentType: ContentType.PING, enabled: true)
            } else {
                throw SyntaxError.invalidModifier(message: "$ping is not supported")
            }
        case "~ping":
            // `ping` resource type is supported since Safari 14
            if SafariService.current.version.isSafari14orGreater() {
                setRequestType(contentType: ContentType.PING, enabled: false)
            } else {
                throw SyntaxError.invalidModifier(message: "$~ping is not supported")
            }
        default:
            throw SyntaxError.invalidModifier(message: "Unsupported modifier: \(optionName)")
        }

        if optionName != "domain" && optionValue != "" {
            throw SyntaxError.invalidModifier(message: "Option \(optionName) must not have value")
        }
    }

    private func setRequestType(contentType: ContentType, enabled: Bool) -> Void {
        if (enabled) {
            if (self.permittedContentType.firstIndex(of: ContentType.ALL) != nil) {
                self.permittedContentType = [];
            }

            self.permittedContentType.append(contentType)
        } else {
            self.restrictedContentType.append(contentType);
        }
    }

    private func setOptionEnabled(option: NetworkRuleOption, value: Bool) throws -> Void {
        // TODO: Respect options restrictions
        if (value) {
            self.enabledOptions.append(option);
        } else {
            self.disabledOptions.append(option);
        }
    }

    private func isOptionEnabled(option: NetworkRuleOption) -> Bool {
        return self.enabledOptions.firstIndex(of: option) != nil;
    }

    struct DomainInfo {
        var domain: String?;
        var path: String?;
    }

    enum ContentType {
        case ALL
        case IMAGE
        case STYLESHEET
        case SCRIPT
        case MEDIA
        case XMLHTTPREQUEST
        case OTHER
        case WEBSOCKET
        case FONT
        case DOCUMENT
        case SUBDOCUMENT
        case PING
    }

    enum NetworkRuleOption {
        case Elemhide
        case Generichide
        case Genericblock
        case Specifichide
        case Jsinject
        case Urlblock
        case Content
        case Document
    }
}
