import Foundation

/**
 * Compiler class
 */
class Compiler {
    // Max number of CSS selectors per rule (look at compactCssRules function)
    private static let MAX_SELECTORS_PER_WIDE_RULE = 250;
    
    private let optimize: Bool
    private let advancedBlockedEnabled: Bool
    
    private let blockerEntryFactory: BlockerEntryFactory;
    
    init(optimize: Bool, advancedBlocking: Bool) {
        self.optimize = optimize;
        self.advancedBlockedEnabled = advancedBlocking;
        self.blockerEntryFactory = BlockerEntryFactory(advancedBlockingEnabled: advancedBlocking);
    }
    
    /**
     * Compiles array of AG rules to intermediate compilation result
     */
    func compileRules(rules: [Rule]) -> CompilationResult {
        var cssBlocking = [BlockerEntry]();
        var cssExceptions = [BlockerEntry]();
        
        var extendedCssBlocking = [BlockerEntry]();
        var scriptRules = [BlockerEntry]();
        var scriptExceptionRules = [BlockerEntry]();
        var scriptlets = [BlockerEntry]();
        var scriptletsExceptions = [BlockerEntry]();
        var cosmeticCssExceptions = [BlockerEntry]();
        
        var compilationResult = CompilationResult();
        compilationResult.rulesCount = rules.count;
        
        for rule in rules {
            let converted = self.blockerEntryFactory.createBlockerEntry(rule: rule);
            if (converted == nil) {
                continue;
            }
            
            let item = converted!;
            
            if (item.action.type == "block") {
                // Url blocking rules
                if (rule.isImportant) {
                    compilationResult.important.append(item);
                } else {
                    compilationResult.urlBlocking.append(item);
                }
            } else if (item.action.type == "css-display-none") {
                cssBlocking.append(item);
            } else if (item.action.type == "css") {
                extendedCssBlocking.append(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isScriptlet) {
                // #@%#//scriptlet
                scriptletsExceptions.append(item);
            } else if (item.action.type == "scriptlet") {
                scriptlets.append(item);
            } else if (item.action.type == "script") {
                scriptRules.append(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isScript) {
                // #@%# rules
                scriptExceptionRules.append(item);
            } else if (item.action.type == "ignore-previous-rules" &&
                (item.action.selector != nil && item.action.selector! != "")) {
                // #@# rules
                cssExceptions.append(item);
            } else if (item.action.type == "ignore-previous-rules" &&
                (item.action.css != nil && item.action.css! != "")) {
                cosmeticCssExceptions.append(item);
            } else if (item.action.type == "ignore-previous-rules" && (rule as! NetworkRule).isSingleOption(option: .Generichide)) {
                compilationResult.cssBlockingGenericHideExceptions.append(item);
            } else if (item.action.type == "ignore-previous-rules" && (rule as! NetworkRule).isSingleOption(option: .Elemhide)) {
                // elemhide rules
                compilationResult.cssElemhide.append(item);
            } else if (item.action.type == "ignore-previous-rules" && (rule as! NetworkRule).isSingleOption(option: .Jsinject)) {
                // jsinject rules
                compilationResult.scriptJsInjectExceptions.append(item);
            } else {
                // other exceptions
                if (rule.isImportant) {
                    compilationResult.importantExceptions.append(item);
                } else if (rule.isDocumentWhiteList) {
                    compilationResult.documentExceptions.append(item);
                } else {
                    compilationResult.other.append(item);
                }
            }
        }
        
        // Applying CSS exceptions
        cssBlocking = Compiler.applyActionExceptions(blockingItems: &cssBlocking, exceptions: cssExceptions, actionValue: "selector");
        let cssCompact = Compiler.compactCssRules(cssBlocking: cssBlocking);
        if (!self.optimize) {
            compilationResult.cssBlockingWide = cssCompact.cssBlockingWide;
        }
        compilationResult.cssBlockingGenericDomainSensitive = cssCompact.cssBlockingGenericDomainSensitive;
        compilationResult.cssBlockingDomainSensitive = cssCompact.cssBlockingDomainSensitive;

        if (self.advancedBlockedEnabled) {
            // Applying CSS exceptions for extended css rules
            extendedCssBlocking = Compiler.applyActionExceptions(
                blockingItems: &extendedCssBlocking, exceptions: cssExceptions + cosmeticCssExceptions, actionValue: "selector"
            );
            let extendedCssCompact = Compiler.compactCssRules(cssBlocking: extendedCssBlocking);
            if (!self.optimize) {
                compilationResult.extendedCssBlockingWide = extendedCssCompact.cssBlockingWide;
            }
            compilationResult.extendedCssBlockingGenericDomainSensitive = extendedCssCompact.cssBlockingGenericDomainSensitive;
            compilationResult.extendedCssBlockingDomainSensitive = extendedCssCompact.cssBlockingDomainSensitive;

            // Applying script exceptions
            scriptRules = Compiler.applyActionExceptions(blockingItems: &scriptRules, exceptions: scriptExceptionRules, actionValue: "script");
            compilationResult.script = scriptRules;

            scriptlets = Compiler.applyActionExceptions(blockingItems: &scriptlets, exceptions: scriptletsExceptions, actionValue: "scriptlet");
            compilationResult.scriptlets = scriptlets;
        }
        
        return compilationResult;
    }
    
    /**
     * Adds exception domain to the specified rule.
     * First it checks if rule has if-domain restriction.
     * If so - it may be that domain is redundant.
     */
    private static func pushExceptionDomain(domain: String, trigger: inout BlockerEntry.Trigger) -> Void {
        let permittedDomains = trigger.ifDomain;
        if (permittedDomains != nil && permittedDomains!.count > 0) {
            
            // First check that domain is not redundant
            let applicable = permittedDomains?.firstIndex(of: domain) != nil;
            if (!applicable) {
                return;
            }
            
            // TODO: Remove domain from trigger.ifDomain?
        }

        if (trigger.unlessDomain == nil) {
            trigger.unlessDomain = [];
        }
        
        trigger.unlessDomain?.append(domain);
    };
    
    static func applyActionExceptions(blockingItems: inout [BlockerEntry], exceptions: [BlockerEntry], actionValue: String) -> [BlockerEntry] {
        for exc in exceptions {
            for index in 0..<blockingItems.count {
                var item = blockingItems[index];
                if (actionValue == "selector" && item.action.selector == exc.action.selector) ||
                    (actionValue == "script" && item.action.script == exc.action.script) ||
                    (actionValue == "scriptlet" && item.action.scriptlet == exc.action.scriptlet) {
                    let exceptionDomains = exc.trigger.ifDomain;
                    if (exceptionDomains != nil) {
                        for d in exceptionDomains! {
                            Compiler.pushExceptionDomain(domain: d, trigger: &item.trigger);
                        }
                        
                        blockingItems[index].trigger = item.trigger;
                    }
                }
            }
        }
        
        var result = [BlockerEntry]();
        
        for r in blockingItems {
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
            } else if (entry.action.selector != nil){
                wideSelectors.append(entry.action.selector!);
                if (wideSelectors.count >= Compiler.MAX_SELECTORS_PER_WIDE_RULE) {
                    cssBlockingWide.append(createWideRule(wideSelectors: wideSelectors));
                    wideSelectors = [String]();
                }
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
    
    struct CompactCssRulesData {
        var cssBlockingWide: [BlockerEntry]
        var cssBlockingDomainSensitive: [BlockerEntry]
        var cssBlockingGenericDomainSensitive: [BlockerEntry]
    }
}
