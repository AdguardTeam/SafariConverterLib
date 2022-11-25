import Foundation

/**
 * Compiler class
 */
class Compiler {
    // Max number of CSS selectors per rule (look at compactCssRules function)
    private static let MAX_SELECTORS_PER_WIDE_RULE = 250;
    private static let MAX_SELECTORS_PER_DOMAIN_RULE = 250;

    private let optimize: Bool
    private let advancedBlockedEnabled: Bool

    private let blockerEntryFactory: BlockerEntryFactory;

    private static let COSMETIC_ACTIONS: [String] = ["css-display-none", "css-inject", "css-extended", "scriptlet", "script"];

    init(
            optimize: Bool,
            advancedBlocking: Bool,
            errorsCounter: ErrorsCounter
    ) {
        self.optimize = optimize
        advancedBlockedEnabled = advancedBlocking
        blockerEntryFactory = BlockerEntryFactory(advancedBlockingEnabled: advancedBlocking, errorsCounter: errorsCounter);
    }

    /**
     * Compiles array of AG rules to intermediate compilation result
     */
    func compileRules(rules: [Rule]) -> CompilationResult {
        var cssBlocking = [BlockerEntry]()
        var cssExceptions = [BlockerEntry]()

        var cssInjects = [BlockerEntry]()
        var extendedCssBlocking = [BlockerEntry]()
        var scriptRules = [BlockerEntry]()
        var scriptExceptionRules = [BlockerEntry]()
        var scriptlets = [BlockerEntry]()
        var scriptletsExceptions = [BlockerEntry]()
        var cosmeticCssExceptions = [BlockerEntry]()

        var specifichideExceptionDomains = [String]()

        var compilationResult = CompilationResult()
        compilationResult.rulesCount = rules.count

        for rule in rules {
            let converted = blockerEntryFactory.createBlockerEntry(rule: rule)
            if (converted == nil) {
                continue
            }

            let item = converted!

            if item.action.type == "block" {
                // Url blocking rules
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
                } else if (rule as! NetworkRule).isSingleOption(option: .Specifichide) {
                    let exceptionDomain = NetworkRuleParser.parseRuleDomain(pattern: rule.ruleText)
                    specifichideExceptionDomains.append(exceptionDomain)
                } else {
                    compilationResult.addIgnorePreviousTypedEntry(entry: item, source: rule)
                }
            }
        }

        // Applying CSS exceptions
        cssBlocking = Compiler.applyActionExceptions(blockingItems: &cssBlocking, exceptions: cssExceptions, actionValue: "selector")
        let cssCompact = Compiler.compactCssRules(cssBlocking: cssBlocking)
        if !optimize {
            compilationResult.cssBlockingWide = cssCompact.cssBlockingWide
        }
        compilationResult.cssBlockingGenericDomainSensitive = Compiler.compactDomainCssRules(entries: cssCompact.cssBlockingGenericDomainSensitive, useUnlessDomain: true)
        compilationResult.cssBlockingDomainSensitive = Compiler.compactDomainCssRules(entries: cssCompact.cssBlockingDomainSensitive)

        // Apply specifichide exceptions
        compilationResult.cssBlockingDomainSensitive = Compiler.applySpecifichide(blockingItems: &compilationResult.cssBlockingDomainSensitive, specifichideExceptions: specifichideExceptionDomains)

        if advancedBlockedEnabled {
            // Applying CSS exceptions for extended css rules
            extendedCssBlocking = Compiler.applyActionExceptions(
                    blockingItems: &extendedCssBlocking, exceptions: cssExceptions + cosmeticCssExceptions, actionValue: "css"
            )
            let extendedCssCompact = Compiler.compactCssRules(cssBlocking: extendedCssBlocking)
            if (!optimize) {
                compilationResult.extendedCssBlockingWide = extendedCssCompact.cssBlockingWide
            }
            compilationResult.extendedCssBlockingGenericDomainSensitive = extendedCssCompact.cssBlockingGenericDomainSensitive
            compilationResult.extendedCssBlockingDomainSensitive = extendedCssCompact.cssBlockingDomainSensitive

            // Apply specifichide exceptions for extended css rules
            compilationResult.extendedCssBlockingDomainSensitive = Compiler.applySpecifichide(blockingItems: &compilationResult.extendedCssBlockingDomainSensitive, specifichideExceptions: specifichideExceptionDomains)

            // Applying CSS exceptions for css injecting rules
            cssInjects = Compiler.applyActionExceptions(
                    blockingItems: &cssInjects, exceptions: cssExceptions + cosmeticCssExceptions, actionValue: "css"
            )
            compilationResult.сssInjects = cssInjects

            // Apply specifichide exceptions for css injecting rules
            compilationResult.сssInjects = Compiler.applySpecifichide(blockingItems: &compilationResult.сssInjects, specifichideExceptions: specifichideExceptionDomains)

            // Applying script exceptions
            scriptRules = Compiler.applyActionExceptions(blockingItems: &scriptRules, exceptions: scriptExceptionRules, actionValue: "script")
            compilationResult.script = scriptRules

            scriptlets = Compiler.applyActionExceptions(blockingItems: &scriptlets, exceptions: scriptletsExceptions, actionValue: "scriptlet")
            compilationResult.scriptlets = scriptlets
        }

