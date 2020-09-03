/**
 * Errors counter 
 */
class ErrorsCounter {
    private var count = 0;
    
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
