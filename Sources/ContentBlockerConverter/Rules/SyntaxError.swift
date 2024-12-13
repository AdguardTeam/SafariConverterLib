/// Represents a syntax error.
enum SyntaxError: Error {
    case invalidRule(message: String)
    case invalidModifier(message: String)
    case invalidPattern(message: String)
}
