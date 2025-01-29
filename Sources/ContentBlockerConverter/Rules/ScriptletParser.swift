import Foundation

/// Helper for working with scriptlet rules.
public class ScriptletParser {
    public static let SCRIPTLET_MASK = "//scriptlet("
    private static let SCRIPTLET_MASK_LEN = SCRIPTLET_MASK.count

    /// Parses and validates a scriptlet rule.
    ///
    /// TODO(ameshkov): !!! Rewrite, it should return just the list of arguments.
    ///
    /// - Parameters:
    ///  - data: the full scriptlet rule, i.e. `//scriptlet('scriptletName', 'arg1', 'arg2')`
    /// - Returns: the scriptlet name and a json with it's arguments.
    /// - Throws: SyntaxError.invalidRule if failed to parse.
    public static func parse(data: String) throws -> (name: String, json: String) {
        if (data.isEmpty || !data.utf8.starts(with: ScriptletParser.SCRIPTLET_MASK.utf8)) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet")
        }

        // Without the scriptlet prefix the string looks like:
        // "scriptletname", "arg1", "arg2", etc
        let argumentsStrIndex = data.utf8.index(data.utf8.startIndex, offsetBy: SCRIPTLET_MASK_LEN)
        // Do not include the last character as it's a bracket.
        let argumentsEndIndex = data.utf8.index(data.utf8.endIndex, offsetBy: -1)
        let argumentsStr = data[argumentsStrIndex..<argumentsEndIndex]

        // Now we just get an array of these arguments
        var params = try ScriptletParser.extractArguments(str: argumentsStr, delimiter: Chars.COMMA)

        if (params.count < 1) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet params");
        }

        let name = params[0]
        params.remove(at: 0)

        let json = encodeScriptletParams(name: name, args: params)

        return (name, json)
    }

    /// Encodes scriptlet parameters as a JSON string with name and arguments.
    private static func encodeScriptletParams(name: String, args: [String]?) -> String {
        var result = "{\"name\":\""
        result.append(name.escapeForJSON())
        result.append("\"")
        if args != nil {
            result.append(",\"args\":")
            result.append(args!.encodeToJSON(escape: true))
        }
        result.append("}")

        return result
    }

    /// Extracts the scriptlet arguments from the string.
    ///
    /// - Parameters:
    ///    - str: the arguments string (i.e. "'arg1', 'arg2', 'arg3'")
    ///    - delimiter: the delimiter for arguments.
    /// - Returns: an array of arguments.
    /// - Throws: SyntaxError.invalidRule
    private static func extractArguments(str: Substring, delimiter: UInt8) throws -> [String] {
        if str.isEmpty {
            return [String]()
        }

        let maxIndex = str.utf8.count - 1
        var pendingQuote = false
        var pendingQuoteChar: UInt8 = 0

        var result = [String]()
        var argumentStartIndex: Int = 0;
        var argumentEndIndex: Int;

        for index in 0...maxIndex {
            let char = str.utf8[safeIndex: index]!

            switch char {
            case Chars.QUOTE_SINGLE, Chars.QUOTE_DOUBLE:
                if !pendingQuote {
                    pendingQuote = true
                    pendingQuoteChar = char

                    argumentStartIndex = index + 1;
                } else if char == pendingQuoteChar {
                    // Ignore escaped quotes.
                    if (index > 0 && str.utf8[safeIndex: index - 1] == Chars.BACKSLASH) {
                        continue
                    }

                    // Not inside an argument anymore.
                    pendingQuote = false

                    // Now we can extract the quoted value (and drop the quotes).
                    argumentEndIndex = index - 1;
                    if argumentEndIndex > argumentStartIndex {
                        let startIdx = str.utf8.index(str.utf8.startIndex, offsetBy: argumentStartIndex)
                        let endIdx = str.utf8.index(str.utf8.startIndex, offsetBy: argumentEndIndex)
                        result.append(String(str[startIdx...endIdx]))
                    } else {
                        result.append("")
                    }
                }

                break
            case delimiter, Chars.WHITESPACE:
                // Ignore delimiter and whitespace characters, they're allowed.
                break
            default:
                if !pendingQuote {
                    throw SyntaxError.invalidRule(message: "Invalid scriptlet arguments string")
                }

                break
            }
        }

        return result
    }

    /// Represents a scriptlet signature, i.e. the scriptlet name and its parameters.
    ///
    /// A normal scriptlet rule looks like this:
    /// //scriptlet('scriptlet name', 'param1', 'param2')
    ///
    /// ScriptletParams object representing this will look like this:
    ///
    /// - name: "scriptlet name"
    /// - args: [ "param1", "param2" ]
    struct ScriptletParams: Encodable {
        let name: String
        let args: [String]?
    }
}
