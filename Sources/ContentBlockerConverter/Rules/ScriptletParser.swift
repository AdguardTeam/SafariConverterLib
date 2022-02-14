import Foundation

/**
 * Scriptlets helper
 */
class ScriptletParser {
    private static let SCRIPTLET_MASK = "//scriptlet("
    private static let SCRIPTLET_MASK_LEN = SCRIPTLET_MASK.count
    
    private static let SEPARATOR_SINGLEQUOTES_PARAMS = ", '"
    private static let SEPARATOR_DOUBLEQUOTES_PARAMS = ", \""

    /**
     * Parses and validates scriptlet rule
     */
    static func parse(data: String) throws -> (name: String, json: String) {
        if (data == "" || !data.hasPrefix(ScriptletParser.SCRIPTLET_MASK)) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet")
        }
        
        let stripped = data.subString(startIndex: SCRIPTLET_MASK_LEN, toIndex: data.unicodeScalars.count - 1)

        var params = [String]()
        var cropped = stripped
        var separatorIndex: Int = 0
        
        repeat {
            cropped = cropped.subString(startIndex: separatorIndex)
            if cropped.hasPrefix(ScriptletParser.SEPARATOR_SINGLEQUOTES_PARAMS) || cropped.hasPrefix(ScriptletParser.SEPARATOR_DOUBLEQUOTES_PARAMS) {
                cropped = cropped.subString(startIndex: 2)
            }
            
            separatorIndex = cropped.indexOf(target: ScriptletParser.SEPARATOR_SINGLEQUOTES_PARAMS)
            
            if separatorIndex == -1 {
                separatorIndex = cropped.indexOf(target: ScriptletParser.SEPARATOR_DOUBLEQUOTES_PARAMS)
            }

            if separatorIndex == -1 {
                separatorIndex = cropped.unicodeScalars.count
            }
        
            params.append(cropped.subString(startIndex: 0, toIndex: separatorIndex))
        } while (separatorIndex != cropped.unicodeScalars.count)
        
        var unquotedParams = ScriptletParser.unquoteStrings(items: params);
        if (unquotedParams.count < 1) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet params");
        }
        
        let name = unquotedParams[0]
        unquotedParams.remove(at: 0)

        let json = encodeScriptletParams(name: name, args: unquotedParams)
        return (name, json)
    }

    private static func encodeScriptletParams(name: String, args: [String]?) -> String {
        var result = "{\"name\":\""
        result.append(name.escapeForJSON())
        result.append("\"")
        if args != nil {
            result.append(",\"args\":")
            result.append(JsonUtils.encodeStringArray(arr: args!, escape: true))
        }
        result.append("}")
        return result
    }
    
    private static func unquoteStrings(items: [String]) -> [String] {
        var result = [String]()
        for item in items {
            if (item.hasPrefix("'")) {
                result.append(item.subString(startIndex: 1, toIndex: item.unicodeScalars.count - 1))
            } else if (item.hasPrefix("\"")) {
                result.append(item.subString(startIndex: 1, toIndex: item.unicodeScalars.count - 1))
            }
        }

        return result
    }
    
    struct ScriptletParams: Encodable {
        let name: String
        let args: [String]?
    }

}
