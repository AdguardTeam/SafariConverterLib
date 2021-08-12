/**
 * Logger
 */
public class Logger {
    public static func log(_ message: String) {
        #if DEBUG
        print("AG: \(message)")
        #endif
    }
}
