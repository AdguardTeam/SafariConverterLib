import Foundation
import Shared

/// Represents the final conversion result.
public struct ConversionResult {
    public static let EMPTY_RESULT_JSON: String = "[{\"trigger\": {\"url-filter\": \".*\",\"if-domain\": [\"domain.com\"]},\"action\":{\"type\": \"ignore-previous-rules\"}}]"

    static func createEmptyResult() -> ConversionResult {
        return ConversionResult(
            totalConvertedCount: 0,
            convertedCount: 0,
            errorsCount: 0,
            overLimit: false,
            converted: self.EMPTY_RESULT_JSON,
            advancedBlockingConvertedCount: 0,
            message: ""
        )
    }

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

    /// Total entries count in the compilation result (before removing overlimit).
    public var totalConvertedCount: Int

    /// Entries count in the result after reducing to limit.
    public var convertedCount: Int

    /// Count of conversion errors (i.e. count of rules that we could not convert).
    public let errorsCount: Int

    /// If true, the provided limit was exceeded.
    public let overLimit: Bool

    /// JSON string with Safari content blocker rules.
    public var converted: String

    /// Count of advanced blocking rules.
    public var advancedBlockingConvertedCount = 0

    /// JSON with advanced content blocker rules.
    public var advancedBlocking: String? = nil

    /// Text with advanced content blocker rules.
    public var advancedBlockingText: String? = nil

    /// Result message.
    public var message: String

}

extension ConversionResult: Encodable {}
