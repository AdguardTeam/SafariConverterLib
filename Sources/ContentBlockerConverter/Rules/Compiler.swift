import Foundation

/**
 * Compiler class
 */
class Compiler {
    
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
        let modifiedRules = Compiler.applyBadFilterExceptions(rules: rules);
        
        var compilationResult = CompilationResult();
        
        for rule in modifiedRules {
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
//                cssBlocking.push(item);
            } else if (item.action.type == "css") {
//                extendedCssBlocking.push(item);
            } else if (item.action.type == "script") {
//                scriptRules.push(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isScript) {
                // #@%# rules
//                scriptExceptionRules.push(item);
            } else if (item.action.type == "scriptlet") {
//                scriptlets.push(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isScriptlet) {
                // #@%#//scriptlet
//                scriptletsExceptions.push(item);
            } else if (item.action.type == "ignore-previous-rules" &&
                (item.action.selector != nil && item.action.selector! != "")) {
                // #@# rules
//                cssExceptions.push(item);
            } else if (item.action.type == "ignore-previous-rules" &&
                (item.action.css != nil && item.action.css! != "")) {
//                cosmeticCssExceptions.push(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isSingleOption(optionName: "generichide")) {
                compilationResult.cssBlockingGenericHideExceptions.append(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isSingleOption(optionName: "elemhide")) {
                // elemhide rules
                compilationResult.cssElemhide.append(item);
            } else if (item.action.type == "ignore-previous-rules" && rule.isSingleOption(optionName: "jsinject")) {
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
        
        // Construct result object
        
        // TODO: Apply exceptions
        // Applying CSS exceptions
//        cssBlocking = applyActionExceptions(cssBlocking, cssExceptions, 'selector');
//        const cssCompact = compactCssRules(cssBlocking);
//        if (!optimize) {
//            contentBlocker.cssBlockingWide = cssCompact.cssBlockingWide;
//        }
//        contentBlocker.cssBlockingGenericDomainSensitive = cssCompact.cssBlockingGenericDomainSensitive;
//        contentBlocker.cssBlockingDomainSensitive = cssCompact.cssBlockingDomainSensitive;
//
//        if (advancedBlocking) {
//            // Applying CSS exceptions for extended css rules
//            extendedCssBlocking = applyActionExceptions(extendedCssBlocking, cssExceptions.concat(cosmeticCssExceptions), 'selector');
//            const extendedCssCompact = compactCssRules(extendedCssBlocking);
//            if (!optimize) {
//                contentBlocker.extendedCssBlockingWide = extendedCssCompact.cssBlockingWide;
//            }
//            contentBlocker.extendedCssBlockingGenericDomainSensitive = extendedCssCompact.cssBlockingGenericDomainSensitive;
//            contentBlocker.extendedCssBlockingDomainSensitive = extendedCssCompact.cssBlockingDomainSensitive;
//
//            // Applying script exceptions
//            scriptRules = applyActionExceptions(scriptRules, scriptExceptionRules, 'script');
//            contentBlocker.script = scriptRules;
//
//            scriptlets = applyActionExceptions(scriptlets, scriptletsExceptions, 'scriptlet');
//            contentBlocker.scriptlets = scriptlets;
//        }
        
        addLogMessage(compilationResult: compilationResult);
        
        return CompilationResult();
    }
    
    static func applyBadFilterExceptions(rules: [Rule]) -> [Rule] {
        // TODO: Apply badfilter exceptions
        return rules;
    }
    
    private func addLogMessage(compilationResult: CompilationResult) -> Void {
        //let message = 'Rules converted: ' + convertedCount + ' (' + contentBlocker.errors.length + ' errors)';
        var message = "";
        message += "\nBasic rules: \(String(describing: compilationResult.urlBlocking.count))";
        message += "\nBasic important rules: \(String(describing: compilationResult.important.count))";
        message += "\nElemhide rules (wide): \(String(describing: compilationResult.cssBlockingWide.count))";
        message += "\nElemhide rules (generic domain sensitive): \(String(describing: compilationResult.cssBlockingGenericDomainSensitive.count))";
        message += "\nExceptions Elemhide (wide): \(String(describing: compilationResult.cssBlockingGenericHideExceptions.count))";
        message += "\nElemhide rules (domain-sensitive): \(String(describing: compilationResult.cssBlockingDomainSensitive.count))";
        message += "\nScript rules: \(String(describing: compilationResult.script.count))";
        message += "\nScriptlets rules: \(String(describing: compilationResult.scriptlets.count))";
        message += "\nExtended Css Elemhide rules (wide): \(String(describing: compilationResult.extendedCssBlockingWide.count))";
        message += "\nExtended Css Elemhide rules (generic domain sensitive): \(String(describing: compilationResult.extendedCssBlockingGenericDomainSensitive.count))";
        message += "\nExtended Css Elemhide rules (domain-sensitive): \(String(describing: compilationResult.extendedCssBlockingDomainSensitive.count))";
        message += "\nExceptions (elemhide): \(String(describing: compilationResult.cssElemhide.count))";
        message += "\nExceptions (important): \(String(describing: compilationResult.importantExceptions.count))";
        message += "\nExceptions (document): \(String(describing: compilationResult.documentExceptions.count))";
        message += "\nExceptions (jsinject): \(String(describing: compilationResult.scriptJsInjectExceptions.count))";
        message += "\nExceptions (other): \(String(describing: compilationResult.other.count))";
        
        NSLog(message);
    }
}
