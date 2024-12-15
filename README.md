# Safari Converter

TODO(ameshkov): !!! Rework documentation

This is a library that provides a compatibility layer between
[AdGuard filtering rules][adguardrules] and [Safari content blocking rules][safarirules].

[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[safarirules]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker

- [Converter](#converter)
  - [Using as a library](#using-as-a-library)
  - [Command-line interface](#command-line-interface)
  - [Using as a node module](#using-as-a-node-module)
- [Limitations](#limitations)
- [For developers](#for-developers)
  - [How to build, test, debug](#how-to-build-test-debug)
  - [Releasing new version](#releasing-new-version)
  - [Third-party dependencies](#third-party-dependencies)

## Converter

The main purpose of this project is converting AdGuard rules into the format
that Safari can understand.

Here's a simple example of how it works.

- AdGuard rule:

  ```adblock
  ||example.org^$third-party
  ```

- Safari rule that does the same:

  ```json
  {
    "action": {
      "type": "block"
    },
    "trigger": {
      "load-type": [
        "third-party"
      ],
      "url-filter": "^[htpsw]+:\\\/\\\/([a-z0-9-]+\\.)?test\\.com([\\\/:&\\?].*)?$"
    }
  }
  ```

Note, that not every rule can be supported natively so there's also a concept of
"advanced rules", the rules that have to be interpreted by a separate extension,
either a [WebExtension][safariwebextension], or a [Safari App Extension][safariappextension].

[safariwebextension]: https://developer.apple.com/documentation/safariservices/safari-web-extensions
[safariappextension]: https://developer.apple.com/documentation/safariservices/safari-app-extensions

### Using as a library

```swift
    let result: ConversionResult? = ContentBlockerConverter.convertArray(
        rules: [String],
        safariVersion: SafariVersions = .DEFAULT,
        optimize: Bool = false,
        advancedBlocking: Bool = false
        advancedBlockingFormat: AdvancedBlockingFormat = .json
    )
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

TODO: Explain how important it is to use contigious UTF-8 strings

### Command-line interface

Converter can be built as a command-line tool with the following interface:

```sh
ConverterTool [--safari-version <safari-version>] [--optimize <optimize>] [--advanced-blocking <advanced-blocking>] [--advanced-blocking-format <advanced-blocking-format>] [<rules>]
```

Here's an example of how it can be used:

```sh
cat rules.txt | ./ConverterTool --safari-version 13 --optimize false --advanced-blocking true --advanced-blocking-format txt
```

### Using as a node module

##### Requirements

- Swift 5 or higher

After installation the build process occurs and binary file will be copied to bin directory

#### API

`jsonFromRules(rules, advancedBlocking, safariVersion, converterToolPath)` - method to convert rules into JSON

- rules - array of rules
- advancedBlocking - if we need advanced blocking content (boolean)
- safariVersion
- converterToolPath - path to ConverterTool binary

`getConverterVersion` - returns Safari Converter Lib version

## Limitations

TODO: Describe limitations of the conversion process.

### Supported AdGuard rules types

#### Basic content blocker format

- Elemhide rules (##)
- Elemhide exceptions
- Url blocking rules
- Url blocking exceptions

#### Extended Advanced blocking types

- Script rules (#%#)
- Script rules exceptions
- Extended css elemhide rules (#?#)
- Scriptlet rules (#%#//scriptlet)
- Scriptlet rules exceptions

### Limitations

- Safari does not support both `if-domain` and `unless-domain` triggers. That's why rules like `example.org,~foo.example.orgs` are invalid. [Feature request](https://bugs.webkit.org/show_bug.cgi?id=226076) to WebKit to allow such rules.
- Cosmetic exception rules will only affect the rules with **the very same domain**. I.e. the rule example.org#@##banner will result in removing example.org from example.org,example.net###banner, but will have **no result** on subdomain.example.org###banner.
- Rules with `ping` modifier are ignored (until [#18](https://github.com/AdguardTeam/SafariConverterLib/issues/18) is solved)
- Exception rule with `specifichide` modifier disables all specific element hiding rules for the same level domain and doesn't influence on subdomains or top-level domains, i.e. the rule `@@||sub.example.org^$specifichide` doesn't disable `test.sub.example.org##.banner` and  `example.org##.banner`
- `generichide`, `elemhide`, `specifichide` and `jsinject` modifiers can be used only as a single modifier in a rule.

#### `denyallow` rules

A rule with the `denyallow` modifier will be converted into a blocking rule and additional exception rules.

For example:

- Generic rule `*$denyallow=x.com,image,domain=a.com`  will be converted to:

    ```adblock
    *$image,domain=a.com
    @@||x.com$image,domain=a.com
    ```

- Blocking rule `/banner.png$image,denyallow=test1.com|test2.com,domain=example.org` will be converted to

    ```adblock
    /banner.png$image,domain=example.org
    @@||test1.com/banner.png$image,domain=example.org
    @@||test1.com/*/banner.png$image,domain=example.org
    @@||test2.com/banner.png$image,domain=example.org
    @@||test2.com/*/banner.png$image,domain=example.org
    ```

- Exception rule `@@/banner.png$image,denyallow=test.com,domain=example.org` will be converted to

    ```adblock
    @@/banner.png$image,domain=example.org
    ||test.com/banner.png$image,domain=example.org,important
    ||test.com/*/banner.png$image,domain=example.org,important
    ```

$generichide == $elemhide ???
$genericblock == $urlblock, i.e. unblocks everything?
Why don't we support ||example.org^$denyallow=x.com,domain=y.com
Does not support $elemhide,urlblock

## For developers

Please note, that the library is published under GPLv3.

### How to build, test, debug

- If you're using Safari Converter as a library then you can simply use it as an
SPM module.
- Building the command-line argument: `swift build`.
- Running unit-tests: `swift test`.

In addition to that, we advise using this [demo project][safariblocker] to debug
the library itself, and even individual Safari content blocking rules.

[safariblocker]: https://github.com/ameshkov/safari-blocker

### Releasing new version

Push a new tag in `v*.*.*` format, then provided github action is intended to build and publish new release with an asset binary.

### Third-party dependencies

- Punycode (<https://github.com/gumob/PunycodeSwift.git>)
