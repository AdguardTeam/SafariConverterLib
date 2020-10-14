import Foundation
/**
 * Conversion result wrapper class
 */
public struct ConversionResult: Encodable {
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
    
    /**
     * Result message
     */
    public var message: String;
    
    init(entries: [BlockerEntry], advBlockingEntries: [BlockerEntry] = [], limit: Int, errorsCount: Int, message: String) throws {
        self.totalConvertedCount = entries.count;
        
        self.overLimit = (limit > 0 && entries.count > limit);
        self.errorsCount = self.overLimit ? errorsCount + 1 : errorsCount;
        
        var limitedEntries = entries;
        if self.overLimit {
            limitedEntries = Array(entries.prefix(limit));
            
            Logger.log("AG: ContentBlockerConverter: The limit is reached. Overlimit rules will be ignored.");
        }
        
        self.convertedCount = limitedEntries.count;
        self.converted = try ConversionResult.createJSONString(entries: limitedEntries);
        
        if advBlockingEntries.count > 0 {
            self.advancedBlockingConvertedCount = advBlockingEntries.count;
            self.advancedBlocking = try ConversionResult.createJSONString(entries: advBlockingEntries);
        }
        
        self.message = message;
    }
    
    private static func createJSONString(entries: [BlockerEntry]) throws -> String {
        let encoder = BlockerEntryEncoder();
        return encoder.encode(entries: entries);
    }
}
