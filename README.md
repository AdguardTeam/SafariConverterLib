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
        rules: [String],
        safariVersion: SafariVersions = .DEFAULT,
        optimize: Bool = false,
        advancedBlocking: Bool = false
        advancedBlockingFormat: AdvancedBlockingFormat = .json
    );
```
Please note, that `safariVersion` must be an instance of enum SafariVersions.

The result contains following properties:
- totalConvertedCount: length of content blocker
- convertedCount: length after reducing to limit (depends on provided Safari version)
- errorsCount: errors count
- overLimit: is limit exceeded flag (the limit depends on provided Safari version)
- converted: json string of content blocker rules
- advancedBlocking: json string of advanced blocking rules
- advancedBlockingText: txt string of advanced blocking rules

### How to use converter from command line:
```
    ConverterTool [--safari-version <safari-version>] [--optimize <optimize>] [--advanced-blocking <advanced-blocking>] [--advanced-blocking-format <advanced-blocking-format>] [<rules>]
```
e.g.
```
    cat rules.txt | ./ConverterTool --safari-version 13 --optimize false --advanced-blocking true --advanced-blocking-format txt
```

The tool then reads stdin line by line for rule until an empty line.

### How to release on GitHub

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
- Extended css elemhide rules (#?#)
- Scriptlet rules (#%#//scriptlet)
- Scriptlet rules exceptions

### Third-party dependencies

- Punycode (https://github.com/gumob/PunycodeSwift.git)

### Use as node module

##### Requirements:

* Swift 4 or higher

After installation the build process occurs and binary file will be copied to bin directory

#### API

`jsonFromRules(rules, advancedBlocking, safariVersion, converterToolPath, advancedBlockingFormat)` - method to convert rules into JSON
* rules - array of rules
* advancedBlocking - if we need advanced blocking content (boolean)
* advancedBlockingFormat - Advanced blocking rules in text or json format
* safariVersion
* converterToolPath - path to ConverterTool binary

`getConverterVersion` - returns Safari Converter Lib version

### Limitations

* Safari does not support both `if-domain` and `unless-domain` triggers. That's why rules like `example.org,~foo.example.orgs` are invalid. [Feature request](https://bugs.webkit.org/show_bug.cgi?id=226076) to WebKit to allow such rules.
* Cosmetic exception rules will only affect the rules with **the very same domain**. I.e. the rule example.org#@##banner will result in removing example.org from example.org,example.net###banner, but will have **no result** on subdomain.example.org###banner.
* Rules with `ping` modifier are ignored (until [#18](https://github.com/AdguardTeam/SafariConverterLib/issues/18) is solved)
* Exception rule with `specifichide` modifier disables all specific element hiding rules for the same level domain and doesn't influence on subdomains or top-level domains, i.e. the rule `@@||sub.example.org^$specifichide` doesn't disable `test.sub.example.org##.banner` and  `example.org##.banner`
* `generichide`, `elemhide`, `specifichide` and `jsinject` modifiers can be used only as a single modifier in a rule.

#### `denyallow` rules

A rule with the `denyallow` modifier will be converted into a blocking rule and additional exception rules.

For example:

* Generic rule `*$denyallow=x.com,image,domain=a.com`  will be converted to
```
*$image,domain=a.com
@@||x.com$image,domain=a.com
```

* Blocking rule `/banner.png$image,denyallow=test1.com|test2.com,domain=example.org` will be converted to
```
/banner.png$image,domain=example.org
@@||test1.com/banner.png$image,domain=example.org
@@||test1.com/*/banner.png$image,domain=example.org
@@||test2.com/banner.png$image,domain=example.org
@@||test2.com/*/banner.png$image,domain=example.org
```
Exception rule `@@/banner.png$image,denyallow=test.com,domain=example.org` will be converted to
```
@@/banner.png$image,domain=example.org
||test.com/banner.png$image,domain=example.org,important
||test.com/*/banner.png$image,domain=example.org,important
```
