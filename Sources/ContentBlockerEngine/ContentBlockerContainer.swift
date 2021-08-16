import Foundation
import ContentBlockerConverter

// Storage and parser
final class ContentBlockerContainer: Codable {
    private var blockerRules: [BlockerRule] = []
    private var networkEngine = NetworkEngine()

    enum ContentBlockerError: Error, CustomDebugStringConvertible {
        case invalidJson(json: String)

        var debugDescription: String {
            switch self {
            case .invalidJson(let json): return "Invalid JSON: \(json)"
            }
        }
    }

    // Parses json and initializes engine
    func setJson(json: String) throws {
        // Parse "content-blocker" json
        let blockerEntries = try parseJsonString(json: json)

        // Parse shortcuts
        for blockerEntry in blockerEntries {
            let blockerRule = BlockerRule(
                ifDomain: blockerEntry.trigger.ifDomain,
                urlFilter: blockerEntry.trigger.urlFilter,
                unlessDomain: blockerEntry.trigger.unlessDomain,
                shortcut: parseShortcut(urlMask: blockerEntry.trigger.urlFilter),
                type: blockerEntry.action.type,
                css: blockerEntry.action.css,
                script: blockerEntry.action.script,
                scriptlet: blockerEntry.action.scriptlet,
                scriptletParam: blockerEntry.action.scriptletParam
            )

            blockerRules.append(blockerRule)
        }

        // Init network engine
        networkEngine = NetworkEngine()
        networkEngine.addRules(rules: blockerRules)
    }

    // Parses url shortcuts
    private func parseShortcut(urlMask: String?) -> String? {
        // Skip empty string
        guard let mask = urlMask, !mask.isEmpty else {
            return nil
        }

        // Skip all url templates
        if mask == ".*" || mask == "^[htpsw]+://" {
            return nil
        }

        let shortcut: String?
        let isRegexRule = mask.hasPrefix("/") && mask.hasSuffix("/")
        if isRegexRule {
            shortcut = findRegexpShortcut(pattern: mask)
        } else {
            shortcut = findShortcut(pattern: mask)
        }

        // shortcut needs to be at least longer than 1 character
        if let shortcut = shortcut, shortcut.count > 1 {
            return shortcut
        } else {
            return nil
        }
    }

    // findRegexpShortcut searches for a shortcut inside of a regexp pattern.
    // Shortcut in this case is a longest string with no REGEX special characters
    // Also, we discard complicated regexps right away.
    private func findRegexpShortcut(pattern: String) -> String? {
        // strip backslashes
        var mask = String(pattern.dropFirst(1).dropLast(1))

        // Do not mess with complex expressions which use lookahead
        guard !(mask.contains("(?") || mask.contains("(!?")) else {
            return nil
        }

        // placeholder for a special character
        let specialCharacter = "$$$"

        // (Dirty) prepend specialCharacter for the following replace calls to work properly
        mask = specialCharacter + mask

        // Strip all types of brackets
        var regex = try! NSRegularExpression(pattern: "[^\\\\]\\(.*[^\\\\]\\)", options: .caseInsensitive)
        mask = regex.stringByReplacingMatches(
            in: mask,
            options: [],
            range: NSRange(location: 0, length: mask.count),
            withTemplate: specialCharacter
        )

        regex = try! NSRegularExpression(pattern: "[^\\\\]\\[.*[^\\\\]\\]", options: .caseInsensitive)
        mask = regex.stringByReplacingMatches(
            in: mask,
            options: [],
            range: NSRange(location: 0, length: mask.count),
            withTemplate: specialCharacter
        )

        regex = try! NSRegularExpression(pattern: "[^\\\\]\\{.*[^\\\\]\\}", options: .caseInsensitive)
        mask = regex.stringByReplacingMatches(
            in: mask,
            options: [],
            range: NSRange(location: 0, length: mask.count),
            withTemplate: specialCharacter
        )

        // Strip some special characters (\n, \t etc)
        regex = try! NSRegularExpression(pattern: "[^\\\\]\\\\[a-zA-Z]", options: .caseInsensitive)
        mask = regex.stringByReplacingMatches(
            in: mask,
            options: [],
            range: NSRange(location: 0, length: mask.count),
            withTemplate: specialCharacter
        )

        // replace "\." with "."
        regex = try! NSRegularExpression(pattern: "\\\\.", options: .caseInsensitive)
        mask = regex.stringByReplacingMatches(
            in: mask,
            options: [],
            range: NSRange(location: 0, length: mask.count),
            withTemplate: "."
        )

        let parts = mask.components(separatedBy: ["*", "^", "|", "+", "?", "$", "[", "]", "(", ")", "{", "}"])

        let longest = parts.max { $0.count < $1.count } ?? ""

        return !longest.isEmpty ? longest.lowercased() : nil
    }

