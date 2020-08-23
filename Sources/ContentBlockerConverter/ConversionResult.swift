import Foundation

struct ConversionResult {
    
    let totalConvertedCount: Int;
    let convertedCount: Int;
    let errorsCount: Int;
    let overLimit: Bool;
    let converted: String;
    
    var advancedBlockingConvertedCount = 0;
    var advancedBlocking: String? = nil;
    
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
        return String(data: json, encoding: .utf8)!;
    }
}
