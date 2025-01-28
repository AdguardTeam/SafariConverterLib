import Foundation

/// Compilation result is an intermediate result object, before building final conversion result.
/// Contains blocker entries objects sorted in groups by source rule type and purpose.
struct CompilationResult {

    /// Total number of rules in the input rules array.
    ///
    /// TODO(ameshkov): !!! REMOVE
    var rulesCount = 0

    /// Total number of errors encountered while converting rules.
    ///
    /// TODO(ameshkov): !!! REMOVE
    var errorsCount = 0

    /// Log message with conversion status details.
    ///
    /// TODO(ameshkov): !!! REMOVE
    var message = ""

    /// Elemhide rules (##) - wide generic rules.
    ///
    /// Example: `##.banner`
    var cssBlockingWide: [BlockerEntry] = []

    /// Elemhide rules (##) - generic domain sensitive
    ///
    /// Example: `~example.org##.banner`
    var cssBlockingGenericDomainSensitive: [BlockerEntry] = []

    /// Elemhide rules (##) with domain restrictions.
    ///
    /// Example: `example.org##.banner`.
    var cssBlockingDomainSensitive: [BlockerEntry] = []

    /// Generic hide exceptions.
    ///
    /// Example: `example.org#@#.banner`
    var cssBlockingGenericHideExceptions: [BlockerEntry] = []

    /// Elemhide exceptions (`$elemhide`)
    var cssElemhideExceptions: [BlockerEntry] = []

    /// Url blocking rules.
    var urlBlocking: [BlockerEntry] = []

    /// Other exceptions
    var otherExceptions: [BlockerEntry] = []

    /// `$important` url blocking rules.
    var important: [BlockerEntry] = []

    /// `$important` url blocking exceptions.
    var importantExceptions: [BlockerEntry] = []

    /// `$document` url blocking exceptions.
    var documentExceptions: [BlockerEntry] = []

    /// Adds a new entry with action`block`.
    mutating func addBlockTypedEntry(entry: BlockerEntry, source: Rule) -> Void {
        if (source.isImportant) {
            important.append(entry)
        } else {
            urlBlocking.append(entry)
        }
    }

    /// Adds a new entry with action `ignore-previous-rules`.
    mutating func addIgnorePreviousTypedEntry(entry: BlockerEntry, rule: Rule) -> Void {
        if (rule is NetworkRule) {
            let networkRule = rule as! NetworkRule

            if (networkRule.isSingleOption(option: .generichide)) {
                cssBlockingGenericHideExceptions.append(entry)
            } else if (networkRule.isSingleOption(option: .elemhide)) {
                cssElemhideExceptions.append(entry)
            } else if (networkRule.isImportant) {
                importantExceptions.append(entry)
            } else if (networkRule.isDocumentWhiteList) {
                documentExceptions.append(entry)
            } else {
                otherExceptions.append(entry)
            }
        } else {
            otherExceptions.append(entry)
        }
    }
}
