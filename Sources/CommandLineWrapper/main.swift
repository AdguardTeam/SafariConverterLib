import Foundation
import ContentBlockerConverter

/**
 * Command line wrapper
 * Usage:
 * ./CommandLineWrapper -limit=0 -optimize=true -advancedBlocking=false
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
    if (arguments.count < 4) {
        writeToStdError(str: "AG: Invalid arguments: Usage: ./CommandLineWrapper -limit=0 -optimize=false -advancedBlocking)");
        exit(EXIT_FAILURE);
    }
    
    let limit = Int(arguments[1][String.Index(encodedOffset: 7)...]) ?? 0;
    Logger.log("AG: Limit: \(limit)");
    
    let optimize = arguments[2] == "-optimize=true";
    Logger.log("AG: Optimize: \(optimize)");
    
    let advancedBlocking = arguments[3] == "-advancedBlocking=true";
    Logger.log("AG: AdvancedBlocking: \(advancedBlocking)");
    
    var rules = [String]();
    var line: String? = nil;
    while (true) {
        line = readLine(strippingNewline: true);
        if (line == nil || line == "") {
            break;
        }
        
        rules.append(line!);
    }
    
    Logger.log("AG: Rules to convert: \(rules.count)");
    
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

