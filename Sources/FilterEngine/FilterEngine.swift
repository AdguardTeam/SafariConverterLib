import ContentBlockerConverter
import Foundation

/// FilterEngine is a class that's used for quickly looking up `FilterRule` objects
/// without keeping them in memory. In order to do that this class operates with rule
/// offsets from `FilterRuleStorage` and only keeps a cache of deserialized
/// `FilterRule` objects that's initialized lazily.
///
/// ## Internal structure
/// Internally, `FilterEngine` builds several `ByteArrayTrie` instances to
/// lookup rules that can be applied to the page. The key for the trie could be
/// a domain name or a shortcut, and the value is the rule's index from the storage.
///
/// ### Trie for domains
/// For each rule that has `permittedDomains` it builds a trie where it puts
/// each of these domain names and the rule index. These rules will be looked
/// up using this trie only and there's no need to extract their shortcuts.
///
/// ### Trie for shortcuts
/// For other rules it builds a shortcuts trie. For that it extracts shortcuts from
/// their `urlPattern` or from their `urlRegex` if these are regex rules,
/// i.e. if their `urlPattern` looks like `/regex/`.
///
/// ### Tail
/// Storage indexes of the rules that have neither `permittedDomains` nor
/// any shortcuts are placed in the tail array.
public class FilterEngine {
    /// Storage for filter rules. In order to save on RAM and initialization time, the rules are
    /// serialized into a binary format on the compilation step and after that we only operate
    /// UInt32 rule indices. The idea is that only a tiny share of all rules are actually required
    /// at runtime so we can safely keep other rules stored in a file. Whenever we actually
    /// need a rule, it can be quickly deserialized to `FilterRule`. This deserialized rule
    /// is then stored in the in-memory cache `rulesCache`.
    private let storage: FilterRuleStorage

    /// Cache for deserialized filter rules. This cache is used to avoid deserializing
    /// the same rule multiple times.
    private var rulesCache: [UInt32: FilterRule] = [:]
    private let rulesCacheLock = NSLock()

    /// Trie for domain lookups.
    ///
    /// This trie stores rule indices indexed by domain names from the rules' permittedDomains.
    /// When looking up rules for a URL, we extract all domain levels from the URL's host
    /// and use them to find matching rules in this trie.
    let domainTrie: ByteArrayTrie

    /// Trie for shortcuts (either extracted from urlPattern or urlRegex).
    ///
    /// This trie stores rule indices indexed by shortcuts extracted from the rules' patterns.
    /// When looking up rules for a URL, we scan the URL string character by character and
    /// use each suffix as a key to find matching rules in this trie.
    let shortcutsTrie: ByteArrayTrie

    /// Tail array contains indexes for rules that don't have permittedDomains or shortcuts.
    var tailIndices: [UInt32] = []

    /// Initializes a new FilterEngine instance with the given rule storage.
    ///
    /// This constructor builds the domain and shortcuts tries from scratch by iterating
    /// through all rules in the storage. Rules with permittedDomains are added to the domain trie,
    /// rules with shortcuts are added to the shortcuts trie, and rules with neither are added to the tail.
    public init(storage: FilterRuleStorage) throws {
        self.storage = storage

        let trieData = try FilterEngine.buildTries(from: storage)

        self.domainTrie = trieData.domainTrie
        self.shortcutsTrie = trieData.shortcutsTrie
        self.tailIndices = trieData.tailIndices
    }

    /// Initializes a new FilterEngine instance with the given rule storage and pre-built index file.
    ///
    /// This constructor reads the domain and shortcuts tries from an existing index file
    /// instead of building them from scratch. This is more efficient for subsequent launches
    /// as it avoids the expensive trie building process.
    public init(storage: FilterRuleStorage, indexFileURL: URL) throws {
        self.storage = storage

        let tries = try FilterEngine.readTries(from: indexFileURL)

        domainTrie = tries.domainTrie
        shortcutsTrie = tries.shortcutsTrie
        tailIndices = tries.tailIndices
    }
}

// MARK: - Selecting rules

extension FilterEngine {
    /// Represents intermediate match result.
    private struct MatchResult {
        public var networkRule: FilterRule?
        public var cosmeticRules: [FilterRule] = []
    }

