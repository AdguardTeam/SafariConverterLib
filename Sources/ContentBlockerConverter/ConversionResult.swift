import Foundation

/**
 * Conversion result wrapper class
 */
public struct ConversionResult {
    /**
     * Total entries count in result
     */
    public let totalConvertedCount: Int;
    
    /**
     * Entries count in result after reducing to limit if provided
     */
    public let convertedCount: Int;
    
    /**
     * Count of errors handled
     */
    public let errorsCount: Int;
    
    /**
     * Is provided limit exceeded
     */
    public let overLimit: Bool;
    
    /**
     * Json string of content blocker rules
     */
    public let converted: String;
    
    /**
     * Count of entries in advanced blocking part
     */
    public var advancedBlockingConvertedCount = 0;
    
    /**
     * Json string of advanced content blocker rules
     */
    public var advancedBlocking: String? = nil;
    
    init(entries: [BlockerEntry], advBlockingEntries: [BlockerEntry] = [], limit: Int, errorsCount: Int) throws {
        self.totalConvertedCount = entries.count;
        
        self.overLimit = (limit > 0 && entries.count > limit);
        self.errorsCount = self.overLimit ? errorsCount + 1 : errorsCount;
        
        var limitedEntries = entries;
        if self.overLimit {
            limitedEntries = Array(entries.prefix(limit));
            
            NSLog("AG: ContentBlockerConverter: The limit is reached. Overlimit rules will be ignored.");
        }
        
        self.convertedCount = limitedEntries.count;
        self.converted = try ConversionResult.createJSONString(entries: limitedEntries);
        
        if advBlockingEntries.count > 0 {
            self.advancedBlockingConvertedCount = advBlockingEntries.count;
            self.advancedBlocking = try ConversionResult.createJSONString(entries: advBlockingEntries);
        }
    }
    
    private static func createJSONString(entries: [BlockerEntry]) throws -> String {
        let encoder = JSONEncoder();
        encoder.outputFormatting = .prettyPrinted
        
        let json = try encoder.encode(entries);
        return String(data: json, encoding: .utf8)!.replacingOccurrences(of: "\\/", with: "/");
    }
}
