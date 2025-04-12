//
//  Utils.swift
//  ContentBlockerConverter
//
//  Created by Andrey Meshkov on 12/04/2025.
//

import ContentBlockerConverter
import Foundation

/// Writes a string to standard output.
/// - Parameter str: The string to write.
func writeToStdOut(str: String) {
    let handle = FileHandle.standardOutput

    if let data = str.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        handle.write(data)
    }
}

/// Reads input from either a file path or stdin
/// - Parameter inputPath: Optional path to a file containing rules
/// - Returns: Array of rule strings
func readInput(from inputPath: String? = nil) throws -> [String] {
    var rules: [String] = []

    if let inputPath = inputPath {
        // Read from file
        do {
            let content = try String(contentsOfFile: inputPath, encoding: .utf8)
            rules = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Logger.log("Read \(rules.count) rules from file: \(inputPath)")
        } catch {
            throw NSError(
                domain: "FileReadError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to read from file: "
                        + "\(error.localizedDescription)"
                ]
            )
        }
    } else {
        // Read from stdin
        while let line = readLine(strippingNewline: true), !line.isEmpty {
            rules.append(line)
        }
        Logger.log("Read \(rules.count) rules from stdin")
    }

    return rules
}
