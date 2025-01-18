import Foundation

/// Compiler accepts a list of Rule objects (AdGuard rules representations)
/// and converts them to Safari content blocking format.
class Compiler {
    /// Max number of CSS selectors per rule (look at compactCssRules function).
    private static let MAX_SELECTORS_PER_WIDE_RULE = 250
    private static let MAX_SELECTORS_PER_DOMAIN_RULE = 250

    /// Cosmetic rule actions.
    ///
    /// "css-display-none" is natively supported by Safari, other types are custom
    /// actions that can only be supported by a different Safari extension.
    private static let COSMETIC_ACTIONS: [String] = [
        "css-display-none",
        "css-inject",
        "css-extended",
        "scriptlet",
        "script",
    ]

    private let optimize: Bool
    private let advancedBlockedEnabled: Bool

    private let blockerEntryFactory: BlockerEntryFactory

    /// Initializes Safari content blocker compiler.
    init(
            optimize: Bool,
            advancedBlocking: Bool,
            errorsCounter: ErrorsCounter,
            version: SafariVersion
    ) {
        self.optimize = optimize
        advancedBlockedEnabled = advancedBlocking
        blockerEntryFactory = BlockerEntryFactory(
            advancedBlockingEnabled: advancedBlocking,
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

        var cssBlocking = [BlockerEntry]()
        var cssExceptions = [BlockerEntry]()

        var cssInjects = [BlockerEntry]()
        var extendedCssBlocking = [BlockerEntry]()
        var scriptRules = [BlockerEntry]()
        var scriptExceptionRules = [BlockerEntry]()
        var scriptlets = [BlockerEntry]()
        var scriptletsExceptions = [BlockerEntry]()
        var cosmeticCssExceptions = [BlockerEntry]()

        // A list of domains disabled by $specifichide rules.
        var specifichideExceptionDomains = [String]()

        var compilationResult = CompilationResult()
        compilationResult.rulesCount = rules.count

        for rule in rules {
            guard shouldContinue else { return CompilationResult() }

            if rule is NetworkRule {
                let networkRule = rule as! NetworkRule

                if networkRule.isOptionEnabled(option: .specifichide) {
                    let res = NetworkRuleParser.extractDomain(pattern: networkRule.urlRuleText)
                    if res.domain != "" && !res.patternMatchesPath {
                        // Prepend wildcard as we'll be excluding wildcard domains.
                        specifichideExceptionDomains.append("*" + res.domain)

                        // There's no need to convert $specifichide rule.
                        continue
                    }
                }
            }

            guard let item = blockerEntryFactory.createBlockerEntry(rule: rule) else { continue }

            if item.action.type == "block" {
                compilationResult.addBlockTypedEntry(entry: item, source: rule)
            } else if item.action.type == "css-display-none" {
                cssBlocking.append(item)
            } else if item.action.type == "css-inject" {
                cssInjects.append(item)
            } else if item.action.type == "css-extended" {
                extendedCssBlocking.append(item)
            } else if item.action.type == "scriptlet" {
                scriptlets.append(item)
            } else if item.action.type == "script" {
                scriptRules.append(item)
            } else if item.action.type == "ignore-previous-rules" {
                // Exceptions
                if rule.isScriptlet {
                    // #@%#//scriptlet
                    scriptletsExceptions.append(item)
                } else if rule.isScript {
                    // #@%# rules
                    scriptExceptionRules.append(item)
                } else if item.action.selector != nil && item.action.selector! != "" {
                    // #@# rules
                    cssExceptions.append(item)
                } else if item.action.css != nil && item.action.css! != "" {
                    cosmeticCssExceptions.append(item)
                } else {
                    compilationResult.addIgnorePreviousTypedEntry(entry: item, rule: rule)
                }
            }
        }

        guard shouldContinue else { return CompilationResult() }

        // Compacting cosmetic rules.
        let cssCompact = Compiler.compactCssRules(cssBlocking: cssBlocking)
        if !optimize {
            compilationResult.cssBlockingWide = cssCompact.cssBlockingWide
        }

        compilationResult.cssBlockingGenericDomainSensitive = Compiler.compactDomainCssRules(
            entries: cssCompact.cssBlockingGenericDomainSensitive,
            useUnlessDomain: true
        )

        compilationResult.cssBlockingDomainSensitive = Compiler.compactDomainCssRules(
            entries: cssCompact.cssBlockingDomainSensitive
        )

        guard shouldContinue else { return CompilationResult() }

        // Apply specifichide exceptions
        compilationResult.cssBlockingDomainSensitive = Compiler.applySpecifichide(
            blockingItems: &compilationResult.cssBlockingDomainSensitive,
            specifichideExceptions: specifichideExceptionDomains)

        guard shouldContinue else { return CompilationResult() }

        if advancedBlockedEnabled {
            guard shouldContinue else { return CompilationResult() }

            let extendedCssCompact = Compiler.compactCssRules(cssBlocking: extendedCssBlocking)
            if (!optimize) {
                compilationResult.extendedCssBlockingWide = extendedCssCompact.cssBlockingWide
            }
            compilationResult.extendedCssBlockingGenericDomainSensitive = extendedCssCompact.cssBlockingGenericDomainSensitive
            compilationResult.extendedCssBlockingDomainSensitive = extendedCssCompact.cssBlockingDomainSensitive

            // Apply specifichide exceptions for extended css rules
            compilationResult.extendedCssBlockingDomainSensitive = Compiler.applySpecifichide(blockingItems: &compilationResult.extendedCssBlockingDomainSensitive, specifichideExceptions: specifichideExceptionDomains)


            // Apply specifichide exceptions for css injecting rules
            compilationResult.сssInjects = Compiler.applySpecifichide(blockingItems: &cssInjects, specifichideExceptions: specifichideExceptionDomains)

            compilationResult.script = scriptRules
            compilationResult.scriptlets = scriptlets
        }

        return compilationResult
    }

    /// Applies $specifichide exceptions by removing the domain from other rules' `if-domain`.
    ///
    /// TODO: [ameshkov]: The algorithm is very ineffective, reconsider later.
    private static func applySpecifichide(
        blockingItems: inout [BlockerEntry],
        specifichideExceptions: [String]
    ) -> [BlockerEntry] {
        for index in 0..<blockingItems.count {
            var item = blockingItems[index]

            for exception in specifichideExceptions {
                if (item.trigger.ifDomain?.contains(exception) != nil) {
                    item.trigger.ifDomain = item.trigger.ifDomain!.filter {
                        $0 != exception
                    }
                }
            }

            blockingItems[index].trigger = item.trigger
        }

        var result = [BlockerEntry]()

        for r in blockingItems {
            // skip entries with excluded ifDomain
            if (r.trigger.ifDomain?.count == 0) {
                continue
            }
            result.append(r)
        }

        return result
    }

    private static func createWideRule(wideSelectors: [String]) -> BlockerEntry {
        return BlockerEntry(
            trigger: BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_COSMETIC_RULES),
            action: BlockerEntry.Action(type: "css-display-none", selector: wideSelectors.joined(separator: ", "))
        )
    }

