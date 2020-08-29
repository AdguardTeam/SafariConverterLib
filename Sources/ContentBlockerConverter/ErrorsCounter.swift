/**
 * Error counter singleton
 */
class ErrorsCounter {
    static let instance = ErrorsCounter();
    private var count = 0;

    private init() {
        
    }
    
    /**
     * Drops current count
     */
    func drop() -> Void {
        count = 0;
    }
    
    /**
     * Increases count
     */
    func add() -> Void {
        count += 1;
    }
    
    /**
     * Returns current count
     */
    func getCount() -> Int {
        return count;
    }
}
