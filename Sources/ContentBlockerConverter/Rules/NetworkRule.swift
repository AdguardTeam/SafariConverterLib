import Foundation

/**
 * Network rule class
 */
class NetworkRule: Rule {
    private static let MASK_WHITE_LIST = "@@";
    private static let DOMAIN_VALIDATION_REGEXP = try! NSRegularExpression(pattern: "^[a-zA-Z0-9][a-zA-Z0-9-.]*[a-zA-Z0-9]\\.[a-zA-Z-]{2,}$", options: [.caseInsensitive]);

    private static let delimeterChar = ",".utf16.first!;
    private static let escapeChar = "\\".utf16.first!;

    private static let NOOP_PATTERN = "_";

    var isUrlBlock = false;
    var isCssExceptionRule = false;
    var isJsInject = false;

    var urlRuleText: NSString = "";

    var isCheckThirdParty = false;
    var isThirdParty = false;
    var isMatchCase = false;
    var isBlockPopups = false;
    var isReplace = false;
    var isCspRule = false;
    var isWebSocket = false;

    var permittedContentType: [ContentType] = [ContentType.ALL];
    var restrictedContentType: [ContentType] = [];

    var enabledOptions: [NetworkRuleOption] = [];
    var disabledOptions: [NetworkRuleOption] = [];

    var urlRegExpSource: NSString? = nil;

    var badfilter: NSString? = nil;

    override init() {
        super.init();
    }

    override init(ruleText: NSString) throws {
        try super.init(ruleText: ruleText);

        let ruleParts = try NetworkRuleParser.parseRuleText(ruleText: ruleText as String);
        isWhiteList = ruleParts.whitelist;

        if (ruleParts.options != nil && ruleParts.options != "") {
            try loadOptions(options: ruleParts.options!);
        }

        if (ruleParts.pattern != nil) {
            if (ruleParts.pattern! == "||"
                    || ruleParts.pattern! == "*"
                    || ruleParts.pattern! == ""
                    || ruleParts.pattern!.unicodeScalars.count < 3
               ) {
                if (permittedDomains.count < 1) {
                    // Rule matches too much and does not have any domain restriction
                    // We should not allow this kind of rules
                    throw SyntaxError.invalidRule(message: "The rule is too wide, add domain restriction or make the pattern more specific");
                }
            }
        }

        if (ruleParts.options == "specifichide" && ruleParts.whitelist == false) {
            throw SyntaxError.invalidRule(message: "Specifichide modifier must be used for exception rules only");
        }

        urlRuleText = NetworkRuleParser.getAsciiDomainRule(pattern: ruleParts.pattern)! as NSString;

        if (isRegexRule()) {
            urlRegExpSource = urlRuleText.substring(with: NSMakeRange(1, urlRuleText.length - 2)) as NSString
        } else {
            if (urlRuleText != "") {
                urlRegExpSource = SimpleRegex.createRegexText(str: self.urlRuleText);
            }
        }

        isDocumentWhiteList = isOptionEnabled(option: .Document);
        isUrlBlock = isSingleOption(option: .Urlblock) || isSingleOption(option: .Genericblock);
        isCssExceptionRule = isSingleOption(option: .Elemhide) || isSingleOption(option: .Generichide);
        isJsInject = isSingleOption(option: .Jsinject);
    }

    func isRegexRule() -> Bool {
        urlRuleText.hasPrefix("/") && urlRuleText.hasSuffix("/")
    }

    func isSingleOption(option: NetworkRuleOption) -> Bool {
        enabledOptions.count == 1 && enabledOptions.firstIndex(of: option) != nil
    }

    func hasContentType(contentType: ContentType) -> Bool {
        if (permittedContentType == [ContentType.ALL] &&
                restrictedContentType.count == 0) {
            // Rule does not contain any constraint
            return true;
        }

        // Checking that either all content types are permitted or request content type is in the permitted list
        let matchesPermitted = permittedContentType == [ContentType.ALL] ||
                permittedContentType.firstIndex(of: contentType) ?? -1 >= 0;

        // Checking that either no content types are restricted or request content type is not in the restricted list
        let notMatchesRestricted = restrictedContentType.count == 0 ||
                restrictedContentType.firstIndex(of: contentType) == nil;

        return matchesPermitted && notMatchesRestricted;
    }

    func isContentType(contentType: ContentType) -> Bool {
        permittedContentType.count == 1 && permittedContentType[0] == contentType
    }

    func hasRestrictedContentType(contentType: ContentType) -> Bool {
        restrictedContentType.contains(contentType)
    }

