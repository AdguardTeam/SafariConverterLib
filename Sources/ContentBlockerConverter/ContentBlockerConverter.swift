import Foundation

/// Entry point into the SafariConverterLib, here the conversion process starts.
public class ContentBlockerConverter {
    public init() {}

    /// Converts filter rules in AdGuard format to the format supported by Safari.
    ///
    /// - Parameters:
    ///   - rules: array of filtering rules.
    ///   - safariVersion: version of Safari for which the conversion should be
    ///     done.
    ///   - advancedBlocking: if true, convert advanced blocking rules too.
    ///   - maxJsonSizeBytes: maximum size for the rules JSON. Due to iOS bug we
    ///     have to limit that size. Read more about the bug in
    ///     [issue #56](https://github.com/AdguardTeam/SafariConverterLib/issues/56).
    ///   - progress: provides a way to cancel conversion earlier.
    /// - Returns:
    ///   - Conversion result that contains the Safari rules JSON and additional
    ///     information about conversion.
    public func convertArray(
        rules: [String],
        safariVersion: SafariVersion = .safari13,
        advancedBlocking: Bool = false,
        maxJsonSizeBytes: Int? = nil,
        progress: Progress? = nil
    ) -> ConversionResult {
        var shouldContinue: Bool {
            !(progress?.isCancelled ?? false)
        }

        let errorsCounter = ErrorsCounter()

        guard shouldContinue else {
            Logger.log("(ContentBlockerConverter) - Cancelled before rules parsing")
            return ConversionResult.createEmptyResult()
        }

        let allRules = RuleFactory.createRules(
            lines: rules,
            for: safariVersion,
            errorsCounter: errorsCounter
        )

        var (simpleRules, advancedRules) = ContentBlockerConverter.splitSimpleAdvanced(allRules)

        // Count rules compatible with Safari before filtering out exceptions.
        let safariCompatibleRulesCount = simpleRules.count

        // Filter out exceptions from simple rules first.
        simpleRules = RuleFactory.filterOutExceptions(from: simpleRules)

        guard shouldContinue else {
            Logger.log("(ContentBlockerConverter) - Cancelled before compiling into Safari JSON")
            return ConversionResult.createEmptyResult()
        }

        let compiler = Compiler(errorsCounter: errorsCounter, version: safariVersion)

        // Compile simple rules to Safari content blocking JSON.
        let compilationResult = compiler.compileRules(rules: simpleRules, progress: progress)

        // Compose the Safari content blocking JSON.
        let rulesLimit = safariVersion.rulesLimit
        let result = SafariCbBuilder.buildCbJson(
            from: compilationResult,
            maxRules: rulesLimit,
            maxJsonSizeBytes: maxJsonSizeBytes
        )

        // Prepare advanced rules text.
        let advancedRulesCount = advancedBlocking ? advancedRules.count : 0
        let advancedBlockingText =
            advancedBlocking && advancedRulesCount > 0
            ? advancedRules.map { $0.ruleText }.joined(separator: "\n") : nil

        // Prepare the conversion result.
        let conversionResult = ConversionResult(
            sourceRulesCount: allRules.count,
            sourceSafariCompatibleRulesCount: safariCompatibleRulesCount,
            safariRulesCount: result.rulesCount,
            advancedRulesCount: advancedRulesCount,
            discardedSafariRules: result.discardedRulesCount,
            errorsCount: errorsCounter.getCount(),
            safariRulesJSON: result.json,
            advancedRulesText: advancedBlockingText
        )

        Logger.log("(ContentBlockerConverter) - Compilation result: \(conversionResult)")

        return conversionResult
    }

    /// Creates allowlist rule for provided domain.
    ///
    /// This function is supposed to be used by the library users.
    public static func createAllowlistRule(by domain: String) -> String {
        return "@@||\(domain)$document"
    }

    /// Creates inverted allowlist rule for provided domains.
    ///
    /// This function is supposed to be used by the library users.
    public static func createInvertedAllowlistRule(by domains: [String]) -> String? {
        let domainsString = domains.filter { !$0.isEmpty }.joined(separator: "|~")
        return !domainsString.isEmpty ? "@@||*$document,domain=~\(domainsString)" : nil
    }

    /// This is a list of modifiers that can affect how cosmetic and scriptlet rules are applied to the page.
    /// Rules with these modifiers should be placed to the list of advanced rules.
    private static let advancedOptions: NetworkRule.Option = [
        .document,
        .jsinject,
        .elemhide,
        .generichide,
        .specifichide,
    ]

    /// Splits all rules into two arrays:
    ///
    /// - Advanced rules (extended CSS, script, scriptlet, css injection)
    /// - Simple rules (network, element hiding)
    private static func splitSimpleAdvanced(_ rules: [Rule]) -> (simple: [Rule], advanced: [Rule]) {
        var simple: [Rule] = []
        var advanced: [Rule] = []

        for rule in rules {
            if let rule = rule as? NetworkRule {
                simple.append(rule)

                if rule.isWhiteList && !rule.enabledOptions.isDisjoint(with: advancedOptions) {
                    // Network rules that can affect how advanced cosmetic rules are used
                    // are added to both simple and advanced.
                    advanced.append(rule)
                }
            } else if let rule = rule as? CosmeticRule {
                // Cosmetic rules are either go to Safari or they need to be applied
                // via javascript (i.e. they are added to advanced).
                let isAdvanced = rule.isScript || rule.isExtendedCss || rule.isInjectCss

                if isAdvanced {
                    advanced.append(rule)
                } else {
                    simple.append(rule)
                }
            }
        }

        return (simple, advanced)
    }
}
