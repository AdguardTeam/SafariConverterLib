//
//  BuildEngineCommand.swift
//  ContentBlockerConverter
//
//  Created by Andrey Meshkov on 12/04/2025.
//

import ArgumentParser
import ContentBlockerConverter
import FilterEngine
import Foundation

/// Subcommand for building the FilterEngine in the binary form.
///
/// ## Usage:
///
/// ```
/// cat advanced-rules.txt | ./ConverterTool buildengine --safari-version 14 --output-dir <path-to-dir>
/// ```
///
/// Or with input file:
///
/// ```
/// ./ConverterTool buildengine --input-path advanced-rules.txt --safari-version 14 --output-dir <path-to-dir>
/// ```
struct BuildEngineCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "buildengine",
        abstract: "Build the FilterEngine binary."
    )

    @Option(name: .shortAndLong, help: "Safari version.")
    var safariVersion: Double = 13

    @Option(
        name: .long,
        help: "Path to the input file with rules. Leave empty to read from stdin."
    )
    var inputPath: String?

    @Option(name: .shortAndLong, help: "Output directory for the FilterEngine binary.")
    var outputDir: String

    mutating func run() throws {
        let safariVersionResolved = SafariVersion(safariVersion)
        Logger.log("(BuildEngine) - Safari version: \(safariVersionResolved)")
        Logger.log("(BuildEngine) - Output directory: \(outputDir)")

        if let inputPath = inputPath {
            Logger.log("(BuildEngine) - Input file: \(inputPath)")
        } else {
            Logger.log("(BuildEngine) - Reading from stdin")
        }

        let rules = try readInput(from: inputPath)
        Logger.log("(BuildEngine) - Advanced rules count: \(rules.count)")

        // Build the FilterEngine binary using the provided rules and safari version.
        // Remove any previous settings from sharedUserDefaults.
        guard let sharedUserDefaults = EmptyDefaults(suiteName: #file) else {
            throw NSError(
                domain: "UserDefaultsError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create UserDefaults"]
            )
        }
        defer { sharedUserDefaults.removePersistentDomain(forName: #file) }

        // Create a URL from the output directory string.
        let containerURL = URL(fileURLWithPath: outputDir)

        // Pass the URL to the WebExtension constructor.
        let webExtension = try WebExtension(
            containerURL: containerURL,
            sharedUserDefaults: sharedUserDefaults,
            version: safariVersionResolved
        )

        // Build the engine.
        _ = try webExtension.buildFilterEngine(rules: rules.joined(separator: "\n"))

        Logger.log("(BuildEngine) - FilterEngine files written to \(outputDir)")
    }
}

/// EmptyDefaults is a UserDefaults instance that does not save or read anything.
/// It is required to avoid creating unnecessary files.
class EmptyDefaults: UserDefaults {
    override func double(forKey defaultName: String) -> Double {
        0
    }

    override func integer(forKey defaultName: String) -> Int {
        0
    }

    override func set(_ value: Double, forKey defaultName: String) {
    }

    override func set(_ value: Int, forKey defaultName: String) {
    }
}
