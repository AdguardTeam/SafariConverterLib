/**
 * Rule syntax error
 */
enum SyntaxError: Error {
    case invalidRule(message: String)
    case invalidMarker(message: String)
}
