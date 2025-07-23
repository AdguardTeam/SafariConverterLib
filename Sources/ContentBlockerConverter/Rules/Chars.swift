import Foundation

/// Special characters that are used in filtering rules.
///
/// This is important that constants here must be defined as literals without any calculations
/// as defining it differently greatly affects performance.
///
/// TODO: Consider removing and replacing with UInt8(ascii: "") everywhere.
public enum Chars {
    public static let EXCLAMATION: UInt8 = 33  // '!'
    public static let HASH: UInt8 = 35  // '#'
    public static let AT_CHAR: UInt8 = 64  // '@'
    public static let DOLLAR: UInt8 = 36  // '$'
    public static let PERCENT: UInt8 = 37  // '%'
    public static let QUESTION: UInt8 = 63  // '?'
    public static let PIPE: UInt8 = 124  // '|'
    public static let BACKSLASH: UInt8 = 92  // '\\'
    public static let SLASH: UInt8 = 47  // '/'
    public static let WILDCARD: UInt8 = 42  // '*'
    public static let COMMA: UInt8 = 44  // ','
    public static let TILDE: UInt8 = 126  // '~'
    public static let UNDERSCORE: UInt8 = 95  // '_'
    public static let QUOTE_DOUBLE: UInt8 = 34  // '"'
    public static let QUOTE_SINGLE: UInt8 = 39  // '\''
    public static let WHITESPACE: UInt8 = 32  // ' '
    public static let SQUARE_BRACKET_OPEN: UInt8 = 91  // '['
    public static let SQUARE_BRACKET_CLOSE: UInt8 = 93  // ']'
    public static let CURLY_BRACKET_OPEN: UInt8 = 123  // '{'
    public static let CURLY_BRACKET_CLOSE: UInt8 = 125  // '}'
    public static let BRACKET_OPEN: UInt8 = 40  // '('
    public static let BRACKET_CLOSE: UInt8 = 41  // ')'
    public static let COLON: UInt8 = 58  // ':'
    public static let EQUALS_SIGN: UInt8 = 61  // '='
    public static let CARET: UInt8 = 94  // '^'
    public static let PLUS: UInt8 = 43  // '+'

    public static let TRIM_SINGLE_QUOTE = CharacterSet.whitespaces.union(
        CharacterSet(charactersIn: "'")
    )
    public static let TRIM_DOUBLE_QUOTE = CharacterSet.whitespaces.union(
        CharacterSet(charactersIn: "\"")
    )
}
