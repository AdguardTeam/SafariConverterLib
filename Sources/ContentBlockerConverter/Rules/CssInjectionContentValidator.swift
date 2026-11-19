import Foundation

/// Validates the content of CSS injection rules.
///
/// CSS injection rules must not use styles that can load external
/// resources, e.g. `background: url(https://example.org/image.png)` or
/// `@import "https://example.org/style.css"`.
///
/// A naive search for the `url(` substring is not enough as it can be
/// bypassed in numerous ways:
///
/// * Different case, e.g. `URL(`;
/// * CSS escapes, e.g. `\75 rl(`;
/// * String arguments, e.g. `image-set("https://..." 1x)`;
/// * The `@import` at-rule, e.g. `@import "https://..."`.
///
/// That's why the content is scanned byte by byte. The scanner
/// deliberately does not track strings and comments: the consumers,
/// WebKit CSSOM and ExtendedCss with its own quote pairing rule,
/// diverge from the CSS tokenization, and selective skipping of
/// literals enabled two confirmed bypasses. Any `url(`, `image-set(`
/// or `@import` occurrence in the rule text is rejected regardless of
/// its context. The cost is over-blocking `url(` inside quoted values,
/// selector strings or comments, which never load anything: the
/// repository fixtures contain none of those.
final class CssInjectionContentValidator {
    /// CSS functions that can load external resources.
    private static let FORBIDDEN_FUNCTIONS = [
        "url",
        "image-set",
        "-webkit-image-set",
    ]

    /// CSS at-rules that can load external styles.
    private static let FORBIDDEN_AT_RULES = ["import"]

    /// A parsed CSS escape sequence.
    private struct CssEscape {
        /// The index right after the escape.
        let endIndex: Int

        /// The escaped code point.
        let codePoint: UInt32
    }

    /// The content bytes.
    private let bytes: String.UTF8View

    /// - Parameter content: CSS injection rule content, i.e. if the rule
    ///   text is `example.org#$#body { background: url(x) }`, it will be
    ///   `body { background: url(x) }`.
    init(content: String) {
        self.bytes = content.utf8
    }

    /// Checks if the content contains forbidden styles.
    ///
    /// - Returns: true if the content can load external resources.
    func containsForbiddenStyles() -> Bool {
        return scanContent()
    }

    // MARK: - Scanning

    /// Scans the whole content.
    ///
    /// The name that is currently accumulated is checked when it ends,
    /// i.e. at the first character that cannot be a part of it. Escaped
    /// characters never end the name: they are appended to it as is,
    /// so `u\72 l(` is still `url(`, while `url\28 x\29` does not call
    /// anything at all.
    private func scanContent() -> Bool {
        var index = 0
        var name = ""
        var atName = false

        // Checks the accumulated name right before the character that
        // ends it: a forbidden function call or a forbidden at-rule.
        func endsForbiddenName(_ char: UInt8) -> Bool {
            if char == Chars.BRACKET_OPEN && Self.FORBIDDEN_FUNCTIONS.contains(name) {
                return true
            }

            return atName && Self.FORBIDDEN_AT_RULES.contains(name)
        }

        while let char = charAt(index) {
            if char == Chars.BACKSLASH {
                let escape = parseCssEscape(startIndex: index + 1)
                name.append(Self.escapedCharacter(codePoint: escape.codePoint))
                index = escape.endIndex
            } else if Self.isNameCharacter(char) {
                // Name characters are accumulated lowercased, e.g.
                // `URL(` is `url(`.
                if char >= UInt8(ascii: "A") && char <= UInt8(ascii: "Z") {
                    name.append(Character(UnicodeScalar(char + 32)))
                } else {
                    name.append(Character(UnicodeScalar(char)))
                }

                index += 1
            } else {
                if endsForbiddenName(char) {
                    return true
                }

                name = ""
                atName = char == Chars.AT_CHAR
                index += 1
            }
        }

        // The content may end right after the name, e.g. `@import`.
        return atName && Self.FORBIDDEN_AT_RULES.contains(name)
    }