        return compilationResult
    }

    /**
     * Adds exception domain to the specified rule.
     * First it checks if rule has if-domain restriction.
     * If so - it may be that domain is redundant.
     */
    private static func applyExceptionDomains(exceptionTrigger: BlockerEntry.Trigger, ruleTrigger: inout BlockerEntry.Trigger) -> Void {
        var exceptionDomains: [String]?;
        var domainsList: [String]?;

        if (exceptionTrigger.ifDomain != nil) {
            exceptionDomains = exceptionTrigger.ifDomain;
            domainsList = ruleTrigger.ifDomain;
        } else if (exceptionTrigger.unlessDomain != nil) {
            exceptionDomains = exceptionTrigger.unlessDomain;
            domainsList = ruleTrigger.unlessDomain;
        }

        // generic exception case
        if (exceptionDomains == nil) {
            exceptionDomains = [];
            ruleTrigger.ifDomain = [];
            return;
        }

        for domain in exceptionDomains! {
            if (domainsList != nil && domainsList!.count > 0) {

                // First check that domain is not redundant
                let applicable = domainsList?.firstIndex(of: domain) != nil;
                if (!applicable) {
                    continue
                }

                // remove exception domain
                if (ruleTrigger.ifDomain != nil) {
                    ruleTrigger.ifDomain = ruleTrigger.ifDomain!.filter {
                        $0 != domain
                    }
                } else if (ruleTrigger.unlessDomain != nil) {
                    ruleTrigger.unlessDomain = ruleTrigger.unlessDomain!.filter {
                        $0 != domain
                    }
                }

            } else {
                if (ruleTrigger.unlessDomain == nil) {
                    ruleTrigger.unlessDomain = [];
                }
                ruleTrigger.unlessDomain?.append(domain);
            }
        }
    };

    private static func getActionValue(entry: BlockerEntry, action: String) -> String? {
        switch action {
        case "selector":
            return entry.action.selector;
        case "css":
            return entry.action.css;
        case "script":
            return entry.action.script;
        case "scriptlet":
            return entry.action.scriptlet;
        default:
            return nil;
        }
    }

    /**
     * Applies specifichide exceptions
     */
    private static func applySpecifichide(blockingItems: inout [BlockerEntry], specifichideExceptions: [String]) -> [BlockerEntry] {
        for index in 0..<blockingItems.count {
            var item = blockingItems[index];

            for exception in specifichideExceptions {
                if (item.trigger.ifDomain?.contains(exception) != nil) {
                    item.trigger.ifDomain = item.trigger.ifDomain!.filter {
                        $0 != exception
                    }
                }
            }

            blockingItems[index].trigger = item.trigger;
        }

        var result = [BlockerEntry]();

        for r in blockingItems {
            // skip entries with excluded ifDomain
            if (r.trigger.ifDomain?.count == 0) {
                continue;
            }
            result.append(r);
        }

        return result;
    }

    /**
     * Applies exceptions
     */
    static func applyActionExceptions(blockingItems: inout [BlockerEntry], exceptions: [BlockerEntry], actionValue: String) -> [BlockerEntry] {
        var exceptionsDictionary = [String: [BlockerEntry]]();
        for exc in exceptions {
            let key = Compiler.getActionValue(entry: exc, action: actionValue);
            if (key == nil) {
                continue;
            }

            var current = exceptionsDictionary[key!];
            if (current == nil) {
                current = [BlockerEntry]();
            }

            current!.append(exc);
            exceptionsDictionary.updateValue(current!, forKey: key!);
        }

        for index in 0..<blockingItems.count {
            let key = Compiler.getActionValue(entry: blockingItems[index], action: actionValue);
            if (key == nil) {
                continue;
            }

            let matchingExceptions = exceptionsDictionary[key!];
            if (matchingExceptions == nil) {
                continue;
            }

            for exc in matchingExceptions! {
                Compiler.applyExceptionDomains(exceptionTrigger: exc.trigger, ruleTrigger: &blockingItems[index].trigger);
            }
        }

        var result = [BlockerEntry]();

        for r in blockingItems {
            // skip cosmetic entries, that has been disabled by exclusion rules
            if ((r.trigger.ifDomain?.count == 0 && r.trigger.unlessDomain == nil) || (r.trigger.unlessDomain?.count == 0 && r.trigger.ifDomain == nil) && self.COSMETIC_ACTIONS.contains(r.action.type)) {
                continue;
            }

            if (r.trigger.ifDomain == nil || r.trigger.ifDomain?.count == 0 ||
                    r.trigger.unlessDomain == nil || r.trigger.unlessDomain?.count == 0) {
                result.append(r);
            }
        }

        return result;
    }

    private static func createWideRule(wideSelectors: [String]) -> BlockerEntry {
        return BlockerEntry(
                trigger: BlockerEntry.Trigger(urlFilter: BlockerEntryFactory.URL_FILTER_CSS_RULES),
                action: BlockerEntry.Action(type: "css-display-none", selector: wideSelectors.joined(separator: ", "))
        );
    };

    /**
     * Compacts wide CSS rules
     * @param cssBlocking unsorted css elemhide rules
     */
    static func compactCssRules(cssBlocking: [BlockerEntry]) -> CompactCssRulesData {
        var cssBlockingWide = [BlockerEntry]();
        var cssBlockingDomainSensitive = [BlockerEntry]();
        var cssBlockingGenericDomainSensitive = [BlockerEntry]();

        var wideSelectors = [String]();

        for entry in cssBlocking {
            if (entry.trigger.ifDomain != nil) {
                cssBlockingDomainSensitive.append(entry);
            } else if (entry.trigger.unlessDomain != nil) {
                cssBlockingGenericDomainSensitive.append(entry);
            } else if (entry.action.selector != nil && entry.trigger.urlFilter == BlockerEntryFactory.URL_FILTER_CSS_RULES) {
                wideSelectors.append(entry.action.selector!);
                if (wideSelectors.count >= Compiler.MAX_SELECTORS_PER_WIDE_RULE) {
                    cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors));
                    wideSelectors = [String]();
                }
            } else {
                cssBlockingWide.append(entry);
            }
        }

        if (wideSelectors.count > 0) {
            cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors));
        }

        return CompactCssRulesData(
                cssBlockingWide: cssBlockingWide,
                cssBlockingDomainSensitive: cssBlockingDomainSensitive,
                cssBlockingGenericDomainSensitive: cssBlockingGenericDomainSensitive
        );
    };

    /**
     * Compacts same domain elemhide rules
     * @param cssBlocking unsorted domain sensitive css elemhide rules
     */
    static func compactDomainCssRules(entries: [BlockerEntry], useUnlessDomain: Bool = false) -> [BlockerEntry] {
        var result = [BlockerEntry]();

        var domainsDictionary = [String: [BlockerEntry]]();
        for entry in entries {
            var domain: String? = nil;

            if (entry.trigger.ifDomain != nil) {
                if (entry.trigger.ifDomain?.count == 1) {
                    domain = entry.trigger.ifDomain![0];
                } else {
                    result.append(entry);
                }
            } else if (entry.trigger.unlessDomain != nil) {
                if (entry.trigger.unlessDomain?.count == 1) {
                    domain = entry.trigger.unlessDomain![0];
                } else {
                    result.append(entry);
                }
            } else {
                // Not a domain sensitive entry
                result.append(entry);
            }

            if (domain != nil) {
                var current = domainsDictionary[domain!];
                if (current == nil) {
                    current = [BlockerEntry]();
                }

                current!.append(entry);
                domainsDictionary.updateValue(current!, forKey: domain!);
            }
        }

        for domain in domainsDictionary.keys {
            let domainEntries = domainsDictionary[domain];
            if (domainEntries == nil) {
                continue;
            }

            if (domainEntries!.count <= 1) {
                result.append(contentsOf: domainEntries!);
                continue;
            }

            result.append(contentsOf: Compiler.createDomainWideEntries(domain: domain, useUnlessDomain: useUnlessDomain, domainEntries: domainEntries!));
        }

        return result;
    };

    private static func createDomainWideEntries(domain: String, useUnlessDomain: Bool, domainEntries: [BlockerEntry]) -> [BlockerEntry] {
        var result = [BlockerEntry]();

        var trigger = BlockerEntry.Trigger(ifDomain: [domain], urlFilter: ".*");
        if (useUnlessDomain) {
            trigger = BlockerEntry.Trigger(urlFilter: ".*", unlessDomain: [domain]);
        }

        let chunked = domainEntries.chunked(into: MAX_SELECTORS_PER_DOMAIN_RULE);
        for chunk in chunked {
            var selectors = [String]();
            for entry in chunk {
                let selector = entry.action.selector;
                if (selector != nil) {
                    selectors.append(entry.action.selector!);
                }
            }

            let wideRuleEntry = BlockerEntry(
                    trigger: trigger,
                    action: BlockerEntry.Action(type: "css-display-none", selector: selectors.joined(separator: ", "))
            );

            result.append(wideRuleEntry);
        }

        return result;
    }

    struct CompactCssRulesData {
        var cssBlockingWide: [BlockerEntry]
        var cssBlockingDomainSensitive: [BlockerEntry]
        var cssBlockingGenericDomainSensitive: [BlockerEntry]
    }
}
