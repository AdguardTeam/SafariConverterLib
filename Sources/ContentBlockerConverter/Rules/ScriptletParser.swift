import Foundation

class ScriptletParser {
    private static let SCRIPTLET_MASK = "//scriptlet(";
    
    /**
     * Parse and validate scriptlet rule
     */
    static func parse(data: String) throws -> (name: String, json: String) {
        if (data == "" || !data.hasPrefix(ScriptletParser.SCRIPTLET_MASK)) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet");
        }
        
        let stripped = data.subString(startIndex: ScriptletParser.SCRIPTLET_MASK.count, toIndex: data.count - 1);
        
        var params = [String]();
        var cropped = stripped;
        var separatorIndex: String.Index? = cropped.startIndex;
        
        repeat {
            cropped = String(cropped.suffix(from: separatorIndex!));
            if (cropped.hasPrefix(", ")) {
                cropped = cropped.subString(startIndex: 2);
            }
            
            // TODO: check is not escaped
            separatorIndex = cropped.firstIndex(of: ",");
            if (separatorIndex == nil) {
                separatorIndex = cropped.endIndex;
            }
        
            params.append(String(cropped.prefix(upTo: separatorIndex!)));
        } while (separatorIndex != cropped.endIndex);
        
        var unquotedParams = ScriptletParser.unquoteStrings(items: params);
        if (unquotedParams.count < 1) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet params");
        }
        
        let name = unquotedParams[0];
        unquotedParams.remove(at: 0);
        
        let json = try JSONEncoder().encode(unquotedParams);
        return (name, String(data: json, encoding: .utf8)!);
    }
    
    private static func unquoteStrings(items: [String]) -> [String] {
        var result = [String]();
        for item in items {
            if (item.hasPrefix("'")) {
                result.append(item.subString(startIndex: 1, toIndex: item.count - 1));
            } else if (item.hasPrefix("\"")) {
                result.append(item.subString(startIndex: 1, toIndex: item.count - 1));
            }
        }
        
        return result;
    }
}
