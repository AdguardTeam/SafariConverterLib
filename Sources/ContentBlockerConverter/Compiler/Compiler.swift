import Foundation

/// Compiler accepts a list of Rule objects (AdGuard rules representations)
/// and converts them to Safari content blocking format.
class Compiler {
    /// Max number of CSS selectors per rule.
    ///
    /// For more details take a look at `compactCssRules` at `compactDomainCssRules` functions.
    private static let MAX_SELECTORS_PER_RULE = 250

    private let blockerEntryFactory: BlockerEntryFactory

    /// Initializes Safari content blocker compiler.
    init(errorsCounter: ErrorsCounter, version: SafariVersion) {
        blockerEntryFactory = BlockerEntryFactory(
            errorsCounter: errorsCounter,
            version: version
        )
    }

    /// Compiles the list of AdGuard rules into an intermediate compilation result object
    /// that later will be converted to JSON.
    func compileRules(rules: [Rule], progress: Progress? = nil) -> CompilationResult {
        var shouldContinue: Bool {
            !(progress?.isCancelled ?? false)
        }

        // `css-display-none` rules will be post-processed after the first stage of conversion.
        var cssBlocking: [BlockerEntry] = []

        // A list of domains disabled by `$specifichide` rules.
        var specifichideExceptionDomains: [String] = []

        // Prepare the object that will be this function result.
        var compilationResult = CompilationResult()

        // Stage 1. Convert rules to content blocker entries.

        for rule in rules {
            if let networkRule = rule as? NetworkRule {
                if networkRule.isOptionEnabled(option: .specifichide) {
                    let res = NetworkRuleParser.extractDomain(pattern: networkRule.urlRuleText)
                    if !res.domain.isEmpty && !res.patternMatchesPath {
                        // Prepend wildcard as we'll be excluding wildcard domains.
                        specifichideExceptionDomains.append("*" + res.domain)

                        // There's no need to convert $specifichide rule.
                        continue
                    }
                }
            }

            guard let items = blockerEntryFactory.createBlockerEntries(rule: rule) else {
                continue
            }

            for item in items {
                switch item.action.type {
                case "block":
                    compilationResult.addBlockTypedEntry(entry: item, source: rule)
                case "css-display-none":
                    cssBlocking.append(item)
                case "ignore-previous-rules":
                    compilationResult.addIgnorePreviousTypedEntry(entry: item, rule: rule)
                default:
                    Logger.log(
                        "(ContentBlockerConverter) - Unexpected action type \(item.action.type)"
                    )
                }
            }
        }

        guard shouldContinue else { return CompilationResult() }

        // Stage 2. Compact cosmetic rules.

        let cssCompact = Compiler.compactCssRules(cssBlocking: cssBlocking)

        compilationResult.cssBlockingWide = cssCompact.cssBlockingWide
        compilationResult.cssBlockingDomainSensitive = cssCompact.cssBlockingDomainSensitive
        compilationResult.cssBlockingGenericDomainSensitive =
            cssCompact.cssBlockingGenericDomainSensitive

        guard shouldContinue else { return CompilationResult() }

        // Stage 3: Apply `$specifichide` exceptions.

        compilationResult.cssBlockingDomainSensitive = Compiler.applySpecifichide(
            blockingItems: &compilationResult.cssBlockingDomainSensitive,
            specifichideExceptions: specifichideExceptionDomains
        )

        return compilationResult
    }

    /// Applies `$specifichide` exceptions by removing the domain from other rules' `if-domain`.
    ///
    /// TODO: [ameshkov]: The algorithm is very ineffective, reconsider later.
    private static func applySpecifichide(
        blockingItems: inout [BlockerEntry],
        specifichideExceptions: [String]
    ) -> [BlockerEntry] {
        for index in 0..<blockingItems.count {
            var item = blockingItems[index]

            for exception in specifichideExceptions {
                if let ifDomain = item.trigger.ifDomain, ifDomain.contains(exception) {
                    item.trigger.ifDomain = ifDomain.filter {
                        $0 != exception
                    }
                }
            }

            blockingItems[index].trigger = item.trigger
        }

        var result: [BlockerEntry] = []

        for rule in blockingItems where !(rule.trigger.ifDomain?.isEmpty ?? false) {
            result.append(rule)
        }

        return result
    }