    /// Finds all filter rules that match the given request.
    ///
    /// This method looks up rules in three different places:
    /// 1. The domain trie (for rules with permittedDomains)
    /// 2. The shortcuts trie (for rules with shortcuts)
    /// 3. The tail array (for rules with neither)
    ///
    /// It then filters the results to only include rules that match the URL
    /// and other conditions.
    public func findAll(for request: Request) -> [FilterRule] {
        let domainIndices = lookupDomainTrie(for: request.url)
        let shortcutIndices = lookupShortcutsTrie(for: request.url)

        var ruleIndices: [UInt32: Bool] = [:]
        var res: MatchResult = .init()

        addMatchingRules(
            for: request,
            from: domainIndices,
            except: &ruleIndices,
            to: &res
        )
        addMatchingRules(
            for: request,
            from: shortcutIndices,
            except: &ruleIndices,
            to: &res
        )
        addMatchingRules(
            for: request,
            from: tailIndices,
            except: &ruleIndices,
            to: &res
        )

        return filterMatchResult(result: res)
    }

    /// Filters cosmetic rules from match result and removes rules
    /// that are disabled by network rule or negated.
    private func filterMatchResult(result: MatchResult) -> [FilterRule] {
        var filteredCosmeticRules: [FilterRule] = []

        if let action = result.networkRule?.action, !result.cosmeticRules.isEmpty {
            for rule in result.cosmeticRules where isRuleEnabled(cosmeticRule: rule, action: action)
            {
                filteredCosmeticRules.append(rule)
            }
        } else if result.networkRule?.action == nil {
            filteredCosmeticRules = result.cosmeticRules
        }

        return filteredCosmeticRules
    }

    /// Returns false if the specified cosmetic rule is disabled by the action.
    ///
    /// For instance, `##.banner` will be disabled by `@@||example.org^$elemhide` on `example.org`.
    private func isRuleEnabled(cosmeticRule: FilterRule, action: Action) -> Bool {
        let isCSS =
            cosmeticRule.action.contains(.cssDisplayNone)
            || cosmeticRule.action.contains(.cssInject)
        let isScript =
            cosmeticRule.action.contains(.scriptInject) || cosmeticRule.action.contains(.scriptlet)

        if isCSS && action.contains(.disableCSS) {
            return false
        }

        if isScript && action.contains(.disableScript) {
            return false
        }

        let isGeneric = cosmeticRule.permittedDomains.isEmpty

        if isCSS && action.contains(.disableGenericCSS) && isGeneric {
            return false
        }

        if isCSS && action.contains(.disableSpecificCSS) && !isGeneric {
            return false
        }

        return true
    }

    /// Looks up `FilterRule` by their indices, checks if the rule matches the page URL and
    /// if it does, adds this rule to the resulting array. It also avoids adding duplicate rules by keeping
    /// track of what's added in `ruleIndices`.
    private func addMatchingRules(
        for request: Request,
        from indices: [UInt32],
        except ruleIndices: inout [UInt32: Bool],
        to result: inout MatchResult
    ) {
        for index in indices {
            if ruleIndices[index] != nil {
                continue
            }

            do {
                let rule = try getRule(by: index)
                if !ruleMatches(
                    rule: rule,
                    request: request
                ) {
                    continue
                }

                // Keep track of added rules.
                ruleIndices[index] = true

                switch rule.action {
                case _ where !rule.action.isDisjoint(with: .network):
                    if result.networkRule == nil
                        || rule.priority >= (result.networkRule?.priority ?? 0)
                    {
                        result.networkRule = rule
                    }
                case _ where !rule.action.isDisjoint(with: .cosmetic):
                    result.cosmeticRules.append(rule)
                default:
                    Logger.log("Found a rule that cannot be evaluated by the engine")
                    continue
                }
            } catch {
                Logger.log("Encountered a corrupted rule with index \(index): \(error)")
            }
        }
    }

    /// Looks up rules in the shortcuts trie.
    ///
    /// Note, that the resulting array may contain duplicates, they need to be dealt with elsewhere.
    private func lookupShortcutsTrie(for url: URL) -> [UInt32] {
        let urlString = url.absoluteString
        let utf8 = urlString.utf8
        var matchingIndices: [UInt32] = []

        var i = utf8.startIndex
        while i < utf8.endIndex {
            let suffix = urlString[i...]
            let indices = shortcutsTrie.collectPayload(word: suffix)
            matchingIndices.append(contentsOf: indices)

            i = utf8.index(after: i)
        }

        return matchingIndices
    }

    /// Looks up rules in the domain trie.
    ///
    /// Note, that the resulting array may contain duplicates, they need to be dealt with elsewhere.
    private func lookupDomainTrie(for url: URL) -> [UInt32] {
        var matchingIndices: [UInt32] = []
        let hostnames = FilterEngine.extractHostnames(from: url)

        for hostname in hostnames {
            let indices = domainTrie.collectPayload(word: hostname)
            matchingIndices.append(contentsOf: indices)
        }

        return matchingIndices
    }

