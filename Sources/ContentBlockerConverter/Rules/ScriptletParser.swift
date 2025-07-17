import Foundation

/// Helper for working with scriptlet rules.
public enum ScriptletParser {
    public static let SCRIPTLET_MASK = "//scriptlet("
    private static let SCRIPTLET_MASK_LEN = SCRIPTLET_MASK.count

    /// Returns true if cosmetic rule content is a scriptlet.
    public static func isScriptlet(cosmeticRuleContent: String) -> Bool {
        return cosmeticRuleContent.utf8.starts(with: SCRIPTLET_MASK.utf8)
    }

    /// Parses and validates a scriptlet rule.
    ///
    /// - Parameters:
    ///   - cosmeticRuleContent: Cosmetic rule content, i.e. if rule text is
    ///     `example.org#%#//scriptlet('name', 'arg)`, it will be
    ///     `//scriptlet('name', 'arg)`.
    /// - Returns: scriptlet name and its arguments.
    /// - Throws:`SyntaxError.invalidRule` if failed to parse.
    public static func parse(cosmeticRuleContent: String) throws -> (name: String, args: [String]) {
        if !isScriptlet(cosmeticRuleContent: cosmeticRuleContent) {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet")
        }

        // Without the scriptlet prefix the string looks like:
        // "scriptletname", "arg1", "arg2", etc
        let utf8 = cosmeticRuleContent.utf8
        let argumentsStrIndex = utf8.index(utf8.startIndex, offsetBy: SCRIPTLET_MASK_LEN)
        // Do not include the last character as it's a bracket.
        let argumentsEndIndex = utf8.index(utf8.endIndex, offsetBy: -1)
        let argumentsStr = cosmeticRuleContent[argumentsStrIndex..<argumentsEndIndex]

        // Now we just get an array of these arguments
        var args: [String] = try ScriptletParser.extractArguments(
            str: argumentsStr,
            delimiter: Chars.COMMA
        )

        if args.count < 1 || args[0].isEmpty {
            throw SyntaxError.invalidRule(message: "Invalid scriptlet params")
        }

        let name = args[0]
        args.remove(at: 0)

        return (name, args)
    }

    /// Extracts the scriptlet arguments from the string.
    ///
    /// - Parameters:
    ///    - str: the arguments string (i.e. "'arg1', 'arg2', 'arg3'")
    ///    - delimiter: the delimiter for arguments.
    /// - Returns: an array of arguments.
    /// - Throws: SyntaxError.invalidRule
    private static func extractArguments(str: Substring, delimiter: UInt8) throws -> [String] {
        var result: [String] = []
        var current: [UInt8] = []
        var iterator = str.utf8.makeIterator()

        var inQuotes = false
        var quoteChar: UInt8 = 0

        while let byte = iterator.next() {
            switch byte {
            case delimiter where !inQuotes:
                continue

            case UInt8(ascii: "\""), UInt8(ascii: "'"):
                if !inQuotes {
                    inQuotes = true
                    quoteChar = byte
                } else if quoteChar == byte {
                    inQuotes = false
                    if let str = String(bytes: current, encoding: .utf8) {
                        result.append(str)
                    }
                    current = []
                } else {
                    current.append(byte)
                }

            case UInt8(ascii: "\\") where inQuotes:
                guard let next = iterator.next() else {
                    throw SyntaxError.invalidRule(
                        message: "Invalid escape sequence in matching arguments"
                    )
                }

                if next == quoteChar || next == UInt8(ascii: "\\") {
                    current.append(next)
                } else {
                    // Keep the backslash and the following char literally
                    current.append(UInt8(ascii: "\\"))
                    current.append(next)
                }

            case UInt8(ascii: " ") where !inQuotes:
                continue

            default:
                if inQuotes {
                    current.append(byte)
                } else {
                    throw SyntaxError.invalidRule(message: "Invalid arguments string")
                }
            }
        }

        if inQuotes {
            throw SyntaxError.invalidRule(message: "Unmatched quotes in scriptlet arguments")
        }

        if !current.isEmpty {
            throw SyntaxError.invalidRule(message: "Invalid arguments string")
        }

        return result
    }
}
