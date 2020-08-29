import Foundation

/**
 * Distributor class
 * Creates a distribution ready result object
 */
class Distributor {
    
    private let limit: Int;
    private let advancedBlockedEnabled: Bool;
    
    init(limit: Int, advancedBlocking: Bool) {
        self.limit = limit;
        self.advancedBlockedEnabled = advancedBlocking;
    }
    
    /**
     * Creates final conversion result from compilation result object
     */
    func createConversionResult(data: CompilationResult) throws -> ConversionResult {
        var entries = [BlockerEntry]();
        entries.append(contentsOf: data.cssBlockingWide);
        entries.append(contentsOf: data.cssBlockingGenericDomainSensitive);
        entries.append(contentsOf: data.cssBlockingGenericHideExceptions);
        entries.append(contentsOf: data.cssBlockingDomainSensitive);
        entries.append(contentsOf: data.cssElemhide);
        entries.append(contentsOf: data.urlBlocking);
        entries.append(contentsOf: data.other);
        entries.append(contentsOf: data.important);
        entries.append(contentsOf: data.importantExceptions);
        entries.append(contentsOf: data.documentExceptions);

        entries = applyDomainWildcards(entries: entries);

        var advBlockingEntries = [BlockerEntry]();
        if (self.advancedBlockedEnabled) {
            advBlockingEntries.append(contentsOf: data.script);
            advBlockingEntries.append(contentsOf: data.scriptlets);
            advBlockingEntries.append(contentsOf: data.scriptJsInjectExceptions);
            advBlockingEntries.append(contentsOf: data.extendedCssBlockingWide);
            advBlockingEntries.append(contentsOf: data.extendedCssBlockingGenericDomainSensitive);
            advBlockingEntries.append(contentsOf: data.cssBlockingGenericHideExceptions);
            advBlockingEntries.append(contentsOf: data.extendedCssBlockingDomainSensitive);
            advBlockingEntries.append(contentsOf: data.cssElemhide);
            advBlockingEntries.append(contentsOf: data.other);
            advBlockingEntries.append(contentsOf: data.importantExceptions);
            advBlockingEntries.append(contentsOf: data.documentExceptions);

            advBlockingEntries = applyDomainWildcards(entries: advBlockingEntries);
        }
        
        let errorsCount = ErrorsCounter.instance.getCount();
        
        return try ConversionResult(entries: entries, advBlockingEntries: advBlockingEntries, limit: self.limit, errorsCount: errorsCount);

    }
    
    /**
     * Updates if-domain and unless-domain fields.
     * Adds wildcard to every rule
     */
    func applyDomainWildcards(entries: [BlockerEntry]) -> [BlockerEntry] {
        var result = [BlockerEntry]();
        for var entry in entries {
            entry.trigger.setIfDomain(domains: addWildcard(domains: entry.trigger.ifDomain));
            entry.trigger.setUnlessDomain(domains: addWildcard(domains: entry.trigger.unlessDomain));
            
            result.append(entry);
        }
        
        return result;
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