    /// Gets rule from the rules storage by its index.
    ///
    /// This function first checks the in-memory cache and only if the rule is not found there,
    /// it reads it from the storage. The deserialized rule is then cached for future use.
    ///
    /// This function can throw a `FilterRuleStorageError` if it fails to read
    /// the rule from the storage.
    private func getRule(by index: UInt32) throws -> FilterRule {
        // First, try to get the rule from the cache under lock
        rulesCacheLock.lock()
        if let cachedRule = rulesCache[index] {
            rulesCacheLock.unlock()
            return cachedRule
        }
        rulesCacheLock.unlock()

        // If not found in cache, read from storage
        let ruleIndex = FilterRuleStorage.Index(offset: index)
        let rule = try storage[ruleIndex]

        // Cache the rule for future use under lock
        rulesCacheLock.lock()
        rulesCache[index] = rule
        rulesCacheLock.unlock()

        return rule
    }
}

// MARK: - Match individual rule

extension FilterEngine {
    /// Checks if the given rule matches the specified URL.
    private func ruleMatches(
        rule: FilterRule,
        request: Request
    ) -> Bool {
        // 1. Make sure the URL has a host
        let host = FilterEngine.host(from: request.url)
        if host.isEmpty {
            return false
        }

        // 2. Check "permittedDomains"
        //    If rule.permittedDomains is not empty, the URL host must match (or be a subdomain of)
        //    at least one of the permitted domains.
        if !rule.permittedDomains.isEmpty {
            let isHostPermitted = rule.permittedDomains.contains { domain in
                return DomainUtils.isDomainOrSubdomain(candidate: host, domain: domain)
            }
            if !isHostPermitted {
                return false
            }
        }

        // 3. Check "restrictedDomains"
        //    If the URL host matches (or is a subdomain of) any of the restricted domains, the rule does not match.
        let isHostRestricted = rule.restrictedDomains.contains { domain in
            return DomainUtils.isDomainOrSubdomain(candidate: host, domain: domain)
        }
        if isHostRestricted {
            return false
        }

        // 4. Check thirdParty
        if let ruleThirdParty = rule.thirdParty, ruleThirdParty != request.thirdParty {
            return false
        }

        // 5. Check subdocument
        if let ruleSubdocument = rule.subdocument, ruleSubdocument != request.subdocument {
            return false
        }

        // 6. Check urlRegex
        //    If urlRegex is not specified, *any* URL is considered valid.
        if let urlRegex = rule.urlRegex {
            guard let regex = RegexCache.regex(for: urlRegex) else {
                // If the regex could not be compiled, consider it as no match
                return false
            }
            let urlString = request.url.absoluteString
            let range = NSRange(location: 0, length: urlString.utf16.count)
            // If there is no match, return false
            if regex.firstMatch(in: urlString, options: [], range: range) == nil {
                return false
            }
        }

        // 7. Check pathRegex
        //    If pathRegex is specified, it is tested against the path + query string, e.g. "/path?p=1".
        if let pathRegex = rule.pathRegex {
            guard let regex = RegexCache.regex(for: pathRegex) else {
                // If the regex could not be compiled, consider it as no match
                return false
            }

            // Combine path and query
            var pathAndQuery = request.url.path
            if let query = request.url.query, !query.isEmpty {
                pathAndQuery += "?\(query)"
            }

            let range = NSRange(location: 0, length: pathAndQuery.utf16.count)
            if regex.firstMatch(in: pathAndQuery, options: [], range: range) == nil {
                return false
            }
        }

        // If all checks pass, the rule matches
        return true
    }

    /// A helper structure for caching compiled NSRegularExpression objects.
    private enum RegexCache {
        static var invalidRegexes: [String: Bool] = [:]
        static var cache: [String: NSRegularExpression] = [:]

        /// Returns a compiled NSRegularExpression for the given pattern.
        /// If it has been previously compiled, returns the cached instance.
        static func regex(for pattern: String) -> NSRegularExpression? {
            if let cached = cache[pattern] {
                return cached
            }

            // Do not waste time on attempts to recompile invalid regexes.
            if invalidRegexes[pattern] != nil {
                return nil
            }

            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                cache[pattern] = regex

                return regex
            } catch {
                Logger.log("Failed to compile regex \(pattern)")

                // Save invalid regex in the dictionary to avoid compiling it again.
                invalidRegexes[pattern] = true

                return nil
            }
        }
    }
}

// MARK: - Trie initialization

