import Foundation

/**
 * Compilation result is an intermediate result object, before building final conversion result
 */
struct CompilationResult {
    // Elemhide rules (##) - wide generic rules
    var cssBlockingWide: [BlockerEntry] = [];
    // Elemhide rules (##) - generic domain sensitive
    var cssBlockingGenericDomainSensitive: [BlockerEntry] = [];
    // Elemhide rules (##) with domain restrictions
    var cssBlockingDomainSensitive: [BlockerEntry] = [];
    // Generic hide exceptions
    var cssBlockingGenericHideExceptions: [BlockerEntry] = [];
    // Elemhide exceptions ($elemhide)
    var cssElemhide: [BlockerEntry] = [];
    // Url blocking rules
    var urlBlocking: [BlockerEntry] = [];
    // Other exceptions
    var other: [BlockerEntry] = [];
    // $important url blocking rules
    var important: [BlockerEntry] = [];
    // $important url blocking exceptions
    var importantExceptions: [BlockerEntry] = [];
    // Document url blocking exceptions
    var documentExceptions: [BlockerEntry] = [];
    
    // Advanced blocking entries
    
    // Script rules (#%#)
    var script: [BlockerEntry] = [];
    // Scriptlet rules (#%#//scriptlet)
    var scriptlets: [BlockerEntry] = [];
    // JsInject exception ($jsinject)
    var scriptJsInjectExceptions: [BlockerEntry] = [];
    // Extended css Elemhide rules (##) - wide generic rules
    var extendedCssBlockingWide: [BlockerEntry] = [];
    // Extended css Elemhide rules (##) - generic domain sensitive
    var extendedCssBlockingGenericDomainSensitive: [BlockerEntry] = [];
    // Elemhide rules (##) with domain restrictions
    var extendedCssBlockingDomainSensitive: [BlockerEntry] = [];
}
