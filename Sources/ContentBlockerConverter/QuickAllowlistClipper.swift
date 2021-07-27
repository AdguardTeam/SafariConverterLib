import Foundation

public class QuickAllowlistClipper {
    let converter = ContentBlockerConverter();
    
    /**
     * Converts provided allowlist rule to json format and returns as string
     */
    public func convertAllowlistRule(ruleText: String) throws -> String {
        guard let conversionResult = converter.convertArray(rules: [ruleText]) else {
            throw QuickAllowlistClipperError.invalidAllowlistRule();
        }
        let allowlistRule = conversionResult.converted.dropFirst(1).dropLast(1);
        return String(allowlistRule);
    }
    
    /**
     * Appends provided allowlist rule to conversion result
     */
    public func addAllowlistRule(withText ruleText: String, conversionResult: ConversionResult) throws -> ConversionResult {
        let allowlistRule = try convertAllowlistRule(ruleText: ruleText);
        
        var result = conversionResult;
        result.converted = String(result.converted.dropLast(1));
        result.converted += ",\(allowlistRule)]"
        
        return result;
    }
    
    /**
     * Removes provided allowlist rule from conversion result
     */
    public func removeAllowlistRule(withText ruleText: String, conversionResult: ConversionResult) throws -> ConversionResult {
        let allowlistRule = try convertAllowlistRule(ruleText: ruleText);
        
        if !conversionResult.converted.contains(allowlistRule) {
            throw QuickAllowlistClipperError.errorRemovingAllowlistRule();
        }
        
        var result = conversionResult;
        result.converted = result.converted.replace(target: allowlistRule, withString: "");
        
        // remove redundant commas
        if result.converted.hasPrefix("[,{") {
            result.converted = result.converted.replace(target: "[,{", withString: "[{");
        } else if result.converted.hasSuffix("},]") {
            result.converted = result.converted.replace(target: "},]", withString: "}]");
        } else if result.converted.contains(",,") {
            result.converted = result.converted.replace(target: ",,", withString: ",");
        }
        // handle empty result
        if result.converted == "[]" {
            return try ConversionResult.createEmptyResult();
        }
        
        return result;
    }
}

public enum QuickAllowlistClipperError: Error {
    case invalidAllowlistRule(debugDescription: String = "Invalid allowlist rule")
    case errorRemovingAllowlistRule(debugDescription: String = "Conversion result doesn't contain provided allowlist rule")
}
