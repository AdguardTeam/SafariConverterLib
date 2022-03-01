import Foundation

/**
 * Scriptlets helper
 */
class ScriptletParser {
    public static let SCRIPTLET_MASK = "//scriptlet("
    private static let SCRIPTLET_MASK_LEN = SCRIPTLET_MASK.count

    /**
     Parses and validates a scriptlet rule.
     - Parameter data: the full scriptlet rule, i.e. "//scriptlet('scriptletName', 'arg1', 'arg2')"
     - Returns: the scriptlet name and a json with it's arguments.
     - Throws: SyntaxError.invalidRule
     */
    static func parse(data: String) throws -> (name: String, json: String) {
        if (data == "" || !data.hasPrefix(ScriptletParser.SCRIPTLET_MASK)) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet")
        }

        let str = data as NSString

        // Without the scriptlet prefix the string looks like:
        // "scriptletname", "arg1", "arg2", etc
        let argumentsStr = str.substring(with: NSRange(location: SCRIPTLET_MASK_LEN, length: str.length - SCRIPTLET_MASK_LEN - 1)) as NSString

        // Now we just get an array of these arguments
        let params = ScriptletParser.splitByDelimiterNotQuoted(str: argumentsStr as NSString, delimiter: ",".utf16.first!)

        var unquotedParams = try ScriptletParser.unquoteStrings(items: params);
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

    /**
     Splits the string using the specified delimiter. Ignores the delimiter if it's inside a
     string enclosed in quotes.
     - Parameters:
       - str: the string to split.
       - delimiter: the delimiter to use.
     - Returns: an array of string parts. Note that string parts are trimmed.
     */
    private static func splitByDelimiterNotQuoted(str: NSString, delimiter: unichar) -> [String] {
        if str.length == 0 {
            return [String]()
        }

        let quoteSingle: unichar = "'".utf16.first!
        let quoteDouble: unichar = "\"".utf16.first!
        let escapeChar: unichar = "\\".utf16.first!

        var pendingQuote = false
        var pendingQuoteChar: unichar = quoteSingle // need at least some value here
        var delimiterIndexes = [Int]()
        for index in 0...str.length - 1 {
            let char = str.character(at: index)
            switch char {
            case quoteSingle, quoteDouble:
                if !pendingQuote {
                    pendingQuote = true
                    pendingQuoteChar = char
                } else if char == pendingQuoteChar {
                    // ignore escaped
                    if (index > 0 && str.character(at: index - 1) == escapeChar) {
                        continue
                    }

                    pendingQuote = false
                }
                break
            case delimiter:
                // ignore if we're inside quotes
                if !pendingQuote {
                    delimiterIndexes.append(index)
                }
            default:
                break
            }
        }

        var result = [String]()
        var previous = 0
        for ind in delimiterIndexes {
            if ind > previous {
                let part = str.substring(with: NSRange(location: previous, length: ind - previous)).trimmingCharacters(in: .whitespaces)
                result.append(part)
            } else {
                result.append("")
            }
            previous = ind + 1
        }

        result.append(str.substring(from: previous).trimmingCharacters(in: .whitespaces))

        return result
    }

    /**
     Unquotes every string from the specified array.
     - Parameter items: strings to unquote.
     - Returns: an array of unquoted strings.
     - Throws: a SyntaxError.invalidRule in case if there's any string that's not enclosed in quotes.
     */
    private static func unquoteStrings(items: [String]) throws -> [String] {
        var result = [String]()
        for item in items {
            let str = item as NSString
            if item.hasPrefix("'") && item.hasSuffix("'") {
                result.append(str.substring(with: NSRange(location: 1, length: str.length - 2)))
            } else if item.hasPrefix("\"") && item.hasSuffix("\"") {
                result.append(str.substring(with: NSRange(location: 1, length: str.length - 2)))
            } else {
                throw SyntaxError.invalidRule(message: "scriptlet argument not enclosed in quotes")
            }
        }

        return result
    }

    struct ScriptletParams: Encodable {
        let name: String
        let args: [String]?
    }

}
