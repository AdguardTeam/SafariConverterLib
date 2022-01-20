import Foundation

/**
 * Blocker entries JSON encoder
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
        var result = "{";
        
        result.append("\"url-filter\":\"");
        result.append(trigger.urlFilter!.escapeForJSON());
        result.append("\"");
        
        if trigger.shortcut != nil {
            result.append("\"url-shortcut\":\"");
            result.append(trigger.shortcut!.escapeForJSON());
            result.append("\"");
        }
        
        if (trigger.caseSensitive != nil) {
            result.append(",\"url-filter-is-case-sensitive\":");
            result.append(trigger.caseSensitive! ? "\"true\"" : "\"false\"");
        }
        
        if (trigger.regex != nil) {
            result.append(",\"regex\":\"");
            result.append(trigger.regex!.pattern.escapeForJSON());
            result.append("\"");
        }
        
        if (trigger.loadType != nil) {
            result.append(",\"load-type\":");
            result.append(JsonUtils.encodeStringArray(arr: trigger.loadType!));
        }
        
        if (trigger.resourceType != nil) {
            result.append(",\"resource-type\":");
            result.append(JsonUtils.encodeStringArray(arr: trigger.resourceType!));
        }
        
        if (trigger.loadContext != nil) {
            result.append(",\"load-context\":");
            result.append(JsonUtils.encodeStringArray(arr: trigger.loadContext!));
        }
        
        if (trigger.ifDomain != nil) {
            result.append(",\"if-domain\":");
            result.append(JsonUtils.encodeStringArray(arr: trigger.ifDomain!, escape: true));
        }
        
        if (trigger.unlessDomain != nil) {
            result.append(",\"unless-domain\":");
            result.append(JsonUtils.encodeStringArray(arr: trigger.unlessDomain!, escape: true));
        }
        
        result.append("}");
        
        return result;
    }
}
