//
//  ConvertCommand.swift
//  ContentBlockerConverter
//
//  Created by Andrey Meshkov on 12/04/2025.
//

import ArgumentParser
import ContentBlockerConverter
import Foundation

/// Subcommand for converting rules to JSON.
///
/// ### Usage
///
/// ```
/// cat rules.txt | ./ConverterTool convert --safari-version 14 --advanced-blocking true
/// ```
///
/// Or with input file:
///
/// ```
/// ./ConverterTool convert --input-path rules.txt --safari-version 14 --advanced-blocking true
/// ```
struct ConvertCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract:
            "Convert AdGuard rules to Safari content blocking JSON and advanced rules for a web extension."
    )

    @Option(name: .shortAndLong, help: "Safari version.")
    var safariVersion: Double = SafariVersion.autodetect().doubleValue

    @Option(name: .shortAndLong, help: "Advanced blocking flag.")
    var advancedBlocking = false

    @Option(name: .shortAndLong, help: "Maximum json size in bytes. Leave empty for no limit.")
    var maxJsonSizeBytes: Int = 0

    @Option(
        name: .long,
        help: "Path to the input file with rules. Leave empty to read from stdin."
    )
    var inputPath: String?

    @Option(
        name: .long,
        help: "Output path to write Safari content blocking JSON file. Leave empty for stdout."
    )
    var safariRulesJSONPath: String?

    @Option(
        name: .long,
        help: "Output path to write advanced blocking rules file. Leave empty for stdout."
    )
    var advancedBlockingRulesPath: String?

    mutating func run() throws {
        let safariVersionResolved = SafariVersion(safariVersion)
        let maxJsonSizeBytesOption: Int? = (maxJsonSizeBytes <= 0) ? nil : maxJsonSizeBytes

        Logger.log("(Convert) - Safari version: \(safariVersionResolved)")
        Logger.log("(Convert) - Advanced blocking: \(advancedBlocking)")
        if let size = maxJsonSizeBytesOption {
            Logger.log("(Convert) - Max json limit: \(size)")
        } else {
            Logger.log("(Convert) - Max json limit: No limit set")
        }

        if let inputPath = inputPath {
            Logger.log("(Convert) - Input file: \(inputPath)")
        } else {
            Logger.log("(Convert) - Reading from stdin")
        }

        let rules = try readInput(from: inputPath)
        Logger.log("(Convert) - Rules to convert: \(rules.count)")

        let result: ConversionResult = ContentBlockerConverter()
            .convertArray(
                rules: rules,
                safariVersion: safariVersionResolved,
                advancedBlocking: advancedBlocking,
                maxJsonSizeBytes: maxJsonSizeBytesOption
            )

        Logger.log("(Convert) - Conversion done.")

        if safariRulesJSONPath == nil && advancedBlockingRulesPath == nil {
            let encoded = try encodeJson(result)
            writeToStdOut(str: encoded)
        }

        if let safariRulesJSONPath = safariRulesJSONPath {
            let content = result.safariRulesJSON
            try content.write(toFile: safariRulesJSONPath, atomically: true, encoding: .utf8)
        }

        if let advancedBlockingRulesPath = advancedBlockingRulesPath {
            let content = result.advancedRulesText ?? ""
            try content.write(toFile: advancedBlockingRulesPath, atomically: true, encoding: .utf8)
        }
    }
}

func encodeJson(_ result: ConversionResult) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let json = try encoder.encode(result)
    guard let jsonString = String(data: json, encoding: .utf8) else {
        throw NSError(
            domain: "EncodingError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON to string"]
        )
    }
    return jsonString.replacingOccurrences(of: "\\/", with: "/")
}
