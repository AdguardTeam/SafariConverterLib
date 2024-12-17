import Foundation

/// Special characters that are used in filtering rules.
///
/// This is important that constants here must be defined as literals without any calculations
/// as defining it differently greatly affects performance.
class Chars {
    static let EXCLAMATION: UInt8 = 33          // '!'
    static let HASH: UInt8 = 35                 // '#'
    static let AT_CHAR: UInt8 = 64              // '@'
    static let DOLLAR: UInt8 = 36               // '$'
    static let PERCENT: UInt8 = 37              // '%'
    static let QUESTION: UInt8 = 63             // '?'
    static let PIPE: UInt8 = 124                // '|'
    static let BACKSLASH: UInt8 = 92            // '\\'
    static let SLASH: UInt8 = 47                // '/'
    static let WILDCARD: UInt8 = 42             // '*'
    static let COMMA: UInt8 = 44                // ','
    static let TILDE: UInt8 = 126               // '~'
    static let UNDERSCORE: UInt8 = 95           // '_'
    static let QUOTE_DOUBLE: UInt8 = 34         // '"'
    static let QUOTE_SINGLE: UInt8 = 39         // '\''
    static let WHITESPACE: UInt8 = 32           // ' '
    static let SQUARE_BRACKET_OPEN: UInt8 = 91  // '['
    static let SQUARE_BRACKET_CLOSE: UInt8 = 93 // ']'
    static let CURLY_BRACKET_OPEN: UInt8 = 123  // '{'
    static let CURLY_BRACKET_CLOSE: UInt8 = 125 // '}'
    static let BRACKET_OPEN: UInt8 = 40         // '('
    static let BRACKET_CLOSE: UInt8 = 41        // ')'
    static let COLON: UInt8 = 58                // ':'
    static let EQUALS_SIGN: UInt8 = 61          // '='
    static let CARET: UInt8 = 94                // '^'
    static let PLUS:UInt8 = 43                  // '+'

    static let TRIM_SINGLE_QUOTE = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "'"))
    static let TRIM_DOUBLE_QUOTE = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\""))
}