extension FilterEngine {
    /// A simple struct for holding tries data.
    private struct TrieData {
        let domainTrie: ByteArrayTrie
        let shortcutsTrie: ByteArrayTrie
        let tailIndices: [UInt32]
    }

    /// Builds the domain and shortcuts tries from the given rule storage.
    ///
    /// This method iterates through all rules in the storage and:
    /// 1. Adds rules with permittedDomains to the domain trie
    /// 2. Adds rules with shortcuts to the shortcuts trie
    /// 3. Adds rules with neither to the tail array
    ///
    /// It also builds a histogram of shortcut usage to select the best shortcut for each rule.
    private static func buildTries(
        from storage: FilterRuleStorage
    ) throws -> TrieData {
        let domainTrieRoot = TrieNode()
        let shortcutsTrieRoot = TrieNode()
        var tailIndices: [UInt32] = []
        var shortcutsHistogram: [String: Int] = [:]

        // Iterate through all stored rules to build the tries and the tail array.
        let iterator = try storage.makeIterator()
        while let (ruleIndex, rule) = iterator.next() {
            if !rule.permittedDomains.isEmpty {
                // Insert each permitted domain into the domain trie.
                for domain in rule.permittedDomains {
                    domainTrieRoot.insert(word: domain, payload: [ruleIndex.offset])
                }
            } else {
                // If there are no permitted domains, attempt to extract shortcuts.
                let shortcuts: [String]
                if SimpleRegex.isRegexPattern(rule.urlPattern),
                    let urlRegex = rule.urlRegex
                {
                    shortcuts = FilterRule.extractRegexShortcuts(from: urlRegex)
                } else {
                    shortcuts = FilterRule.extractShortcuts(from: rule.urlPattern)
                }

                if !shortcuts.isEmpty {
                    let shortcut = selectBestShortcut(
                        shortcuts: shortcuts,
                        shortcutsHistogram: shortcutsHistogram
                    )
                    // Increment the usage of the chosen shortcut
                    shortcutsHistogram[shortcut, default: 0] += 1

                    shortcutsTrieRoot.insert(word: shortcuts[0], payload: [ruleIndex.offset])
                } else {
                    // If no permitted domains or shortcuts, it goes into the tail array.
                    tailIndices.append(ruleIndex.offset)
                }
            }
        }

        let domainTrie = ByteArrayTrie(from: domainTrieRoot)
        let shortcutsTrie = ByteArrayTrie(from: shortcutsTrieRoot)

        return TrieData(
            domainTrie: domainTrie,
            shortcutsTrie: shortcutsTrie,
            tailIndices: tailIndices
        )
    }

    /// This is a helper function that helps us choose the best search shortcut among available.
    /// In order to do this we build a histogram and select the least used shortcut among
    /// available. If there are several shortcuts that have the same usage count, we'll select
    /// the longest one.
    private static func selectBestShortcut(
        shortcuts: [String],
        shortcutsHistogram: [String: Int]
    ) -> String {
        var leastUsedShortcut = shortcuts[0]
        var leastUsageCount = shortcutsHistogram[leastUsedShortcut, default: 0]

        // Find the shortcut with the smallest usage count
        for shortcut in shortcuts.dropFirst() {
            let usageCount = shortcutsHistogram[shortcut, default: 0]
            if usageCount < leastUsageCount {
                leastUsedShortcut = shortcut
                leastUsageCount = usageCount
            } else if usageCount == leastUsageCount
                && leastUsedShortcut.utf8.count < shortcut.utf8.count
            {
                leastUsedShortcut = shortcut
            }
        }

        // Return the "best" (least-used) shortcut
        return leastUsedShortcut
    }
}

// MARK: - Helper functions

extension FilterEngine {
    private static func host(from url: URL) -> String {
        if #available(macOS 13.0, iOS 16.0, *) {
            return url.host() ?? ""
        } else {
            // Fallback on earlier versions
            return url.host ?? ""
        }
    }

    /// Extracts hostnames of all levels from the URL.
    ///
    /// For example, if the url is `https://example.org/`, it will return `['example.org', 'org']`.
    private static func extractHostnames(from url: URL) -> [String] {
        let host = FilterEngine.host(from: url)

        if host.isEmpty {
            return []
        }

        var hostnames: [String] = []
        hostnames.append(host)

        let parts = host.split(separator: ".")
        if parts.count == 1 {
            return hostnames
        }

        for i in 1..<parts.count {
            let domain = parts[i...].joined(separator: ".")
            hostnames.append(domain)
        }

        return hostnames
    }
}
