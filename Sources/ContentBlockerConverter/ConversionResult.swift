import Foundation
import Shared

/**
 * Conversion result wrapper class
 */
public struct ConversionResult {
    public init(
        totalConvertedCount: Int,
        convertedCount: Int,
        errorsCount: Int,
        overLimit: Bool,
        converted: String,
        advancedBlockingConvertedCount: Int = 0,
        advancedBlocking: String? = nil,
        advancedBlockingText: String? = nil,
        message: String
    ) {
        self.totalConvertedCount = totalConvertedCount
        self.convertedCount = convertedCount
        self.errorsCount = errorsCount
        self.overLimit = overLimit
        self.converted = converted
        self.advancedBlockingConvertedCount = advancedBlockingConvertedCount
        self.advancedBlocking = advancedBlocking
        self.advancedBlockingText = advancedBlockingText
        self.message = message
    }
    
    /**
     * Total entries count in result
     */
    public var totalConvertedCount: Int;
    
    /**
     * Entries count in result after reducing to limit if provided
     */
    public var convertedCount: Int;
    
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
    public var converted: String;
    
    /**
     * Count of entries in advanced blocking part
     */
    public var advancedBlockingConvertedCount = 0;
    
    /**
     * Json string of advanced content blocker rules
     */
    public var advancedBlocking: String? = nil;

    /**
     * Text of advanced content blocker rules
     */
    public var advancedBlockingText: String? = nil;
    
    /**
     * Limit of the json size in bytes
     */
    private var maxJsonLimitBytes: Int? = nil;

    /**
     * Result message
     */
    public var message: String;
    
    public static let EMPTY_RESULT_JSON: String = "[{\"trigger\": {\"url-filter\": \".*\",\"if-domain\": [\"domain.com\"]},\"action\":{\"type\": \"ignore-previous-rules\"}}]";
    
    public init(
        entries: [BlockerEntry],
        advBlockingEntries: [BlockerEntry] = [],
        limit: Int,
        errorsCount: Int,
        message: String,
        maxJsonSizeBytes: Int? = nil
    ) {
        self.totalConvertedCount = entries.count + advBlockingEntries.count
        
        self.overLimit = (limit > 0 && entries.count > limit)
        self.errorsCount = self.overLimit ? errorsCount + 1 : errorsCount
        
        var limitedEntries = entries
        if self.overLimit {
            limitedEntries = Array(entries.prefix(limit))
            
            Logger.log("(ConversionResult) - The limit is reached. Overlimit rules will be ignored.")
        }
        
        let (encodedString, encodedCount) = ConversionResult.createJSONString(entries: limitedEntries, maxJsonSizeBytes: maxJsonSizeBytes)
        self.converted = encodedString
        self.convertedCount = encodedCount

        if advBlockingEntries.count > 0 {
            let (encodedString, encodedCount) = ConversionResult.createJSONString(
                entries: advBlockingEntries,
                maxJsonSizeBytes: maxJsonSizeBytes
            )
            self.advancedBlocking = encodedString
            self.advancedBlockingConvertedCount = encodedCount
        }
        
        self.message = message
    }
    
    private static func createJSONString(entries: [BlockerEntry], maxJsonSizeBytes: Int?) -> (String, Int) {
        if entries.isEmpty {
            return (self.EMPTY_RESULT_JSON, 0)
        }
        
        let encoder = BlockerEntryEncoder()
        let (encoded, count) = encoder.encode(entries: entries, maxJsonSizeBytes: maxJsonSizeBytes)
        
        // if nothing was converted due to limits, return empty result json
        if (count == 0) {
            return (self.EMPTY_RESULT_JSON, 0)
        }
        
        return (encoded, count)
    }
    
    static func createEmptyResult() -> ConversionResult {
        var result = ConversionResult(
            entries: [BlockerEntry](),
            advBlockingEntries: [],
            limit: 0,
            errorsCount: 0,
            message: ""
        );
        
        result.converted = self.EMPTY_RESULT_JSON;
        return result;
    }
}

extension ConversionResult: Encodable {}
