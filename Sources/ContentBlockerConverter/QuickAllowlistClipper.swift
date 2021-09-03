import Foundation

/**
 * Provides methods to manage allowlist and inverted allowlist rules without conversion
 */
protocol QuickAllowlistClipperProtocol {
    // Converts provided rule to json format and returns as string
    func convertRuleToJsonString(ruleText: String) throws -> String
    
    // Appends rule to provided conversion result
    func add(rule: String, to conversionResult: ConversionResult) throws -> ConversionResult
    
    // Removes rule from provided conversion result
    func remove(rule: String, from conversionResult: ConversionResult) throws -> ConversionResult
    
    // Replaces rule in conversion result with provided rule
    func replace(rule: String, with newRule: String, in conversionResult: ConversionResult) throws -> ConversionResult
    
    // Public method to create allowlist rule for provided domain and append it to conversion result
    func addAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult
    
    // Public method to create inverted allowlist rule for provided domain and append it to conversion result
    func addInvertedAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult
    
    // Public method to create allowlist rule for provided domain and remove it from provided conversion result
    func removeAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult
    
    // Public method to create inverted allowlist rule for provided domain and remove it from provided Ωconversion result
    func removeInvertedAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult
}

/**
 * Special service for managing allowlist rules:
 * quickly add/remove allowlist rules without filters recompilation
 */
public class QuickAllowlistClipper: QuickAllowlistClipperProtocol {
    let converter = ContentBlockerConverter();

    /**
     * Converts provided rule to json format and returns as string
     */
    func convertRuleToJsonString(ruleText: String) throws -> String {
        guard let conversionResult = converter.convertArray(rules: [ruleText]) else {
            throw QuickAllowlistClipperError.errorConvertingRule;
        }
        let convertedRule = conversionResult.converted.dropFirst(1).dropLast(1);
        return String(convertedRule);
    }

    /**
     * Appends provided rule to conversion result
     */
    func add(rule: String, to conversionResult: ConversionResult) throws -> ConversionResult {
        let convertedRule = try convertRuleToJsonString(ruleText: rule);

        if conversionResult.converted.contains(convertedRule) {
            throw QuickAllowlistClipperError.errorAddingRule;
        }

        var result = conversionResult;
        result.converted = String(result.converted.dropLast(1));
        result.converted += ",\(convertedRule)]"
        result.convertedCount += 1;
        result.totalConvertedCount += 1;

        return result;
    }

    /**
     * Removes provided rule from conversion result
     */
    func remove(rule: String, from conversionResult: ConversionResult) throws -> ConversionResult {
        let convertedRule = try convertRuleToJsonString(ruleText: rule);

        if !conversionResult.converted.contains(convertedRule) {
            throw QuickAllowlistClipperError.noRuleInConversionResult;
        }

        // amount of rules to remove in conversion result
        let delta = conversionResult.converted.components(separatedBy: convertedRule).count - 1;

        var result = conversionResult;
        result.converted = result.converted.replacingOccurrences(of: convertedRule, with: "");

        // remove redundant commas
        if result.converted.hasPrefix("[,{") {
            result.converted = result.converted.replacingOccurrences(of: "[,{", with: "[{");
        }
        if result.converted.hasSuffix("},]") {
            result.converted = result.converted.replacingOccurrences(of: "},]", with: "}]");
        }
        while result.converted.contains(",,") {
            result.converted = result.converted.replacingOccurrences(of: ",,", with: ",");
        }
        // handle empty result
        if result.converted == "[]" {
            return try ConversionResult.createEmptyResult();
        }

        result.convertedCount -= delta;
        result.totalConvertedCount -= delta;

        return result;
    }

    /**
     * Replaces rule in conversion result with provided rule
     */
    public func replace(rule: String, with newRule: String, in conversionResult: ConversionResult) throws -> ConversionResult {
        var result = conversionResult;
        let ruleJsonString = try convertRuleToJsonString(ruleText: rule);

        if !result.converted.contains(ruleJsonString) {
            throw QuickAllowlistClipperError.noRuleInConversionResult;
        }

        let newRuleJsonString = try convertRuleToJsonString(ruleText: newRule);

        result.converted = result.converted.replacingOccurrences(of: ruleJsonString, with: newRuleJsonString);
        return result;
    }

    /**
     * Appends allowlist rule for provided domain to conversion result
     */
    public func addAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult {
        let allowlistRule = ContentBlockerConverter.createAllowlistRule(by: domain);
        return try add(rule: allowlistRule, to: conversionResult);
    }

    /**
     * Appends inverted allowlist rule for provided domain to conversion result
     */
    public func addInvertedAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult {
        let invertedAllowlistRule = ContentBlockerConverter.createInvertedAllowlistRule(by: domain);
        return try add(rule: invertedAllowlistRule, to: conversionResult);
    }

    /**
     * Removes allowlist rule for provided domain from conversion result
     */
    public func removeAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult {
        let allowlistRule = ContentBlockerConverter.createAllowlistRule(by: domain);
        return try remove(rule: allowlistRule, from: conversionResult);
    }

    /**
     * Removes inverted allowlist rule for provided domain from conversion result
     */
    public func removeInvertedAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult {
        let invertedAllowlistRule = ContentBlockerConverter.createInvertedAllowlistRule(by: domain);
        return try remove(rule: invertedAllowlistRule, from: conversionResult);
    }
}

public enum QuickAllowlistClipperError: Error, CustomDebugStringConvertible {
    case errorConvertingRule
    case noRuleInConversionResult
    case errorAddingRule

    public var debugDescription: String {
        switch self {
            case .errorConvertingRule: return "A rule conversion error has occurred"
            case .noRuleInConversionResult: return "Conversion result doesn't contain provided rule"
            case .errorAddingRule: return "The provided rule is already in conversion result"
        }
    }
}