    /// Checks if the character can be a part of a CSS name.
    ///
    /// CSS names consist of letters, digits, hyphens, underscores and
    /// non-ASCII characters.
    private static func isNameCharacter(_ char: UInt8) -> Bool {
        switch char {
        case UInt8(ascii: "a")...UInt8(ascii: "z"),
            UInt8(ascii: "A")...UInt8(ascii: "Z"),
            UInt8(ascii: "0")...UInt8(ascii: "9"),
            UInt8(ascii: "-"),
            UInt8(ascii: "_"):
            return true
        default:
            return char >= 128
        }
    }

    // MARK: - CSS escapes

    /// Parses a CSS escape sequence that starts at `startIndex`, i.e.
    /// right after the backslash.
    ///
    /// An escape is either:
    ///
    /// * One to six hexadecimal digits that are optionally followed by a
    ///   single whitespace consumed as a part of the escape, CRLF counts
    ///   as a single whitespace;
    /// * Any other character escaped as is.
    ///
    /// - Returns: the parsed escape sequence.
    private func parseCssEscape(startIndex: Int) -> CssEscape {
        var position = startIndex
        var codePoint: UInt32 = 0
        var digits = 0

        while digits < 6, let char = charAt(position), let digit = Self.cssHexDigitValue(char) {
            codePoint = codePoint * 16 + digit
            digits += 1
            position += 1
        }

        if digits > 0 {
            if let char = charAt(position), Self.isCssWhitespace(char) {
                position += 1

                // CRLF counts as a single whitespace.
                if char == 0x0D, charAt(position) == 0x0A {
                    position += 1
                }
            }

            return CssEscape(endIndex: position, codePoint: codePoint)
        }

        // A backslash followed by a non-hex character escapes it as is.
        if let char = charAt(position) {
            return CssEscape(endIndex: position + 1, codePoint: UInt32(char))
        }

        // A backslash at the very end of the content.
        return CssEscape(endIndex: position, codePoint: 0)
    }

    /// Converts an escaped code point to a character for the name buffer.
    ///
    /// Invalid code points are replaced with the replacement character
    /// just like the CSS tokenizer does. Uppercase letters are lowercased
    /// so that escaped names are matched the same way, e.g. `\52` is `r`.
    private static func escapedCharacter(codePoint: UInt32) -> Character {
        // Zero, surrogates and out of range code points are invalid.
        guard codePoint != 0,
            codePoint <= 0x10FFFF,
            !(codePoint >= 0xD800 && codePoint <= 0xDFFF),
            let scalar = UnicodeScalar(codePoint)
        else {
            return "\u{FFFD}"
        }

        // Lowercase A-Z.
        if scalar.value >= 65 && scalar.value <= 90 {
            return Character(UnicodeScalar(UInt8(scalar.value) + 32))
        }

        return Character(scalar)
    }

    /// Checks if the byte is a CSS whitespace. A hex escape may be followed
    /// by a single whitespace that is consumed as a part of the escape.
    private static func isCssWhitespace(_ char: UInt8) -> Bool {
        // Space, tab, line feed, form feed, carriage return.
        return char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0C || char == 0x0D
    }

    /// Returns the value of a hexadecimal digit or nil for other bytes.
    private static func cssHexDigitValue(_ char: UInt8) -> UInt32? {
        switch char {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return UInt32(char - UInt8(ascii: "0"))
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            return UInt32(char - UInt8(ascii: "A") + 10)
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            return UInt32(char - UInt8(ascii: "a") + 10)
        default:
            return nil
        }
    }

    // MARK: - Character access

    /// Returns the character at the specified position, nil past the end.
    private func charAt(_ position: Int) -> UInt8? {
        guard position < bytes.count else {
            return nil
        }

        return bytes[safeIndex: position]
    }
}
