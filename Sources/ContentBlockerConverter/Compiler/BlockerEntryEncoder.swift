import Foundation

/// Blocker entries JSON encoder
class BlockerEntryEncoder {
    /// Encodes an array of blocker entries into a JSON string representation
    /// with an optional maximum size limit.
    ///
    /// - Parameters:
    ///   - entries: The array of BlockerEntry objects to be encoded.
    ///   - maxJsonSizeBytes: The optional maximum size in bytes for the
    ///                       resulting JSON string. If nil, there is no size
    ///                       limit.
    ///
    /// - Returns: A tuple containing:
    ///   - A JSON-formatted string containing the encoded blocker
    ///     entries, adhering to the optional maxJsonSizeBytes limit.
    ///   - An integer representing the number of entries successfully
    ///     encoded into the JSON string.
    ///
    /// Note: The `maxJsonSizeBytes` is in bytes, calculated based on the UTF-8
    /// representation of the string. If the size limit is reached, no more
    /// entries will be encoded and the function will break out of the loop.
    func encode(entries: [BlockerEntry], maxJsonSizeBytes: Int? = nil) -> (String, Int) {
        var result = "["
        // Account for the opening and closing brackets in the JSON string
        var currentSize = 2
        // To keep track of successfully encoded entries
        var encodedCount = 0

        for index in 0..<entries.count {
            // Encode the individual entry to its JSON representation
            let entryJSON = encodeEntry(entry: entries[index])
            // Calculate the size in bytes of the JSON representation
            let entrySize = entryJSON.utf8.count
            // Calculate the size of the comma separator (if needed)
            // Account for comma separator if not the first entry
            let commaSize = index == 0 ? 0 : 1

            // Check if adding the next entry would exceed the maxSize limit
            if let maxSize = maxJsonSizeBytes, currentSize + entrySize + commaSize > maxSize {
                Logger.log(
                    "(BlockerEntryEncoder) - The maxSize limit is reached. Overlimit entries will be ignored."
                )
                break
            }

            // Append a comma separator if this is not the first entry
            if index > 0 {
                result.append(",")
            }

            // Append the JSON representation of the entry to the result string
            result.append(entryJSON)
            // Update the current size in bytes of the resulting JSON string
            currentSize += entrySize + commaSize
            // Increment successfully encoded count
            encodedCount += 1
        }

        result.append("]")

        return (result, encodedCount)
    }

    private func encodeEntry(entry: BlockerEntry) -> String {
        let action = encodeAction(action: entry.action)
        let trigger = encodeTrigger(trigger: entry.trigger)

        var result = "{\"trigger\":"
        result.append(trigger)
        result.append(",\"action\":")
        result.append(action)
        result.append("}")

        return result
    }

    private func encodeAction(action: BlockerEntry.Action) -> String {
        var result = "{"

        result.append("\"type\":\"")
        result.append(action.type)
        result.append("\"")

        if let selector = action.selector {
            result.append(",\"selector\":\"")
            result.append(selector.escapeForJSON())
            result.append("\"")
        }

        result.append("}")

        return result
    }

    private func encodeTrigger(trigger: BlockerEntry.Trigger) -> String {
        var result = "{"

        result.append("\"url-filter\":\"")
        result.append(trigger.urlFilter?.escapeForJSON() ?? "")
        result.append("\"")

        if let caseSensitive = trigger.caseSensitive {
            result.append(",\"url-filter-is-case-sensitive\":")
            result.append(caseSensitive ? "true" : "false")
        }

        if let loadType = trigger.loadType {
            result.append(",\"load-type\":")
            result.append(loadType.encodeToJSON())
        }

        if let resourceType = trigger.resourceType {
            result.append(",\"resource-type\":")
            result.append(resourceType.encodeToJSON())
        }

        if let loadContext = trigger.loadContext {
            result.append(",\"load-context\":")
            result.append(loadContext.encodeToJSON())
        }

        if let ifDomain = trigger.ifDomain {
            result.append(",\"if-domain\":")
            result.append(ifDomain.encodeToJSON(escape: true))
        }

        if let unlessDomain = trigger.unlessDomain {
            result.append(",\"unless-domain\":")
            result.append(unlessDomain.encodeToJSON(escape: true))
        }

        result.append("}")

        return result
    }
}
