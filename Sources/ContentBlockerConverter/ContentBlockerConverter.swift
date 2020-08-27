import Foundation

// Entry point
class ContentBlockerConverter {
    
    // Main func
    func convertArray(rules: [String], limit: Int = 0, optimize: Bool = false, advancedBlocking: Bool = false) -> ConversionResult? {
        if rules.count == 0 {
            NSLog("AG: ContentBlockerConverter: No rules presented");
            return nil;
        }
        
        ErrorsCounter.instance.drop();
        
        do {
            let parsedRules = RuleFactory.createRules(lines: rules);
            let compilationResult = Compiler(optimize: optimize, advancedBlocking: advancedBlocking).compileRules(rules: parsedRules);
            
            return try Distributor(limit: limit, advancedBlocking: advancedBlocking).createConversionResult(data: compilationResult);
        } catch {
            NSLog("AG: ContentBlockerConverter: Unexpected error: \(error)");
        }
        
        return nil;
    }
}
