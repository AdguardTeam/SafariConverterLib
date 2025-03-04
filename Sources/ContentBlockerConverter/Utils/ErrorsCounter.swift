/// Helper class the only purpose of which is to count errors.
public class ErrorsCounter {
    private var count = 0

    public init() {
    }

    /// Increments the number of errors.
    public func add() {
        count += 1
    }

    /// Returns the current count of errors.
    public func getCount() -> Int {
        return count
    }
}