    /**
     * Parses domain and path
     */
    func parseRuleDomain() -> DomainInfo? {
        let startsWith = [
            "http://www." as NSString,
            "https://www." as NSString,
            "http://" as NSString,
            "https://" as NSString,
            "||" as NSString,
            "//" as NSString
        ]
        let contains = ["/", "^"]

        var startIndex = 0

        for start in startsWith {
            // hasPrefix is bridged with NSString so no problem using Swift's String here
            if (urlRuleText.hasPrefix(start as String)) {
                startIndex = start.length
                break
            }
        }

        // Exclusive for domain
        let exceptRule = "domain="

        let optionsRange = urlRuleText.range(of: "$")
        let domainRange = urlRuleText.range(of: exceptRule)
        if (domainRange.location != NSNotFound && optionsRange.location != NSNotFound) {
            startIndex = domainRange.location + exceptRule.count
        }

        var pathEndIndex = optionsRange.location
        if (pathEndIndex == 0 || pathEndIndex == NSNotFound) {
            pathEndIndex = urlRuleText.length
        }

        let candidateStr = urlRuleText.substring(with: NSMakeRange(0, pathEndIndex)) as NSString
        var symbolIndex = NSNotFound
        for containsPrefix in contains {
            let cntsRange = candidateStr.range(
                    of: containsPrefix,
                    options: NSString.CompareOptions.literal,
                    range: NSMakeRange(startIndex, candidateStr.length - startIndex))
            let index = cntsRange.location
            if (index >= 0 && index != NSNotFound) {
                symbolIndex = index
                break
            }
        }

        let domain = symbolIndex == NSNotFound ?
                urlRuleText.substring(from: startIndex) :
                urlRuleText.substring(with: NSMakeRange(startIndex, symbolIndex - startIndex))

        let path = symbolIndex == NSNotFound ?
                nil :
                urlRuleText.substring(with: NSMakeRange(symbolIndex, pathEndIndex - symbolIndex))

        if (!SimpleRegex.isMatch(regex: NetworkRule.DOMAIN_VALIDATION_REGEXP, target: domain as NSString)) {
            // Not a valid domain name, ignore it
            return nil
        }

        return DomainInfo(domain: domain, path: path)
    };

    /**
    * Returns true if this rule negates the specified rule
    * Only makes sense when this rule has a `badfilter` modifier
    */
    func negatesBadfilter(specifiedRule: NetworkRule) -> Bool {
        if (isWhiteList != specifiedRule.isWhiteList) {
            return false;
        }

        if (urlRuleText != specifiedRule.urlRuleText) {
            return false;
        }

        if (permittedContentType != specifiedRule.permittedContentType) {
            return false;
        }

        if (restrictedContentType != specifiedRule.restrictedContentType) {
            return false;
        }

        if (enabledOptions != specifiedRule.enabledOptions) {
            return false;
        }

        if (disabledOptions != specifiedRule.disabledOptions) {
            return false;
        }

        if (restrictedDomains != specifiedRule.restrictedDomains) {
            return false;
        }

        if (!NetworkRule.stringArraysHaveIntersection(left: permittedDomains, right: specifiedRule.permittedDomains)) {
            return false;
        }

        return true;
    }

    /**
     * TODO: Move to Array extension
     */
    static func stringArraysHaveIntersection(left: [String], right: [String]) -> Bool {
        if (left.count == 0 || right.count == 0) {
            return true;
        }

        for elem in left {
            if (right.contains(elem)) {
                return true;
            }
        }

        return false;
    }
    
    /**
     * Parses source string and sets up permitted and restricted domains fields
     */
    private func setNetworkRuleDomains(domains: String) throws -> Void {
        if (domains == "") {
            throw SyntaxError.invalidRule(message: "Modifier $domain cannot be empty")
        }

        try setDomains(domains: domains, separator: Rule.VERTICAL_SEPARATOR)
    }

