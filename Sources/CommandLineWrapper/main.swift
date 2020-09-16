import Foundation
import ContentBlockerConverter

/**
 * Command line wrapper
 * Usage:
 * ./CommandLineWrapper '["test_rule_one", "test_rule_two"]' -limit=0 -optimize -advancedBlocking=false
 */

do {
    print("AG: Conversion started");
    
    let arguments: [String] = CommandLine.arguments;
    print(arguments);
    
    if (arguments.count < 5) {
        print("AG: Invalid arguments: Usage: ./CommandLineWrapper '[\"test_rule\"]' -limit=0 -optimize -advancedBlocking)");
        throw fatalError("AG: Wrong arguments.");
    }
    
    let data = arguments[1].data(using: String.Encoding.utf8, allowLossyConversion: false)!;
    let decoder = JSONDecoder();
    let rules = try decoder.decode([String].self, from: data);
    print("Rules to convert: \(rules.count)");
    
    let limit = Int(arguments[2][String.Index(encodedOffset: 7)...]) ?? 0;
    print("Limit: \(limit)");
    
    let optimize = arguments[3] == "-optimize";
    print("Optimize: \(optimize)");
    
    let advancedBlocking = arguments[4] == "-advancedBlocking";
    print("AdvancedBlocking: \(advancedBlocking)");
    
    let result: ConversionResult? = try ContentBlockerConverter().convertArray(
        rules: rules, limit: limit, optimize: optimize, advancedBlocking: advancedBlocking
    );

    print("\(result!.converted)");
    
    print("AG: Conversion done");
} catch {
    print("AG: ContentBlockerConverter: Unexpected error: \(error)");
}

