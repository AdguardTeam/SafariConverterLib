import Foundation

/// Takes care of validation of regular expressions that can used by Safari.
public enum SafariRegex {
    /// Safari does not support some regular expressions so we do some additional validations.
    ///
    /// Supported expressions:
    /// - `.*`: Matches all strings with a dot appearing zero or more times. Use this syntax to match every URL.
    /// - `.`: Matches any character.
    /// - `\.`: Explicitly matches the dot character.
    /// - `[a-b]`: Matches a range of alphabetic characters.
    /// - `(abc)`: Matches groups of the specified characters.
    /// - `+`: Matches the preceding term one or more times.
    /// - `*`: Matches the preceding character zero or more times.
    /// - `?`: Matches the preceding character zero or one time.
    ///
    /// Also, it only supports ASCII.
    ///
    /// Here is what was figured out while experimenting:
    /// - Brackets for groups MUST be balanced, otherwise it will not tolerate that.
    /// - Brackets for character ranges SHOULD be balanced (does not break anything if unbalanced).
    /// - Explicitly matching special characters is allowed:
    ///   - Allowed: `\.`, `\*`, `\+`, `\/`, `\[`, `\(`, `\]`, `\)`, `\|`, `\?`, `{`, `}`.
    ///   - Any other is not allowed.
    /// - MUST keep track of quantifiable characters (i.e. those to which you can apply `\*` `?` `+`) .
    /// - Special characters are not quantifiable unless escaped.
    /// - Nested groups are allowed (but can not mixed).
    /// - `|`, `{`, `}` ruin regex unless escaped or inside a character range.
    /// - `^` and `$` must be either in the beginning / end of the pattern or escaped or inside a character range.
    /// - `\*`, `+`, `?` treated as normal characters when inside a character range.
    ///
    /// - Parameters:
    ///   - pattern: regular expression to check.
    ///
    /// - Returns: true if the regular expression is most likely compatible.
    public static func isSupported(pattern: String) -> Result<Void, Error> {
        let utf8 = pattern.utf8
        var i = utf8.startIndex
        let end = utf8.endIndex
        // Stack is required to validate if parentheses are balanced.
        var stack: [UInt8] = []
        // This variable signals whether quantifiers ('+', '*', '?') can be applied
        // to the character that was previously read.
        var canQuantify = false

        /// Checks if a character is ASCII.
        @inline(__always)
        func isASCII(_ character: UInt8) -> Bool {
            return character < 128
        }

        /// Checks if we are currently inside a character class.
        @inline(__always)
        func inCharacterClass() -> Bool {
            stack.last == UInt8(ascii: "[")
        }

        /// Peeks at the next character in the pattern.
        @inline(__always)
        func peekNext() -> UInt8? {
            let next = utf8.index(after: i)
            guard next < end else { return nil }
            return utf8[next]
        }

        /// Peeks at the previous character in the pattern.
        @inline(__always)
        func peekPrevious() -> UInt8? {
            guard i > utf8.startIndex else { return nil }
            let previous = utf8.index(before: i)
            return utf8[previous]
        }

        // Loop through every character in the pattern.
        while i < end {
            let currentChar = utf8[i]

            if !isASCII(currentChar) {
                return .failure(SafariRegexError.nonASCII(message: "Found non-ASCII character"))
            }

            switch currentChar {
            case UInt8(ascii: "\\"):
                guard let next = peekNext() else {
                    return .failure(
                        SafariRegexError.invalidRegex(message: "Unsupporteed escape sequence")
                    )
                }

                // Explicitly matching special characters is allowed.
                switch next {
                case UInt8(ascii: "."), UInt8(ascii: "*"), UInt8(ascii: "+"), UInt8(ascii: "?"),
                    UInt8(ascii: "/"), UInt8(ascii: "["), UInt8(ascii: "]"), UInt8(ascii: "("),
                    UInt8(ascii: ")"), UInt8(ascii: "|"), UInt8(ascii: "{"), UInt8(ascii: "}"),
                    UInt8(ascii: "^"), UInt8(ascii: "$"), UInt8(ascii: "\\"):
                    // Skip the next character, it is allowed.
                    i = utf8.index(i, offsetBy: 2)
                    canQuantify = true
                    continue
                default:
                    return .failure(
                        SafariRegexError.unsupportedMetaCharacter(
                            message: "Unsupported escape sequence"
                        )
                    )
                }

            case UInt8(ascii: "("):
                if !inCharacterClass() {
                    // Push opening brackets onto the stack
                    stack.append(currentChar)
                    canQuantify = false
                }

            case UInt8(ascii: "["):
                // Push opening brackets onto the stack
                stack.append(currentChar)
                canQuantify = false

            case UInt8(ascii: ")"):
                if !inCharacterClass() {
                    // If we encounter a closing parenthesis, the top of the stack
                    // must be a matching '('
                    guard let last = stack.popLast(), last == UInt8(ascii: "(") else {
                        return .failure(
                            SafariRegexError.unbalancedParentheses(message: "Unbalanced brackets")
                        )
                    }
                }
                canQuantify = true

            case UInt8(ascii: "]"):
                // If we encounter a closing bracket, the top of the stack
                // must be a matching '['
                guard let last = stack.popLast(), last == UInt8(ascii: "[") else {
                    return .failure(
                        SafariRegexError.unbalancedParentheses(
                            message: "Unbalanced square brackets"
                        )
                    )
                }
                canQuantify = true

            case UInt8(ascii: "^"):
                if i != utf8.startIndex && !inCharacterClass() {
                    return .failure(
                        SafariRegexError.invalidRegex(
                            message: "Invalid regex: unescaped ^ in the middle"
                        )
                    )
                }
                canQuantify = false

            case UInt8(ascii: "$"):
                let next = peekNext()
                if next != nil && !inCharacterClass() {
                    return .failure(
                        SafariRegexError.invalidRegex(
                            message: "Invalid regex: unescaped $ in the middle"
                        )
                    )
                }
                canQuantify = false

            case UInt8(ascii: "|"):
                if !inCharacterClass() {
                    // If we got here, the character was not escaped.
                    return .failure(
                        SafariRegexError.pipeCondition(message: "Pipe conditions not supported")
                    )
                }

            case UInt8(ascii: "{"), UInt8(ascii: "}"):
                if !inCharacterClass() {
                    // If we got here, the curly brackets were not escaped.
                    return .failure(
                        SafariRegexError.digitRange(message: "Digit ranges not supported")
                    )
                }

            case UInt8(ascii: "*"), UInt8(ascii: "+"), UInt8(ascii: "?"):
                if !canQuantify && !inCharacterClass() {
                    return .failure(
                        SafariRegexError.unquantifiableCharacter(message: "Unquantifiable chacter")
                    )
                }
                canQuantify = false
            default:
                // Normal characters are quantifiable.
                canQuantify = true
            }

            i = utf8.index(after: i)
        }

        if !stack.isEmpty {
            return .failure(
                SafariRegexError.unbalancedParentheses(message: "Unbalanced parentheses")
            )
        }

        return .success(())
    }
}

/// Represents different reasons why the regular expression may be considered invalid by Safari.
enum SafariRegexError: Error {
    case invalidRegex(message: String)
    case unquantifiableCharacter(message: String)
    case digitRange(message: String)
    case pipeCondition(message: String)
    case nonASCII(message: String)
    case unbalancedParentheses(message: String)
    case unsupportedMetaCharacter(message: String)
}
