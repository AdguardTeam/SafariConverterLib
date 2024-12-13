import Foundation
import Shared

/**
 * Blocker entries JSON encoder
 */
class BlockerEntryEncoder {
    
    /**
     * Encodes an array of blocker entries into a JSON string representation with an optional maximum size limit.
     *
     * - Parameters:
     *   - entries: The array of BlockerEntry objects to be encoded.
     *   - maxJsonSizeBytes: The optional maximum size in bytes for the resulting JSON string.
     *                       If nil, there is no size limit.
     *
     * - Returns: A tuple containing:
     *             1. A JSON-formatted string containing the encoded blocker entries,
     *                adhering to the optional maxJsonSizeBytes limit.
     *             2. An integer representing the number of entries successfully encoded into the JSON string.
     *
     * Note: The maxJsonSizeBytes is in bytes, calculated based on the UTF-8 representation of the string.
     *       If the size limit is reached, no more entries will be encoded and the function will break out of the loop.
     */
    func encode(entries: [BlockerEntry], maxJsonSizeBytes: Int? = nil) -> (String, Int) {
        var result = "["
        var currentSize = 2 // Account for the opening and closing brackets in the JSON string
        var encodedCount = 0 // To keep track of successfully encoded entries
        
        for index in 0..<entries.count {
            // Encode the individual entry to its JSON representation
            let entryJSON = encodeEntry(entry: entries[index])
            // Calculate the size in bytes of the JSON representation
            let entrySize = entryJSON.utf8.count
            // Calculate the size of the comma separator (if needed)
            let commaSize = index == 0 ? 0 : 1 // Account for comma separator if not the first entry
            
            // Check if adding the next entry would exceed the maxSize limit
            if let maxSize = maxJsonSizeBytes, currentSize + entrySize + commaSize > maxSize {
                Logger.log("(BlockerEntryEncoder) - The maxSize limit is reached. Overlimit entries will be ignored.");
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
        let action = encodeAction(action: entry.action);
        let trigger = encodeTrigger(trigger: entry.trigger);
        
        var result = "{\"trigger\":";
        result.append(trigger);
        result.append(",\"action\":");
        result.append(action);
        result.append("}");
        return result;
    }
    
    private func encodeAction(action: BlockerEntry.Action) -> String {
        var result = "{";

        result.append("\"type\":\"");
        result.append(action.type);
        result.append("\"");

        if action.selector != nil {
            result.append(",\"selector\":\"");
            result.append(action.selector!.escapeForJSON());
            result.append("\"");
        }

        if action.css != nil {
            result.append(",\"css\":\"");
            result.append(action.css!.escapeForJSON());
            result.append("\"");
        }

        if action.script != nil {
            result.append(",\"script\":\"");
            result.append(action.script!.escapeForJSON());
            result.append("\"");
        }

        if action.scriptlet != nil {
            result.append(",\"scriptlet\":\"");
            result.append(action.scriptlet!.escapeForJSON());
            result.append("\"");
        }

        if action.scriptletParam != nil {
            result.append(",\"scriptletParam\":\"");
            result.append(action.scriptletParam!.escapeForJSON());
            result.append("\"");
        }

        result.append("}");
        
        return result;
    }
    
    private func encodeTrigger(trigger: BlockerEntry.Trigger) -> String {
        var result = "{"
        
        result.append("\"url-filter\":\"")
        result.append(trigger.urlFilter!.escapeForJSON())
        result.append("\"")
        
        if trigger.shortcut != nil {
            result.append("\"url-shortcut\":\"")
            result.append(trigger.shortcut!.escapeForJSON())
            result.append("\"")
        }
        
        if (trigger.caseSensitive != nil) {
            result.append(",\"url-filter-is-case-sensitive\":")
            result.append(trigger.caseSensitive! ? "true" : "false")
        }
        
        if (trigger.regex != nil) {
            result.append(",\"regex\":\"")
            result.append(trigger.regex!.pattern.escapeForJSON())
            result.append("\"")
        }
        
        if (trigger.loadType != nil) {
            result.append(",\"load-type\":")
            result.append(JsonUtils.encodeStringArray(arr: trigger.loadType!))
        }
        
        if (trigger.resourceType != nil) {
            result.append(",\"resource-type\":")
            result.append(JsonUtils.encodeStringArray(arr: trigger.resourceType!))
        }
        
        if (trigger.loadContext != nil) {
            result.append(",\"load-context\":")
            result.append(JsonUtils.encodeStringArray(arr: trigger.loadContext!))
        }

        if (trigger.ifDomain != nil) {
            result.append(",\"if-domain\":")
            result.append(JsonUtils.encodeStringArray(arr: trigger.ifDomain!, escape: true))
        }

        if (trigger.unlessDomain != nil) {
            result.append(",\"unless-domain\":")
            result.append(JsonUtils.encodeStringArray(arr: trigger.unlessDomain!, escape: true))
        }

        result.append("}")

        return result
    }
}
