/// Represents a syntax error.
public enum SyntaxError: Error {
    case invalidRule(message: String)
    case invalidModifier(message: String)
    case invalidPattern(message: String)
}
