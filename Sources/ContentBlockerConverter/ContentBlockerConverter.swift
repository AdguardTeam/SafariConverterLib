import Foundation

/**
 * Entry point
 */
public class ContentBlockerConverter {

    public init() {

    }

    /**
     * Converts filter rules in AdGuard format to the format supported by Safari.
     */
    public func convertArray(rules: [String], safariVersion: SafariVersion = .safari13, optimize: Bool = false, advancedBlocking: Bool = false) -> ConversionResult? {
        
        SafariService.current.version = safariVersion;

        let rulesLimit = safariVersion.rulesLimit;
        
        do {
            if rules.count == 0 || (rules.count == 1 && rules[0].isEmpty) {
                Logger.log("AG: ContentBlockerConverter: No rules passed");
                return try ConversionResult.createEmptyResult();
            }
            
            let errorsCounter = ErrorsCounter();

            let parsedRules = RuleFactory(errorsCounter: errorsCounter).createRules(lines: rules);
            var compilationResult = Compiler(
                optimize: optimize,
                advancedBlocking: advancedBlocking,
                errorsCounter: errorsCounter
            ).compileRules(rules: parsedRules);

            compilationResult.errorsCount = errorsCounter.getCount();

            let message = createLogMessage(compilationResult: compilationResult);
            Logger.log("AG: ContentBlockerConverter: " + message);
            compilationResult.message = message;

            return try Distributor(limit: rulesLimit, advancedBlocking: advancedBlocking).createConversionResult(data: compilationResult);
        } catch {
            Logger.log("AG: ContentBlockerConverter: Unexpected error: \(error)");
        }

        return nil;
    }

    private func createLogMessage(compilationResult: CompilationResult) -> String {
        var message = "Rules converted:  \(compilationResult.rulesCount) (\(compilationResult.errorsCount) errors)";
        message += "\nBasic rules: \(String(describing: compilationResult.urlBlocking.count))";
        message += "\nBasic important rules: \(String(describing: compilationResult.important.count))";
        message += "\nElemhide rules (wide): \(String(describing: compilationResult.cssBlockingWide.count))";
        message += "\nElemhide rules (generic domain sensitive): \(String(describing: compilationResult.cssBlockingGenericDomainSensitive.count))";
        message += "\nExceptions Elemhide (wide): \(String(describing: compilationResult.cssBlockingGenericHideExceptions.count))";
        message += "\nElemhide rules (domain-sensitive): \(String(describing: compilationResult.cssBlockingDomainSensitive.count))";
        message += "\nCssInject rules (domain-sensitive): \(String(describing: compilationResult.сssInjects.count))";
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

        return message;
    }
}
