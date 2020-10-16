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
            result.append(self.escapeString(value: action.selector!));
            result.append("\"");
        }

        if action.css != nil {
            result.append(",\"css\":\"");
            result.append(self.escapeString(value: action.css!));
            result.append("\"");
        }

        if action.script != nil {
            result.append(",\"script\":\"");
            result.append(self.escapeString(value: action.script!));
            result.append("\"");
        }

        if action.scriptlet != nil {
            result.append(",\"scriptlet\":\"");
            result.append(self.escapeString(value: action.scriptlet!));
            result.append("\"");
        }

        if action.scriptletParam != nil {
            result.append(",\"scriptletParam\":\"");
            result.append(self.escapeString(value: action.scriptletParam!));
            result.append("\"");
        }

        result.append("}");
        
        return result;
    }
    
    private func encodeTrigger(trigger: BlockerEntry.Trigger) -> String {
        var result = "{";
        
        result.append("\"url-filter\":\"");
        result.append(self.escapeString(value: trigger.urlFilter!));
        result.append("\"");
        
        if trigger.shortcut != nil {
            result.append("\"url-shortcut\":\"");
            result.append(self.escapeString(value: trigger.shortcut!));
            result.append("\"");
        }
        
        if (trigger.caseSensitive != nil) {
            result.append(",\"url-filter-is-case-sensitive\":");
            result.append(trigger.caseSensitive! ? "\"true\"" : "\"false\"");
        }
        
        if (trigger.regex != nil) {
            result.append(",\"regex\":\"");
            result.append(self.escapeString(value: trigger.regex!.pattern));
            result.append("\"");
        }
        
        if (trigger.loadType != nil) {
            result.append(",\"load-type\":");
            result.append(self.encodeStringArray(arr: trigger.loadType!));
        }
        
        if (trigger.resourceType != nil) {
            result.append(",\"resource-type\":");
            result.append(self.encodeStringArray(arr: trigger.resourceType!));
        }
        
        if (trigger.ifDomain != nil) {
            result.append(",\"if-domain\":");
            result.append(self.encodeStringArray(arr: trigger.ifDomain!, escape: true));
        }
        
        if (trigger.unlessDomain != nil) {
            result.append(",\"unless-domain\":");
            result.append(self.encodeStringArray(arr: trigger.unlessDomain!, escape: true));
        }
        
        result.append("}");
        
        return result;
    }
    
    private func encodeStringArray(arr: [String], escape: Bool = false) -> String {
        var result = "[";
        
        for index in 0..<arr.count {
            if (index > 0) {
                result.append(",");
            }
            
            result.append("\"");
            result.append(escape ? self.escapeString(value: arr[index]) : arr[index]);
            result.append("\"");
        }
        
        result.append("]");
        
        return result;
    }
    
    /**
     * Escapes specials in string value
     */
    func escapeString(value: String) -> String {
        var result = "";
        
        let scalars = value.unicodeScalars
        var start = scalars.startIndex
        let end = scalars.endIndex
        var idx = start
        while idx < scalars.endIndex {
            let s: String
            let c = scalars[idx]
            switch c {
                case "\\": s = "\\\\"
                case "\"": s = "\\\""
                case "\n": s = "\\n"
                case "\r": s = "\\r"
                case "\t": s = "\\t"
                case "\u{8}": s = "\\b"
                case "\u{C}": s = "\\f"
                case "\0"..<"\u{10}":
                    s = "\\u000\(String(c.value, radix: 16, uppercase: true))"
                case "\u{10}"..<" ":
                    s = "\\u00\(String(c.value, radix: 16, uppercase: true))"
                default:
                    idx = scalars.index(after: idx)
                    continue
            }
            
            if idx != start {
                result.append(String(scalars[start..<idx]));
            }
            result.append(s);
            
            idx = scalars.index(after: idx)
            start = idx
        }
        
        if start != end {
            result.append(String(scalars[start..<end]));
        }
        
        return result;
    }
}
