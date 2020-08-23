import Foundation

// Entry point
class ContentBlockerConverter {
    
    // Main func
    func convertArray(rules: [String], limit: Int, optimize: Bool, advancedBlocking: Bool) -> ConversionResult? {
        if rules.count == 0 {
            NSLog("AG: ContentBlockerConverter: No rules presented");
            return nil;
        }
        
        do {
            let parsedRules = RuleFactory.createRules(lines: rules);
            let compilationResult = Compiler(optimize: optimize, advancedBlocking: advancedBlocking).compileRules(rules: parsedRules);
            
            return try Builder(limit: limit, advancedBlocking: advancedBlocking).createConversionResult(data: compilationResult);
        } catch {
            NSLog("AG: ContentBlockerConverter: Unexpected error");
        }
        
        return nil;
    }
}
