import Foundation

/**
 * Blocker entries JSON encoder
 * TODO: Escape sensitive strings
 * TODO: Remove PMJSON dep
 */
class BlockerEntryEncoder {
    
    /**
     * Encodes array of blocker entries
     */
    func encode(entries: [BlockerEntry]) -> String {
        var result = "[";
        
        for index in 0..<entries.count {
            if (index > 0) {
                result.append(",");
            }
            
            result.append(self.encodeEntry(entry: entries[index]));
        }
        
        result.append("]");
        
        return result;
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
            result.append(action.selector!);
            result.append("\"");
        }

        if action.css != nil {
            result.append(",\"css\":\"");
            result.append(action.css!);
            result.append("\"");
        }

        if action.script != nil {
            result.append(",\"script\":\"");
            result.append(action.script!);
            result.append("\"");
        }

        if action.scriptlet != nil {
            result.append(",\"scriptlet\":\"");
            result.append(action.scriptlet!);
            result.append("\"");
        }

        if action.scriptletParam != nil {
            result.append(",\"scriptletParam\":\"");
            result.append(action.scriptletParam!);
            result.append("\"");
        }

        result.append("}");
        
        return result;
    }
    
    private func encodeTrigger(trigger: BlockerEntry.Trigger) -> String {
        var result = "{";
        
        result.append("\"url-filter\":\"");
        result.append(trigger.urlFilter!);
        result.append("\"");
        
        if trigger.shortcut != nil {
            result.append("\"url-shortcut\":\"");
            result.append(trigger.shortcut!);
            result.append("\"");
        }
        
        if (trigger.caseSensitive != nil) {
            result.append(",\"url-filter-is-case-sensitive\":");
            result.append(trigger.caseSensitive! ? "\"true\"" : "\"false\"");
        }
        
        if (trigger.regex != nil) {
            result.append(",\"regex\":\"");
            result.append(trigger.regex!.pattern);
            result.append("\"");
        }
        
        if (trigger.loadType != nil) {
            result.append(",\"load-type\":");
            result.append(self.encodeStringArray(arr: trigger.loadType!));
            result.append("\"");
        }
        
        if (trigger.resourceType != nil) {
            result.append("\"resource-type\":");
            result.append(self.encodeStringArray(arr: trigger.resourceType!));
        }
        
        if (trigger.ifDomain != nil) {
            result.append(",\"if-domain\":");
            result.append(self.encodeStringArray(arr: trigger.ifDomain!));
        }
        
        if (trigger.unlessDomain != nil) {
            result.append(",\"unless-domain\":");
            result.append(self.encodeStringArray(arr: trigger.unlessDomain!));
        }
        
        result.append("}");
        
        return result;
    }
    
    private func encodeStringArray(arr: [String]) -> String {
        var result = "[";
        
        for index in 0..<arr.count {
            if (index > 0) {
                result.append(",");
            }
            
            result.append("\"");
            result.append(arr[index]);
            result.append("\"");
        }
        
        result.append("]");
        
        return result;
    }
}
