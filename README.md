# Swift Safari Converter

Content Blocker converter swift code


## Safari Content Blocker

Converts filter rules in AdGuard format to the format supported by Safari.
* https://webkit.org/blog/3476/content-blockers-first-look/

### How to build:

```
    swift build
```

### Tests:

```
    swift test
```

### How to use converter:

```
    let result: ConversionResult? = ContentBlockerConverter.convertArray(
        rules: [String], limit: Int = 0, optimize: Bool = false, advancedBlocking: Bool = false
    );
```

The result contains following properties:
- totalConvertedCount: length of content blocker
- convertedCount: length after reducing to limit if provided
- errorsCount: errors count
- overLimit: is limit exceeded flag
- converted: json string of content blocker rules
- advancedBlocking: json string of advanced blocking rules

### How to use converter from command line:

```
    ./ConverterTool -limit=0 -optimize=true -advancedBlocking=false <<STDIN -o other --options
    test_rule_one
    test_rule_two
    STDIN
```

The tool then reads stdin line by line for rule until an empty line.

### How to release on Github

Push a new tag in `v*.*.*` format, then provided github action is intended to build and publish new release with an asset binary.

### Supported AdGuard rules types:

#### Basic content blocker format:

- Elemhide rules (##)
- Elemhide exceptions
- Url blocking rules
- Url blocking exceptions

#### Extended Advanced blocking types:

- Script rules (#%#)
- Script rules exceptions
- Extended css elemhide rules (##)
- Scriptlet rules (#%#//scriptlet)
- Scriptlet rules exceptions

### Third-party dependencies

- Punycode (https://github.com/gumob/PunycodeSwift.git)

### Use as node module

##### Requirements:

* Swift 4 or higher

After installation the build process occurs and binary file will be copied to bin directory

#### API

`jsonFromRules(rules, advancedBlocking, log)` - method to convert rules into JSON
* rules - array of rules
* advancedBlocking - if we need advanced blocking content (boolean)
* logger

`getConverterVersion` - returns Safari Converter Lib version

### Limitations

* Safari does not support both `if-domain` and `unless-domain` triggers. That's why rules like `example.org,~foo.example.orgs` are invalid. [Feature request](https://bugs.webkit.org/show_bug.cgi?id=226076) to WebKit to allow such rules.
* Rules with `ping` modifier are ignored (until [#18](https://github.com/AdguardTeam/SafariConverterLib/issues/18) is solved)
* Exception rule with `specifichide` modifier disables all specific element hiding rules for the same level domain and doesn't influence on subdomains or top-level domains, i.e. the rule `@@||sub.example.org^$specifichide` doesn't disable `test.sub.example.org##.banner` and  `example.org##.banner`
* `generichide`, `elemhide`, `specifichide` and `jsinject` modifiers can't be used together.
