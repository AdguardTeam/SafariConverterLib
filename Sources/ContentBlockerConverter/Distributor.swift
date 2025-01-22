import Foundation

/// Distributor creates a Safari JSON and checks for additional limitations while doing that.
///
/// TODO(ameshkov): !!! Fix comment
class Distributor {
    private let limit: Int
    private let maxJsonSizeBytes: Int?

    init(
        limit: Int,
        maxJsonSizeBytes: Int? = nil
    ) {
        self.limit = limit
        self.maxJsonSizeBytes = maxJsonSizeBytes
    }

    /// Creates an array of rules for Safari content blocker in the correct order.
    private func createEntries(from result: CompilationResult) -> [BlockerEntry] {
        var entries = [BlockerEntry]()

        entries.append(contentsOf: result.cssBlockingWide)
        entries.append(contentsOf: result.cssBlockingGenericDomainSensitive)
        entries.append(contentsOf: result.cssBlockingGenericHideExceptions)
        entries.append(contentsOf: result.cssBlockingDomainSensitive)
        entries.append(contentsOf: result.cssElemhide)
        entries.append(contentsOf: result.urlBlocking)
        entries.append(contentsOf: result.other)
        entries.append(contentsOf: result.important)
        entries.append(contentsOf: result.importantExceptions)
        entries.append(contentsOf: result.documentExceptions)

        return entries
    }

    /// Creates the final conversion result from the compilation result object.
    func createConversionResult(data: CompilationResult) -> ConversionResult {
        let entries = createEntries(from: data)

        let message = data.message
        let totalConvertedCount = entries.count
        let overLimit = (limit > 0 && entries.count > limit)
        let errorsCount = overLimit ? data.errorsCount + 1 : data.errorsCount

        var limitedEntries = entries
        if overLimit {
            limitedEntries = Array(entries.prefix(limit))

            Logger.log("(ConversionResult) - The limit is reached. Overlimit rules will be ignored.")
        }

        let (converted, convertedCount) = Distributor.createJSONString(entries: limitedEntries, maxJsonSizeBytes: maxJsonSizeBytes)

        return ConversionResult(
            totalConvertedCount: totalConvertedCount,
            convertedCount: convertedCount,
            errorsCount: errorsCount,
            overLimit: overLimit,
            converted: converted,
            message: message
        )
    }

    /// Serializes a list of `BlockerEntry` to JSON.
    private static func createJSONString(entries: [BlockerEntry], maxJsonSizeBytes: Int?) -> (String, Int) {
        if entries.isEmpty {
            return (ConversionResult.EMPTY_RESULT_JSON, 0)
        }

        let encoder = BlockerEntryEncoder()
        let (encoded, count) = encoder.encode(entries: entries, maxJsonSizeBytes: maxJsonSizeBytes)

        // if nothing was converted due to limits, return empty result json
        if count == 0 {
            return (ConversionResult.EMPTY_RESULT_JSON, 0)
        }

        return (encoded, count)
    }
}