    /// Tries to compress CSS rules by combining generic rules into a single rule.
    static func compactCssRules(cssBlocking: [BlockerEntry]) -> CompactCssRulesData {
        var cssBlockingWide = [BlockerEntry]()
        var cssBlockingDomainSensitive = [BlockerEntry]()
        var cssBlockingGenericDomainSensitive = [BlockerEntry]()

        var wideSelectors = [String]()

        for entry in cssBlocking {
            if (entry.trigger.ifDomain != nil) {
                cssBlockingDomainSensitive.append(entry)
            } else if (entry.trigger.unlessDomain != nil) {
                cssBlockingGenericDomainSensitive.append(entry)
            } else if (entry.action.selector != nil && entry.trigger.urlFilter == BlockerEntryFactory.URL_FILTER_COSMETIC_RULES) {
                wideSelectors.append(entry.action.selector!)
                if (wideSelectors.count >= Compiler.MAX_SELECTORS_PER_WIDE_RULE) {
                    cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors))
                    wideSelectors = [String]()
                }
            } else {
                cssBlockingWide.append(entry)
            }
        }

        if (wideSelectors.count > 0) {
            cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors))
        }

        return CompactCssRulesData(
                cssBlockingWide: cssBlockingWide,
                cssBlockingDomainSensitive: cssBlockingDomainSensitive,
                cssBlockingGenericDomainSensitive: cssBlockingGenericDomainSensitive
        )
    }

    /// Compacts cosmetic rules for the same domain to one entry.
    static func compactDomainCssRules(entries: [BlockerEntry], useUnlessDomain: Bool = false) -> [BlockerEntry] {
        var result = [BlockerEntry]()

        var domainsDictionary = [String: [BlockerEntry]]()
        for entry in entries {
            var domain: String? = nil

            if (entry.trigger.ifDomain != nil) {
                if (entry.trigger.ifDomain?.count == 1) {
                    domain = entry.trigger.ifDomain![0]
                } else {
                    result.append(entry)
                }
            } else if (entry.trigger.unlessDomain != nil) {
                if (entry.trigger.unlessDomain?.count == 1) {
                    domain = entry.trigger.unlessDomain![0]
                } else {
                    result.append(entry)
                }
            } else {
                // Not a domain sensitive entry
                result.append(entry)
            }

            if (domain != nil) {
                var current = domainsDictionary[domain!]
                if (current == nil) {
                    current = [BlockerEntry]()
                }

                current!.append(entry)
                domainsDictionary.updateValue(current!, forKey: domain!)
            }
        }

        for domain in domainsDictionary.keys {
            let domainEntries = domainsDictionary[domain]
            if (domainEntries == nil) {
                continue
            }

            if (domainEntries!.count <= 1) {
                result.append(contentsOf: domainEntries!)
                continue
            }

            result.append(contentsOf: Compiler.createDomainWideEntries(domain: domain, useUnlessDomain: useUnlessDomain, domainEntries: domainEntries!))
        }

        return result;
    };

    private static func createDomainWideEntries(domain: String, useUnlessDomain: Bool, domainEntries: [BlockerEntry]) -> [BlockerEntry] {
        var result = [BlockerEntry]()

        var trigger = BlockerEntry.Trigger(ifDomain: [domain], urlFilter: ".*")
        if (useUnlessDomain) {
            trigger = BlockerEntry.Trigger(urlFilter: ".*", unlessDomain: [domain])
        }

        let chunked = domainEntries.chunked(into: MAX_SELECTORS_PER_DOMAIN_RULE)
        for chunk in chunked {
            var selectors = [String]()
            for entry in chunk {
                let selector = entry.action.selector
                if (selector != nil) {
                    selectors.append(entry.action.selector!)
                }
            }

            let wideRuleEntry = BlockerEntry(
                    trigger: trigger,
                    action: BlockerEntry.Action(type: "css-display-none", selector: selectors.joined(separator: ", "))
            );

            result.append(wideRuleEntry)
        }

        return result
    }

    struct CompactCssRulesData {
        var cssBlockingWide: [BlockerEntry]
        var cssBlockingDomainSensitive: [BlockerEntry]
        var cssBlockingGenericDomainSensitive: [BlockerEntry]
    }
}
