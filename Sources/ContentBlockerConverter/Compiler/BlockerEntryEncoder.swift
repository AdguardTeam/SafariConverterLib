import Foundation

/**
 * Blocker entries JSON encoder
 * TODO: Escape sensitive strings
 */
class BlockerEntryEncoder {
    
    /**
     * Encodes array of blocker entries
     */
    func encode(entries: [BlockerEntry]) -> String {
        var result = "[";
        if (entries.count > 0) {
            for entry in entries {
                result += self.encodeEntry(entry: entry);
                result += ",";
            }
            
            result = (result as NSString).substring(to: (result as NSString).length - 2);
        }
        
        result += "]";
        
        return result;
    }
    
    private func encodeEntry(entry: BlockerEntry) -> String {
        let action = encodeAction(action: entry.action);
        let trigger = encodeTrigger(trigger: entry.trigger);
        
        return "{\"trigger\":\(trigger),\"action\":\(action)}";
    }
    
    private func encodeAction(action: BlockerEntry.Action) -> String {
        var result = "{";
        
        result += "\"type\":\"\(action.type)\"";
        
        if action.selector != nil {
            result += ",\"selector\":\"\(action.selector!)\"";
        }
        
        if action.css != nil {
            result += ",\"css\":\"\(action.css!)\"";
        }
        
        if action.script != nil {
            result += ",\"script\":\"\(action.script!)\"";
        }
        
        if action.scriptlet != nil {
            result += ",\"scriptlet\":\"\(action.scriptlet!)\"";
        }
        
        if action.scriptletParam != nil {
            result += ",\"scriptletParam\":\"\(action.scriptletParam!)\"";
        }
        
        result += "}";
        
        return result;
    }
    
    private func encodeTrigger(trigger: BlockerEntry.Trigger) -> String {
        var result = "{";
        
        if trigger.urlFilter != nil {
            result += "\"url-filter\":\"\(trigger.urlFilter!)\",";
        }
        
        if trigger.shortcut != nil {
            result += "\"url-shortcut\":\"\(trigger.shortcut!)\",";
        }
        
        if (trigger.caseSensitive != nil) {
            result += "\"url-filter-is-case-sensitive\":\"\(trigger.caseSensitive! ? "true" : "false")\",";
        }
        
        if (trigger.regex != nil) {
            result += "\"regex\":\"\(trigger.regex!)\",";
        }
        
        if (trigger.loadType != nil) {
            result += "\"load-type\":[";
            for item in trigger.loadType! {
                result += "\"\(item)\",";
            }
            
            result = (result as NSString).substring(to: (result as NSString).length - 2);
            result += "],"
        }
        
        if (trigger.resourceType != nil) {
            result += "\"resource-type\":[";
            for item in trigger.resourceType! {
                result += "\"\(item)\",";
            }
            
            result = (result as NSString).substring(to: (result as NSString).length - 2);
            result += "],"
        }
        
        if (trigger.ifDomain != nil) {
            result += "\"if-domain\":[";
            for item in trigger.ifDomain! {
                result += "\"\(item)\",";
            }
            
            result = (result as NSString).substring(to: (result as NSString).length - 2);
            result += "],"
        }
        
        if (trigger.unlessDomain != nil) {
            result += "\"unless-domain\":[";
            for item in trigger.unlessDomain! {
                result += "\"\(item)\",";
            }
            
            result = (result as NSString).substring(to: (result as NSString).length - 2);
            result += "],"
        }
        
        result = (result as NSString).substring(to: (result as NSString).length - 2);
        
        result += "}";
        
        return result;
    }
}
