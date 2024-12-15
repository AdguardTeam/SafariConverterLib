import Foundation

/// Compilation result is an intermediate result object, before building final conversion result.
/// Contains blocker entries objects sorted in groups by source rule type and purpose.
struct CompilationResult {

    /// Total number of rules in the input rules array.
    var rulesCount = 0;

    /// Total number of errors encountered while converting rules.
    var errorsCount = 0;

    /// Log message with conversion status details.
    var message = "";

    /// Elemhide rules (##) - wide generic rules
    var cssBlockingWide: [BlockerEntry] = []
    
    /// Elemhide rules (##) - generic domain sensitive
    var cssBlockingGenericDomainSensitive: [BlockerEntry] = []
    
    /// Elemhide rules (##) with domain restrictions
    var cssBlockingDomainSensitive: [BlockerEntry] = []
    
    /// Generic hide exceptions
    var cssBlockingGenericHideExceptions: [BlockerEntry] = []
    
    /// Elemhide exceptions ($elemhide)
    var cssElemhide: [BlockerEntry] = []
    
    /// Url blocking rules
    var urlBlocking: [BlockerEntry] = []
    
    /// Other exceptions
    var other: [BlockerEntry] = []
    
    /// $important url blocking rules
    var important: [BlockerEntry] = []
    
    /// $important url blocking exceptions
    var importantExceptions: [BlockerEntry] = []
    
    /// Document url blocking exceptions
    var documentExceptions: [BlockerEntry] = []

    // Advanced blocking entries

    /// Script rules (#%#)
    var script: [BlockerEntry] = []

    /// Scriptlet rules (#%#//scriptlet)
    var scriptlets: [BlockerEntry] = []

    /// JsInject exception ($jsinject)
    var scriptJsInjectExceptions: [BlockerEntry] = []

    /// Css injecting rules
    var сssInjects: [BlockerEntry] = []

    /// Extended css Elemhide rules (##) - wide generic rules
    var extendedCssBlockingWide: [BlockerEntry] = []

    /// Extended css Elemhide rules (##) - generic domain sensitive
    var extendedCssBlockingGenericDomainSensitive: [BlockerEntry] = []

    /// Elemhide rules (##) with domain restrictions
    var extendedCssBlockingDomainSensitive: [BlockerEntry] = []

    /// Adds a new entry with action`block`.
    mutating func addBlockTypedEntry(entry: BlockerEntry, source: Rule) -> Void {
        if (source.isImportant) {
            important.append(entry)
        } else {
            urlBlocking.append(entry)
        }
    }

    /// Adds a new entry with action `ignore-previous-rules`.
    mutating func addIgnorePreviousTypedEntry(entry: BlockerEntry, source: Rule) -> Void {
        if (source is NetworkRule) {
            let networkRule = source as! NetworkRule;
            if (networkRule.isSingleOption(option: .generichide)) {
                cssBlockingGenericHideExceptions.append(entry);
                return;
            } else if (networkRule.isSingleOption(option: .elemhide)) {
                cssElemhide.append(entry);
                return;
            } else if (networkRule.isSingleOption(option: .jsinject)) {
                scriptJsInjectExceptions.append(entry);
                return;
            }
        }

        // Other exceptions.
        if (source.isImportant) {
            importantExceptions.append(entry);
        } else if (source.isDocumentWhiteList) {
            documentExceptions.append(entry);
        } else {
            other.append(entry);
        }
    }
}
