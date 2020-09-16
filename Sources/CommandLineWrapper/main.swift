import ContentBlockerConverter



do {
    print("AG: Conversion started");
    
    let converter = ContentBlockerConverter();

    let result: ConversionResult? = try converter.convertArray(
        rules: ["test"], limit: 0, optimize: false, advancedBlocking: false
    );

    print("\(result!.converted)");
    
    print("AG: Conversion done");
} catch {
    print("AG: ContentBlockerConverter: Unexpected error: \(error)");
}

