
class ErrorsCounter {
    static let instance = ErrorsCounter();
    private var count = 0;

    private init() {
        
    }
    
    func drop() -> Void {
        count = 0;
    }
    
    func add() -> Void {
        count += 1;
    }
    
    func getCount() -> Int {
        return count;
    }
}
