import Foundation
import Shared

struct VettedRules {
    // extcss, script, scriptlet, css inject
    var advancedRules: [Rule] = []
    // network, css, other
    var simpleRules: [Rule] = []
}

/// Entry point into the SafariConverterLib, here the conversion process starts.
public class ContentBlockerConverter {
    
    public init() {}
    
    /// Converts filter rules in AdGuard format to the format supported by Safari.
    ///
    /// TODO(ameshkov): Remove optimize argument, this logic is not used by anyone and is deprecated.
    ///
    /// - Parameters:
    ///   - rules: array of filtering rules.
    ///   - safariVersion: version of Safari for which the conversion should be done.
    ///   - optimize: if set to true, removes generic element hiding rules form the result.
    ///   - advancedBlocking: if true, convert advanced blocking rules too.
    ///   - advancedBlockingFormat: format for advanced blocking rules (can be json or txt).
    ///   - maxJsonSizeBytes: maximum size for the rules JSON. Due to iOS bug we have to limit that size.
    ///   - progress: provides a way to cancel conversion earlier.
    /// - Returns:
    ///   - Conversion result that contains the Safari rules JSON and additional information about conversion.
    public func convertArray(
        rules: [String],
        safariVersion: SafariVersion = .safari13,
        optimize: Bool = false,
        advancedBlocking: Bool = false,
        advancedBlockingFormat: AdvancedBlockingFormat = .json,
        maxJsonSizeBytes: Int? = nil,
        progress: Progress? = nil
    ) -> ConversionResult {
        var shouldContinue: Bool {
            !(progress?.isCancelled ?? false)
        }

        SafariService.current.version = safariVersion

        let rulesLimit = safariVersion.rulesLimit

        if rules.count == 0 || (rules.count == 1 && rules[0].isEmpty) {
            Logger.log("(ContentBlockerConverter) - No rules passed")
            return ConversionResult.createEmptyResult()
        }
        
        let errorsCounter = ErrorsCounter()
        
        guard shouldContinue else {
            Logger.log("(ContentBlockerConverter) - Cancelled before rules parsing")
            return ConversionResult.createEmptyResult()
        }
        
        let parsedRules = RuleFactory(errorsCounter: errorsCounter).createRules(lines: rules, progress: progress)
        
        let advancedBlockingJson = advancedBlocking && advancedBlockingFormat == AdvancedBlockingFormat.json
        
        let compiler = Compiler(
            optimize: optimize,
            advancedBlocking: advancedBlockingJson,
            errorsCounter: errorsCounter
        )
        
        var compilationResult: CompilationResult
        var advancedRulesTexts: String? = nil
        
        guard shouldContinue else {
            Logger.log("(ContentBlockerConverter) - Cancelled before advanced converting")
            return ConversionResult.createEmptyResult()
        }
        
        if advancedBlocking && advancedBlockingFormat == .txt {
            let vettedRules = vetRules(parsedRules)
            let advancedRules = vettedRules.advancedRules
            let simpleRules = vettedRules.simpleRules

            compilationResult = compiler.compileRules(rules: simpleRules, progress: progress)
            advancedRulesTexts = advancedRules.map { $0.ruleText as String }.joined(separator: "\n")
        } else {
            // by default for .json format
            compilationResult = compiler.compileRules(rules: parsedRules, progress: progress)
        }
        
        compilationResult.errorsCount = errorsCounter.getCount()
        
        let message = createLogMessage(compilationResult: compilationResult)
        Logger.log("(ContentBlockerConverter) - Compilation result: " + message)
        compilationResult.message = message
        
        var conversionResult = Distributor(
            limit: rulesLimit,
            advancedBlocking: advancedBlockingJson,
            maxJsonSizeBytes: maxJsonSizeBytes
        ).createConversionResult(data: compilationResult)
        
        conversionResult.advancedBlockingText = advancedRulesTexts
        
        return conversionResult
    }
    
    /// Creates allowlist rule for provided domain.
    public static func createAllowlistRule(by domain: String) -> String {
        return "@@||\(domain)$document";
    }
    
    /// Creates inverted allowlist rule for provided domains.
    public static func createInvertedAllowlistRule(by domains: [String]) -> String? {
        let domainsString = domains.filter { !$0.isEmpty }.joined(separator: "|~")
        return domainsString.count > 0 ? "@@||*$document,domain=~\(domainsString)" : nil
    }
    
    /// Creates two lists with:
    /// - advanced rules (extcss, script, scriptlet, css inject)
    /// - simple rules (network, css, other)
    private func vetRules(_ rules: [Rule]) -> VettedRules {
        var result = VettedRules()
        
        for rule in rules {
            var isException = rule.isDocumentWhiteList;
            
            if !isException, let rule = rule as? NetworkRule {
                isException = rule.isCssExceptionRule || rule.isJsInject
            }
            
            // exception rules with $document, $elemhide, $generichide, $jsinject modifiers
            // are required in the both lists
            if (isException) {
                result.advancedRules.append(rule)
                result.simpleRules.append(rule)
                continue;
            }
            
            var isAdvanced = rule.isScript
            
            if !isAdvanced, let rule = rule as? CosmeticRule {
                isAdvanced = rule.isExtendedCss || rule.isInjectCss
            }
            
            if (isAdvanced) {
                result.advancedRules.append(rule)
            } else {
                result.simpleRules.append(rule)
            }
        }
        
        return result
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
