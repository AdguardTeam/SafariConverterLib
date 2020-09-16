import Foundation
import ContentBlockerConverter

/**
 * Command line wrapper
 * Usage:
 * ./CommandLineWrapper '["test_rule_one", "test_rule_two"]' -limit=0 -optimize -advancedBlocking=false
 */

func writeToStdError(str: String) {
    let handle = FileHandle.standardError;
    
    if let data = str.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        handle.write(data)
    }
}

func writeToStdOut(str: String) {
    let handle = FileHandle.standardOutput;
    
    if let data = str.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        handle.write(data)
    }
}

do {
    print("AG: Conversion started");
    
    let arguments: [String] = CommandLine.arguments;
    if (arguments.count < 5) {
        writeToStdError(str: "AG: Invalid arguments: Usage: ./CommandLineWrapper '[\"test_rule\"]' -limit=0 -optimize -advancedBlocking)");
        exit(EXIT_FAILURE);
    }
    
    let data = arguments[1].data(using: String.Encoding.utf8, allowLossyConversion: false)!;
    let decoder = JSONDecoder();
    let rules = try decoder.decode([String].self, from: data);
    print("AG: Rules to convert: \(rules.count)");
    
    let limit = Int(arguments[2][String.Index(encodedOffset: 7)...]) ?? 0;
    print("AG: Limit: \(limit)");
    
    let optimize = arguments[3] == "-optimize";
    print("AG: Optimize: \(optimize)");
    
    let advancedBlocking = arguments[4] == "-advancedBlocking";
    print("AG: AdvancedBlocking: \(advancedBlocking)");
    
    let result: ConversionResult? = ContentBlockerConverter().convertArray(
        rules: rules, limit: limit, optimize: optimize, advancedBlocking: advancedBlocking
    );

    print("AG: Conversion done");
    
    writeToStdOut(str: "\(result!.converted)");
    
    exit(EXIT_SUCCESS);
} catch {
    print("AG: ContentBlockerConverter: Unexpected error: \(error)");
}

