import Foundation

/**
 * Entry point
 */
class ContentBlockerConverter {
    
    /**
     * Converts filter rules in AdGuard format to the format supported by Safari.
     */
    func convertArray(rules: [String], limit: Int = 0, optimize: Bool = false, advancedBlocking: Bool = false) -> ConversionResult? {
        if rules.count == 0 {
            NSLog("AG: ContentBlockerConverter: No rules presented");
            return nil;
        }
        
        do {
            let errorsCounter = ErrorsCounter();
            
            let parsedRules = RuleFactory(errorsCounter: errorsCounter).createRules(lines: rules);
            var compilationResult = Compiler(
                optimize: optimize,
                advancedBlocking: advancedBlocking,
                errorsCounter: errorsCounter
            ).compileRules(rules: parsedRules);
            
            compilationResult.errorsCount = errorsCounter.getCount();
            
            addLogMessage(compilationResult: compilationResult);
            
            return try Distributor(limit: limit, advancedBlocking: advancedBlocking).createConversionResult(data: compilationResult);
        } catch {
            NSLog("AG: ContentBlockerConverter: Unexpected error: \(error)");
        }
        
        return nil;
    }
    
    private func addLogMessage(compilationResult: CompilationResult) -> Void {
        var message = "Rules converted:  \(compilationResult.rulesCount) (\(compilationResult.errorsCount) errors)";
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
        
        NSLog("AG: ContentBlockerConverter: " + message);
    }
}
