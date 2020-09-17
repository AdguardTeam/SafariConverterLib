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

func encodeJson(_ result: ConversionResult) throws -> String {
    let encoder = JSONEncoder();
    encoder.outputFormatting = .prettyPrinted
    
    let json = try encoder.encode(result);
    return String(data: json, encoding: .utf8)!.replacingOccurrences(of: "\\/", with: "/");
}

do {
    Logger.log("AG: Conversion started");
    
    let arguments: [String] = CommandLine.arguments;
    if (arguments.count < 5) {
        writeToStdError(str: "AG: Invalid arguments: Usage: ./CommandLineWrapper '[\"test_rule\"]' -limit=0 -optimize -advancedBlocking)");
        exit(EXIT_FAILURE);
    }
    
    let data = arguments[1].data(using: String.Encoding.utf8, allowLossyConversion: false)!;
    let decoder = JSONDecoder();
    let rules = try decoder.decode([String].self, from: data);
    Logger.log("AG: Rules to convert: \(rules.count)");
    
    let limit = Int(arguments[2][String.Index(encodedOffset: 7)...]) ?? 0;
    Logger.log("AG: Limit: \(limit)");
    
    let optimize = arguments[3] == "-optimize";
    Logger.log("AG: Optimize: \(optimize)");
    
    let advancedBlocking = arguments[4] == "-advancedBlocking";
    Logger.log("AG: AdvancedBlocking: \(advancedBlocking)");
    
    let result: ConversionResult? = ContentBlockerConverter().convertArray(
        rules: rules, limit: limit, optimize: optimize, advancedBlocking: advancedBlocking
    );

    Logger.log("AG: Conversion done");
    
    if (result == nil) {
        writeToStdError(str: "AG: ContentBlockerConverter: Empty result.");
        exit(EXIT_FAILURE);
    }
    
    let encoded = try encodeJson(result!);
    
    writeToStdOut(str: "\(encoded)");
    exit(EXIT_SUCCESS);
} catch {
    writeToStdError(str: "AG: ContentBlockerConverter: Unexpected error: \(error)");
    exit(EXIT_FAILURE);
}