    private func loadOptions(options: String) throws -> Void {
        let optionParts = options.splitByDelimiterWithEscapeCharacter(delimiter: NetworkRule.delimeterChar, escapeChar: NetworkRule.escapeChar);

        for option in optionParts {
            var optionName = option;
            var optionValue = "";

            let valueIndex = option.indexOf(target: "=");
            if (valueIndex > 0) {
                optionName = option.subString(startIndex: 0, toIndex: valueIndex);
                optionValue = option.subString(startIndex: valueIndex + 1);
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

    private func loadOption(optionName: String, optionValue: String) throws -> Void {
        if (optionName.hasSuffix(NetworkRule.NOOP_PATTERN)) {
            // A noop modifier does nothing and can be used to increase some rules readability.
            // It consists of the sequence of underscore characters (_) of any length
            // and can appear in a rule as many times as it's needed.
            let isNoopOption = !optionName.components(separatedBy: NetworkRule.NOOP_PATTERN).contains {
                !$0.isEmpty
            };
            if (isNoopOption) {
                return;
            }
        }
        switch (optionName) {
        case "third-party",
             "~first-party":
            isCheckThirdParty = true;
            isThirdParty = true;
            break;
        case "~third-party",
             "first-party":
            isCheckThirdParty = true;
            isThirdParty = false;
            break;
        case "match-case":
            isMatchCase = true;
            break;
        case "~match-case":
            isMatchCase = false;
            break;
        case "important":
            isImportant = true;
            break;
        case "popup":
            isBlockPopups = true;
            break;
        case "badfilter":
            badfilter = parseBadfilter() as NSString?;
            break;
        case "csp":
            isCspRule = true;
            break;
        case "replace":
            isReplace = true;
            break;
        case "domain":
            try setNetworkRuleDomains(domains: optionValue);
            break;
        case "elemhide":
            try setOptionEnabled(option: NetworkRuleOption.Elemhide, value: true);
            break;
        case "generichide":
            try setOptionEnabled(option: NetworkRuleOption.Generichide, value: true);
            break;
        case "genericblock":
            try setOptionEnabled(option: NetworkRuleOption.Genericblock, value: true);
            break;
        case "specifichide":
            try setOptionEnabled(option: NetworkRuleOption.Specifichide, value: true);
            break;
        case "jsinject":
            try setOptionEnabled(option: NetworkRuleOption.Jsinject, value: true);
            break;
        case "urlblock":
            try setOptionEnabled(option: NetworkRuleOption.Urlblock, value: true);
            break;
        case "content":
            try setOptionEnabled(option: NetworkRuleOption.Content, value: true);
            break;
        case "document":
            try setOptionEnabled(option: NetworkRuleOption.Document, value: true);
            break;
        case "script":
            setRequestType(contentType: ContentType.SCRIPT, enabled: true);
            break;
        case "~script":
            setRequestType(contentType: ContentType.SCRIPT, enabled: false);
            break;
        case "stylesheet":
            setRequestType(contentType: ContentType.STYLESHEET, enabled: true);
            break;
        case "~stylesheet":
            setRequestType(contentType: ContentType.STYLESHEET, enabled: false);
            break;
        case "subdocument":
            setRequestType(contentType: ContentType.SUBDOCUMENT, enabled: true);
            break;
        case "~subdocument":
            setRequestType(contentType: ContentType.SUBDOCUMENT, enabled: false);
            break;
        case "object":
            setRequestType(contentType: ContentType.OBJECT, enabled: true);
            break;
        case "~object":
            setRequestType(contentType: ContentType.OBJECT, enabled: false);
            break;
        case "image":
            setRequestType(contentType: ContentType.IMAGE, enabled: true);
            break;
        case "~image":
            setRequestType(contentType: ContentType.IMAGE, enabled: false);
            break;
        case "xmlhttprequest":
            setRequestType(contentType: ContentType.XMLHTTPREQUEST, enabled: true);
            break;
        case "~xmlhttprequest":
            setRequestType(contentType: ContentType.XMLHTTPREQUEST, enabled: false);
            break;
        case "media":
            setRequestType(contentType: ContentType.MEDIA, enabled: true);
            break;
        case "~media":
            setRequestType(contentType: ContentType.MEDIA, enabled: false);
            break;
        case "font":
            setRequestType(contentType: ContentType.FONT, enabled: true);
            break;
        case "~font":
            setRequestType(contentType: ContentType.FONT, enabled: false);
            break;
        case "websocket":
            self.isWebSocket = true;
            setRequestType(contentType: ContentType.WEBSOCKET, enabled: true);
            break;
        case "~websocket":
            setRequestType(contentType: ContentType.WEBSOCKET, enabled: false);
            break;
        case "other":
            setRequestType(contentType: ContentType.OTHER, enabled: true);
            break;
        case "~other":
            setRequestType(contentType: ContentType.OTHER, enabled: false);
            break;
        case "object-subrequest":
            setRequestType(contentType: ContentType.OBJECT_SUBREQUEST, enabled: true);
            break;
        case "~object-subrequest":
            setRequestType(contentType: ContentType.OBJECT_SUBREQUEST, enabled: false);
            break;
        case "ping":
            // `ping` resource type is supported since Safari 14
            if SafariService.current.version.isSafari14orGreater() {
                setRequestType(contentType: ContentType.PING, enabled: true);
            } else {
                throw SyntaxError.invalidRule(message: "$ping option is not supported");
            }
            break;
        case "~ping":
            // `ping` resource type is supported since Safari 14
            if SafariService.current.version.isSafari14orGreater() {
                setRequestType(contentType: ContentType.PING, enabled: false);
            } else {
                throw SyntaxError.invalidRule(message: "$~ping option is not supported");
            }
            break;
        case "webrtc":
            setRequestType(contentType: ContentType.WEBRTC, enabled: true);
            break;
        case "~webrtc":
            setRequestType(contentType: ContentType.WEBRTC, enabled: false);
            break;
            
        default:
            throw SyntaxError.invalidRule(message: "Unknown option: \(optionName)");
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

    private func parseBadfilter() -> String {
        return self.ruleText
                .replacingOccurrences(of: "$badfilter,", with: "$")
                .replacingOccurrences(of: ",badfilter", with: "")
                .replacingOccurrences(of: "$badfilter", with: "");
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
        case OBJECT
        case OBJECT_SUBREQUEST
        case WEBRTC
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