    private static func createWideRule(wideSelectors: [String]) -> BlockerEntry {
        return BlockerEntry(
            trigger: BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_COSMETIC_RULES),
            action: BlockerEntry.Action(
                type: "css-display-none",
                selector: wideSelectors.joined(separator: ", ")
            )
        )
    }

    /// Tries to compress CSS rules by combining generic rules into a single rule.
    ///
    /// The explanation below uses AdGuard rules syntax, but it still explains the idea well enough.
    ///
    /// For generic rules without domain limitations they're united into a single rule, i.e.
    /// ```
    /// ###banner
    /// ###ad
    /// ```
    ///
    /// Will be united into a single rule: `###banner,#ad`.
    ///
    /// Domain sensitive rules are compacted using the same approach:
    ///
    /// ```
    /// example.org###banner
    /// example.org###ad
    /// ```
    ///
    /// Becomes `example.org###banner,#ad`
    ///
    /// - Parameters:
    ///   - cssBlocking: A list of `css-display-none` content blocking rules that need to be converted.
    /// - Returns: an object with cosmetic rules split into three arrays (wide/generic/domain-sensitive)
    static func compactCssRules(cssBlocking: [BlockerEntry]) -> CompactCssRulesData {
        var cssBlockingWide: [BlockerEntry] = []
        var cssBlockingDomainSensitive: [BlockerEntry] = []
        var cssBlockingGenericDomainSensitive: [BlockerEntry] = []

        var wideSelectors: [String] = []

        for entry in cssBlocking {
            if let domains = entry.trigger.ifDomain, !domains.isEmpty {
                cssBlockingDomainSensitive.append(entry)
            } else if let domains = entry.trigger.unlessDomain, !domains.isEmpty {
                cssBlockingGenericDomainSensitive.append(entry)
            } else if let selector = entry.action.selector,
                entry.trigger.urlFilter == BlockerEntryFactory.URL_FILTER_COSMETIC_RULES
            {
                wideSelectors.append(selector)
                if wideSelectors.count >= MAX_SELECTORS_PER_RULE {
                    cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors))
                    wideSelectors = []
                }
            } else {
                cssBlockingWide.append(entry)
            }
        }

        if !wideSelectors.isEmpty {
            cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors))
        }

        // Now try to also compact domain-sensitive rules
        cssBlockingDomainSensitive = Compiler.compactDomainCssRules(
            entries: cssBlockingDomainSensitive
        )
        cssBlockingGenericDomainSensitive = Compiler.compactDomainCssRules(
            entries: cssBlockingGenericDomainSensitive
        )

        return CompactCssRulesData(
            cssBlockingWide: cssBlockingWide,
            cssBlockingDomainSensitive: cssBlockingDomainSensitive,
            cssBlockingGenericDomainSensitive: cssBlockingGenericDomainSensitive
        )
    }

    /// Compacts cosmetic rules for the same domain to one entry.
    ///
    /// For instance, if there're rules like these:
    /// ```
    /// example.org##.banner
    /// example.org##.otherbanner
    /// ```
    ///
    /// They will be essentially compacted to `example.org##.banner,.otherbanner`
    ///
    /// - Parameters:
    ///   - entries: Rules to compact.
    /// - Returns: the new compacted list of rules.
    static func compactDomainCssRules(entries: [BlockerEntry]) -> [BlockerEntry] {
        var result: [BlockerEntry] = []
        var domainsDictionary: [String: [BlockerEntry]] = [:]

        for entry in entries {
            let urlFilter = entry.trigger.urlFilter
            let ifDomain = entry.trigger.ifDomain
            let unlessDomain = entry.trigger.unlessDomain

            if let domains = ifDomain, domains.count == 1,
                urlFilter == BlockerEntryFactory.URL_FILTER_ANY_URL,
                unlessDomain?.isEmpty ?? true
            {
                let domain = domains[0]

                var current = domainsDictionary[domain] ?? []
                current.append(entry)
                domainsDictionary[domain] = current
            } else {
                // This entry cannot be compressed.
                result.append(entry)
            }
        }

        for domain in domainsDictionary.keys {
            guard let domainEntries = domainsDictionary[domain] else {
                continue
            }

            if domainEntries.count <= 1 {
                result.append(contentsOf: domainEntries)
                continue
            }

            let compactEntries = Compiler.createDomainWideEntries(
                domain: domain,
                domainEntries: domainEntries
            )
            result.append(contentsOf: compactEntries)
        }

        return result
    }

    /// Takes several rules that are limited to the same domain and compacts them
    /// by uniting these rules into a single entry.
    private static func createDomainWideEntries(
        domain: String,
        domainEntries: [BlockerEntry]
    ) -> [BlockerEntry] {
        var result: [BlockerEntry] = []

        let trigger = BlockerEntry.Trigger(ifDomain: [domain], urlFilter: ".*")

        let chunked = domainEntries.chunked(into: MAX_SELECTORS_PER_RULE)
        for chunk in chunked {
            var selectors: [String] = []
            for entry in chunk {
                if let selector = entry.action.selector {
                    selectors.append(selector)
                }
            }

            let wideRuleEntry = BlockerEntry(
                trigger: trigger,
                action: BlockerEntry.Action(
                    type: "css-display-none",
                    selector: selectors.joined(separator: ", ")
                )
            )

            result.append(wideRuleEntry)
        }

        return result
    }

    /// Represents the result of compacting `css-display-none` rules.
    struct CompactCssRulesData {
        var cssBlockingWide: [BlockerEntry]
        var cssBlockingDomainSensitive: [BlockerEntry]
        var cssBlockingGenericDomainSensitive: [BlockerEntry]
    }
}
