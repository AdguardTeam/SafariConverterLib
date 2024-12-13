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

        entries = updateDomains(entries: entries)

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

            advBlockingEntries = updateDomains(entries: advBlockingEntries)
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

    /**
     * Updates if-domain and unless-domain fields.
     * Adds wildcard to every rule and splits rules contains over limit domains
     *
     * TODO(ameshkov): !!! Why are we doing it here?
     */
    func updateDomains(entries: [BlockerEntry]) -> [BlockerEntry] {
        var result = [BlockerEntry]()
        for var entry in entries {
            entry.trigger.ifDomain = addWildcard(domains: entry.trigger.ifDomain)
            entry.trigger.unlessDomain = addWildcard(domains: entry.trigger.unlessDomain)

            result += [entry]
        }
        return result
    };

    private func addWildcard(domains: [String]?) -> [String]? {
        if domains == nil || domains?.count == 0 {
            return domains;
        }

        var result = [String]();
        for domain in domains! {
            if !domain.hasPrefix("*") {
                result.append("*" + domain);
            } else {
                result.append(domain);
            }
        }

        return result;
    };
}
