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
    ///   - cosmeticRuleContent: Cosmetic rule content, i.e. if rule text is `example.org#%#//scriptlet('name', 'arg)`,
    ///           it will be `//scriptlet('name', 'arg)`.
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

        if args.count < 1 {
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
        if str.isEmpty {
            return [String]()
        }

        let maxIndex = str.utf8.count - 1
        var pendingQuote = false
        var pendingQuoteChar: UInt8 = 0

        var result: [String] = []
        var argumentStartIndex: Int = 0
        var argumentEndIndex: Int

        for index in 0...maxIndex {
            // swiftlint:disable:next force_unwrapping
            let char = str.utf8[safeIndex: index]!

            switch char {
            case Chars.QUOTE_SINGLE, Chars.QUOTE_DOUBLE:
                if !pendingQuote {
                    pendingQuote = true
                    pendingQuoteChar = char

                    argumentStartIndex = index + 1
                } else if char == pendingQuoteChar {
                    // Ignore escaped quotes.
                    if index > 0 && str.utf8[safeIndex: index - 1] == Chars.BACKSLASH {
                        continue
                    }

                    // Not inside an argument anymore.
                    pendingQuote = false

                    // Now we can extract the quoted value (and drop the quotes).
                    argumentEndIndex = index - 1
                    if argumentEndIndex > argumentStartIndex {
                        let startIdx = str.utf8.index(
                            str.utf8.startIndex,
                            offsetBy: argumentStartIndex
                        )
                        let endIdx = str.utf8.index(str.utf8.startIndex, offsetBy: argumentEndIndex)
                        result.append(String(str[startIdx...endIdx]))
                    } else {
                        result.append("")
                    }
                }
            case delimiter, Chars.WHITESPACE:
                // Ignore delimiter and whitespace characters, they're allowed.
                break
            default:
                if !pendingQuote {
                    throw SyntaxError.invalidRule(message: "Invalid scriptlet arguments string")
                }
            }
        }

        return result
    }
}