    // Searches for the longest substring of the pattern that
    // does not contain any special characters: *,^,|.
    private func findShortcut(pattern: String) -> String? {
        let parts = pattern.components(separatedBy: ["*", "^", "|"])
        let longest = parts.max { $0.count < $1.count } ?? ""

        return !longest.isEmpty ? longest.lowercased() : nil
    }

    // Returns scripts and css wrapper object for current url
    func getData(url: URL) throws -> BlockerData {
        let blockerData = BlockerData()

        // Check lookup tables
        var selectedIndexes = networkEngine.lookupRules(url: url)
        selectedIndexes.sort()

        // Get entries for indexes
        let selectedRules = selectedIndexes.map { blockerRules[$0] }

        // Iterate reversed to apply actions or ignore next rules
        for var rule in selectedRules.reversed() {
            if isRuleTriggered(rule: &rule, url: url) {
                if rule.type == "ignore-previous-rules" {
                    return blockerData
                } else {
                    addActionContent(blockerData: blockerData, blockerRule: rule)
                }
            }
        }

        return blockerData
    }

    // Checks if trigger content is suitable for current url
    private func isRuleTriggered(rule: inout BlockerRule, url: URL) -> Bool {
        let host = url.host
        let absoluteUrl = url.absoluteString

        if let urlFilter = rule.urlFilter, !urlFilter.isEmpty {
            if let shortcut = rule.shortcut {
                if (absoluteUrl.lowercased().contains(shortcut)) {
                    return true
                }
            }

            if host == nil || !checkDomains(rule: rule, host: host!) {
                return false
            }

            return matchesUrlFilter(text: absoluteUrl, rule: &rule)
        }

        return false
    }

    // Checks if trigger domain's fields matches current host
    private func checkDomains(rule: BlockerRule, host: String) -> Bool {
        let permittedDomains = rule.ifDomain
        let restrictedDomains = rule.unlessDomain

        let permittedDomainsEmpty = permittedDomains == nil || permittedDomains!.isEmpty
        let restrictedDomainsEmpty = restrictedDomains == nil || restrictedDomains!.isEmpty

        if permittedDomainsEmpty && restrictedDomainsEmpty {
            return true
        }

        if !restrictedDomainsEmpty && permittedDomainsEmpty {
            return !matchesDomains(domainPatterns: restrictedDomains!, domain: host)
        }

        if restrictedDomainsEmpty && !permittedDomainsEmpty {
            return matchesDomains(domainPatterns: permittedDomains!, domain: host)
        }

        return matchesDomains(domainPatterns: permittedDomains!, domain: host) && !matchesDomains(domainPatterns: restrictedDomains!, domain: host)
    }

    // Checks if domain matches at least one domain pattern
    private func matchesDomains(domainPatterns: [String], domain: String) -> Bool {
        for pattern in domainPatterns {
            if domain == pattern {
                return true
            }

            // If pattern starts with '*' - it matches sub domains
            if !pattern.isEmpty
                    && domain.hasSuffix(String(pattern.dropFirst(1)))
                    && pattern.hasPrefix("*") {
                return true
            }
        }

        return false
    }

    // Checks if text matches specified trigger
    // Checks url-filter or cached regexp
    private func matchesUrlFilter(text: String, rule: inout BlockerRule) -> Bool {
        let pattern = rule.urlFilter

        if pattern == ".*" || pattern == "^[htpsw]+:\\/\\/" {
            return true
        }

        if rule.regex == nil {
            return text.range(of: pattern!, options: .regularExpression, range: nil, locale: nil) != nil
        } else {
            let numberOfMatches = rule.regex!.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
            return numberOfMatches > 0
        }
    }

    // Adds scripts or css to blocker data object
    private func addActionContent(blockerData: BlockerData, blockerRule: BlockerRule) {
        if blockerRule.type == "css-extended" {
            blockerData.addCssExtended(style: blockerRule.css)
        } else if blockerRule.type == "css-inject" {
            blockerData.addCssInject(style: blockerRule.css)
        } else if blockerRule.type == "script" {
            blockerData.addScript(script: blockerRule.script)
        } else if blockerRule.type == "scriptlet" {
            blockerData.addScriptlet(scriptlet: blockerRule.scriptletParam)
        }
    }

    // Parses json to objects array
    private func parseJsonString(json: String) throws -> [BlockerEntry] {
        guard let data = json.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            throw ContentBlockerError.invalidJson(json: json)
        }

        let decoder = JSONDecoder()
        let parsedData = try decoder.decode([BlockerEntry].self, from: data)

        return parsedData
    }
}
