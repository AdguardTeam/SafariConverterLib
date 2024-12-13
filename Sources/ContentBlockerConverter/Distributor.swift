import Foundation
import Shared

/// Distributor creates a Safari JSON and checks for additional limitations while doing that.
class Distributor {

    private let limit: Int;
    private let advancedBlockedEnabled: Bool;
    private let maxJsonSizeBytes: Int?;
    
    init(
        limit: Int,
        advancedBlocking: Bool,
        maxJsonSizeBytes: Int? = nil
    ) {
        self.limit = limit
        advancedBlockedEnabled = advancedBlocking
        self.maxJsonSizeBytes = maxJsonSizeBytes
    }

    /**
     * Creates final conversion result from compilation result object
     */
    func createConversionResult(data: CompilationResult) -> ConversionResult {
        var entries = [BlockerEntry]()
        entries.append(contentsOf: data.cssBlockingWide)
        entries.append(contentsOf: data.cssBlockingGenericDomainSensitive)
        entries.append(contentsOf: data.cssBlockingGenericHideExceptions)
        entries.append(contentsOf: data.cssBlockingDomainSensitive)
        entries.append(contentsOf: data.cssElemhide)
        entries.append(contentsOf: data.urlBlocking)
        entries.append(contentsOf: data.other)
        entries.append(contentsOf: data.important)
        entries.append(contentsOf: data.importantExceptions)
        entries.append(contentsOf: data.documentExceptions)

        var advBlockingEntries = [BlockerEntry]()
        if (advancedBlockedEnabled) {
            advBlockingEntries.append(contentsOf: data.extendedCssBlockingWide)
            advBlockingEntries.append(contentsOf: data.extendedCssBlockingGenericDomainSensitive)
            advBlockingEntries.append(contentsOf: data.cssBlockingGenericHideExceptions)
            advBlockingEntries.append(contentsOf: data.extendedCssBlockingDomainSensitive)
            advBlockingEntries.append(contentsOf: data.cssElemhide)
            advBlockingEntries.append(contentsOf: data.script)
            advBlockingEntries.append(contentsOf: data.scriptlets)
            advBlockingEntries.append(contentsOf: data.scriptJsInjectExceptions)
            advBlockingEntries.append(contentsOf: data.сssInjects)
            advBlockingEntries.append(contentsOf: data.other)
            advBlockingEntries.append(contentsOf: data.importantExceptions)
            advBlockingEntries.append(contentsOf: data.documentExceptions)
        }

        let errorsCount = data.errorsCount
        
        return ConversionResult(
            entries: entries,
            advBlockingEntries: advBlockingEntries,
            limit: self.limit,
            errorsCount: errorsCount,
            message: data.message,
            maxJsonSizeBytes: self.maxJsonSizeBytes
        )
    }
}
