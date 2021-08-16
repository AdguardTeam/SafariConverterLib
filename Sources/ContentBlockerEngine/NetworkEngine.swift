import Foundation

// Builds lookup tables:
// 1. domain -> ruleIdx
// 2. shortcut hash -> ruleIdx
// 3. no shortcuts indexes list
final class NetworkEngine: Codable {
    private var shortcutLength = 5

    private var domainsLookupTable = [UInt32: [Int]]()
    private var shortcutsLookupTable = [UInt32: [Int]]()
    private var shortcutsHistogram = [UInt32: Int]()
    private var otherRules = [Int]()

    // Adds rules to engine
    func addRules(rules: [BlockerRule]) {
        for i in 0..<rules.count {
            addRule(rule: rules[i], index: i)
        }
    }

    // Looking for matches in lookup tables
    func lookupRules(url: URL) -> [Int] {
        let absoluteUrl = url.absoluteString
        let host = url.host ?? ""

        // First check by shortcuts
        var result = matchShortcutsLookupTable(url: absoluteUrl)

        // Check domains lookup
        for index in matchDomainsLookupTable(host: host) {
            result.append(index)
        }

        // Add all other rules
        for index in otherRules {
            result.append(index)
        }

        return result
    }

    // matchDomainsLookupTable finds all matching rules from the domains lookup table
    private func matchDomainsLookupTable(host: String) -> [Int] {
        var result = [Int]()

        if host.isEmpty {
            return result
        }

        let domains = getSubdomains(hostname: host)
        for domain in domains {
            let hash = fastHash(str: domain)
            guard let rules = domainsLookupTable[hash] else {
                continue
            }

            for ruleIdx in rules {
                result.append(ruleIdx)
            }
        }
        return result
    }

    private func getSubdomains(hostname: String) -> [String] {
        let parts = hostname.split(separator: ".")
        var subdomains = [String]()
        var domain = ""
        for part in parts.reversed() {
            if domain.isEmpty {
                domain = String(part)
            } else {
                domain = part + "." + domain
            }
            subdomains.append(domain)
        }

        return subdomains
    }

    // matchShortcutsLookupTable finds all matching rules from the shortcuts lookup table
    private func matchShortcutsLookupTable(url: String) -> [Int] {
        var result: [Int] = []

        if (url.count < shortcutLength) {
            return result
        }

        for i in 0..<(url.count - shortcutLength) {
            let hash = fastHashBetween(str: url, begin: i, end: i + shortcutLength)
            guard let rules = shortcutsLookupTable[hash] else {
                continue
            }

            for ruleIdx in rules {
                result.append(ruleIdx)
            }
        }

        return result
    }

    // Adds rule to the network engine
    private func addRule(rule: BlockerRule, index: Int) {
        if !addRuleToShortcutsTable(rule: rule, index: index) {
            if !addRuleToDomainsTable(rule: rule, index: index) {
                if !otherRules.contains(index) {
                    otherRules.append(index)
                }
            }
        }
    }

    private func addRuleToShortcutsTable(rule: BlockerRule, index: Int) -> Bool {
        guard let shortcuts = getRuleShortcuts(rule: rule) else {
            return false
        }

        if shortcuts.isEmpty {
            return false
        }

        // Find the applicable shortcut (the least used)
        var shortcutHash: UInt32 = 0
        var minCount = Int.max
        for shortcutToCheck in shortcuts {
            let hash = fastHash(str: shortcutToCheck)
            var count = shortcutsHistogram[hash]
            if count == nil {
                count = 0
            }

            if count! < minCount {
                minCount = count!
                shortcutHash = hash
            }
        }

        // Increment the histogram
        shortcutsHistogram[shortcutHash] = minCount + 1

        // Add the rule to the lookup table
        var rulesIndexes = shortcutsLookupTable[shortcutHash]
        if rulesIndexes == nil {
            rulesIndexes = []
        }

        rulesIndexes!.append(index)
        shortcutsLookupTable[shortcutHash] = rulesIndexes

        return true
    }

    // getRuleShortcuts returns a list of shortcuts that can be used for the lookup table
    private func getRuleShortcuts(rule: BlockerRule) -> [String]? {
        guard let entryShortcut = rule.shortcut,
              entryShortcut.count >= shortcutLength,
              !isAnyURLShortcut(shortcut: entryShortcut) else {
            return nil
        }

        var shortcuts: [String] = []
        for i in 0..<(entryShortcut.count - shortcutLength + 1) {
            let start = entryShortcut.index(entryShortcut.startIndex, offsetBy: i)
            let end = entryShortcut.index(entryShortcut.startIndex, offsetBy: shortcutLength + i)
            let range = start..<end

            let mySubstring = entryShortcut[range]
            let shortcut = String(mySubstring)
            shortcuts.append(shortcut)
        }

        return shortcuts
    }

    // isAnyURLShortcut checks if the rule potentially matches too many URLs.
    // We'd better use another type of lookup table for this kind of rules.
    private func isAnyURLShortcut(shortcut: String) -> Bool {
        // Sorry for magic numbers
        // The numbers are basically ("PROTO://".length + 1)

        if shortcut.count < 6 && shortcut.starts(with: "ws:") {
            return true
        }

        if shortcut.count < 7 && shortcut.starts(with: "|ws") {
            return true
        }

        if shortcut.count < 9 && shortcut.starts(with: "http") {
            return true
        }

        if shortcut.count < 10 && shortcut.starts(with: "|http") {
            return true
        }

        return false
    }

    private func addRuleToDomainsTable(rule: BlockerRule, index: Int) -> Bool {
        guard let permittedDomains = rule.ifDomain, !permittedDomains.isEmpty else {
            return false
        }

        for domain in permittedDomains {
            var pattern = domain
            if domain.hasPrefix("*") {
                pattern = String(domain.dropFirst())
            }

            let hash = fastHash(str: pattern)

            // Add the rule to the lookup table
            var rulesIndexes = domainsLookupTable[hash] ?? []
            rulesIndexes.append(index)
            domainsLookupTable[hash] = rulesIndexes
        }

        return true
    }

    // Return hash function from string
    private func fastHashBetween(str: String, begin: Int, end: Int) -> UInt32 {
        let startIndex = str.index(str.startIndex, offsetBy: begin)
        let endIndex = str.index(str.startIndex, offsetBy: end)
        let range = startIndex..<endIndex

        let substring = String(str[range])
        // https://gist.github.com/kharrison/2355182ac03b481921073c5cf6d77a73#file-country-swift-L31
        let unicodeScalars = substring.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) {
          ($0 << 5) &+ $0 &+ UInt32($1)
        }
    }

    // Return hash function from string
    private func fastHash(str: String) -> UInt32 {
        if str == "" {
            return 0
        }

        return fastHashBetween(str: str, begin: 0, end: str.count)
    }
}
