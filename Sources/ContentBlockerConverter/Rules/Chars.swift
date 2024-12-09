/// Special characters that are used in filtering rules
class Chars {
    static let EXCLAMATION: UInt8 = "!".utf8.first!
    static let HASH: UInt8 = "#".utf8.first!
    static let AT_CHAR: UInt8 = "@".utf8.first!
    static let DOLLAR: UInt8 = "$".utf8.first!
    static let PERCENT: UInt8 = "%".utf8.first!
    static let QUESTION: UInt8 = "?".utf8.first!
    static let PIPE: UInt8 = "|".utf8.first!
    static let BACKSLASH: UInt8 = "\\".utf8.first!
    static let SLASH: UInt8 = "/".utf8.first!
    static let WILDCARD: UInt8 = "*".utf8.first!
    static let COMMA: UInt8 = ",".utf8.first!
    static let TILDE: UInt8 = "~".utf8.first!
    static let UNDERSCORE: UInt8 = "_".utf8.first!
    static let QUOTE_DOUBLE: UInt8 = "\"".utf8.first!
    static let QUOTE_SINGLE: UInt8 = "'".utf8.first!
    static let WHITESPACE: UInt8 = " ".utf8.first!
    static let SQUARE_BRACKET_OPEN: UInt8 = "[".utf8.first!
    static let SQUARE_BRACKET_CLOSE: UInt8 = "]".utf8.first!
    static let BRACKET_OPEN: UInt8 = "(".utf8.first!
    static let BRACKET_CLOSE: UInt8 = ")".utf8.first!
    static let COLON: UInt8 = ":".utf8.first!
    static let EQUALS_SIGN: UInt8 = "=".utf8.first!
    static let CARET: UInt8 = "^".utf8.first!
}
