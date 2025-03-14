# Safari Converter

This is a library that provides a compatibility layer between
[AdGuard filtering rules][adguardrules] and [Safari content blocking rules][safarirules].

[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[safarirules]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker

- [Converter](#converter)
  - [Using as a library](#using-as-a-library)
  - [Command-line interface](#command-line-interface)
  - [Using as a node module](#using-as-a-node-module)
- [Supported rules and limitations](#supported-rules-and-limitations)
  - [Basic (network) rules](#basic-network-rules)
  - [Cosmetic rules](#cosmetic-rules)
  - [Script/scriptlet rules](#scriptscriptlet-rules)
  - [HTML filtering rules](#html-filtering-rules)
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
    let result: ConversionResult = ContentBlockerConverter().convertArray(
        rules: lines,
        safariVersion: SafariVersion(18.1),
        optimize: false,
        advancedBlocking: true,
        advancedBlockingFormat: .txt,
        maxJsonSizeBytes: nil,
        progress: nil
    )
```

#### `convertArray()` parameters

- `rules`: `[String]` - array of [AdGuard rules][adguardrules] to convert.
- `safariVersion`: `SafariVersion` - for which the conversion should be done.
  The minimum supported version if `13`. Depending on the version the result
  may be different, newer Safari versions add more capabilities.

  Depending on `SafariVersion` the converter also will limit the number of
  entries in JSON. Safari 15 supports up to 150k rules, older Safari versions
  support up to 50k rules.
- `optimize`: `Bool` - **Deprecated**. Removes generic cosmetic rules from the
  output.
- `advancedBlocking`: `Bool` - if `true`, convert rules that need to be
  interpreted by an additional extension (either a [WebExtension][safariwebextension], or a [Safari App Extension][safariappextension]).
- `advancedBlockingFormat`: `AdvancedBlockingFormat` - format for advanced
  rules output. Can be `.json` or `.txt` format. `.txt` is basically unchanged
  AdGuard format that is supposed to be interpreted by [tsurlfilter]-based web
  extension. `.json` is a "Safari content blocker"-like JSON syntax that is
  better suited for native Safari App Extension.
- `maxJsonSizeBytes`: `Int?` - provides a way to limit the size of the output
  JSON. This was required due to a [nasty iOS bug][#56] in iOS 17.
- `progress`: `Progress?` instance that can be used to report the amount of work
  that has been done, or cancel the process in the middle.

#### `convertArray()` return value

Returns an instance of `ConversionResult` with the following fields.

- `totalConvertedCount`: `Int` - total entries count in the compilation result
  (before removing overlimit).
- `convertedCount`: `Int` - Entries count in the result after reducing to the
  limit defined by `SafariVersion`.
- `errorsCount`: `Int` - Count of conversion errors (i.e. count of rules that we
  could not convert).
- `overLimit`: `Bool` - If `true`, the limit was exceeded.
- `converted`: `String` - Resulting JSON with Safari content blocker rules.
- `advancedBlockingConvertedCount`: `Int` - Count of advanced blocking rules.
- `advancedBlocking`: `String?` - JSON with advanced content blocking rules. It
  is only set when `advancedBlockingFormat` is set to `.json`.
- `advancedBlockingText`: `String?` - plain text list of advanced content
  blocking rules. It is only set when `advancedBlockingFormat` is set to `.txt`.
- `message`: `String` - message with the overall conversion status.

> [!TIP]
> In order to keep parsing fast, we heavily rely on `UTF8View`. Users need to
> avoid extra conversion to UTF-8. Please make sure that the filter's content
> is stored with this encoding. You can ensure this by calling
> [`makeContiguousUTF8`][makecontiguousutf8] before splitting the filter
> content into rules to pass them to the converter. If the `String` is already
> contiguous, this call does not cost anything.

[tsurlfilter]: https://github.com/AdguardTeam/tsurlfilter
[#56]: https://github.com/AdguardTeam/SafariConverterLib/issues/56
[makecontiguousutf8]: https://developer.apple.com/documentation/swift/string/makecontiguousutf8()

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

Run `yarn install` to prepare the node module. This command will automatically
trigger compilation of the `ConverterTool` command-line tool as node module
relies on it.

Node module provides the following methods.

#### `jsonFromRules(rules, advancedBlocking, safariVersion, converterToolPath)`

Converts an array of [AdGuard rules][adguardrules] to JSON with Safari rules.

- `rules` - array of rules to convert.
- `advancedBlocking` - if `true`, advanced content blocking rules will also be
  provided in the result.
- `safariVersion` - target Safari version.
- `converterToolPath` - (optional) path to the `ConverterTool` binary. If not
  set, it will use the version packed with the node module.

### `getConverterVersion`

Returns the Safari Converter version.

## Supported rules and limitations

Safari Converter aims to support [AdGuard filtering rules syntax][adguardrules]
as much as possible, but still there are limitations and shortcomings that are
hard to overcome.

### Basic (network) rules

Safari Converter supports a substantial subset of [basic rules][basicrules] and
certainly supports the most important types of those rules.

[basicrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#basic-rules

#### Supported with limitations

- [Regular expression rules][regexrules] are limited to the subset of regex that
  is [supported by Safari][safariregex].

- `$domain` - [domain modifier][domainmodifier] is supported with several
  limitations.

  - It's impossible to mix allowed and disallowed domains (like
    `$domain=example.org|~sub.example.org`). Please upvote the
    [feature request][webkitmixeddomainsissue] to WebKit to lift this
    limitation.
  - "Any TLD" (i.e. `domain.*`) is not fully supported. In the current
    implementation the converter just replaces `.*` with top 100 popular TLDs.
    This implementation will be improved [in the future][iftopurlissue].
  - Using regular expressions in `$domain` is not supported, but it also will
    be improved [in the future][iftopurlissue].

- `$denyallow` - this modifier is supported via converting `$denyallow` rule to
  a set of rules (one blocking rule + several unblocking rules).

  Due to that limitation `$denyallow` is only allowed when the rule also has
  `$domain` modifier.

  - Generic rule `*$denyallow=x.com,image,domain=a.com` will be converted to:

    ```adblock
    *$image,domain=a.com
    @@||x.com$image,domain=a.com
    ```

  - Rule `/banner.png$image,denyallow=test1.com|test2.com,domain=example.org`
    will be converted to:

    ```adblock
    /banner.png$image,domain=example.org
    @@||test1.com/banner.png$image,domain=example.org
    @@||test1.com/*/banner.png$image,domain=example.org
    @@||test2.com/banner.png$image,domain=example.org
    @@||test2.com/*/banner.png$image,domain=example.org
    ```

  - Rule without `$domain` is **not supported**: `$denyallow=a.com|b.com`.

- `$popup` - popup rules are supported, but they're basically the same as
  `$document`-blocking rules and will not attempt to close the tab.

- Exception rules (`@@`) disable cosmetic filtering on matching domains.

  Exception rules in Safari rely on the rule type `ignore-previous-rules` so to
  make it work we have to order the rules in a specific order. Exception rules
  without modifiers are placed at the end of the list and therefore they disable
  not just URL blocking, but cosmetic rules as well.

  This limitation may be lifted if [#70] is implemented.

- `$urlblock`, `$genericblock` is basically the same as `$document`, i.e. it
  disable all kinds of filtering on websites.

  These limitations may be lifted when [#69] and [#71] are implemented.

- `$content` makes no sense in the case of Safari since HTML filtering rules
  are not supported so it's there for compatibility purposes only. Rules with
  `$content` modifier are limited to `document` resource type.

- `$specifichide` is implemented by scanning existing element hiding rules and
  removing the target domain from their `if-domain` array.

  - `$specifichide` rules MUST target a domain, i.e. be like this:
    `||example.org^$specifichide`. Rules with more specific patterns will be
    discarded, i.e. `||example.org/path$specifichide` will not be supported.
  - `$specifichide` rules only cover rules that target the same domain as the
    rule itself, subdomains are ignored. I.e. the rule
    `@@||example.org^$specifichide` will disable `example.org##.banner`, but
    will ignore `sub.example.org##.banner`. This limitation may be lifted if
    [#72] is implemented.

- `urlblock`, `genericblock`, `generichide`, `elemhide`, `specifichide`, and
  `jsinject` modifiers can be used only as a single modifier in a rule. This
  limitation may be lifted in the future: [#73].

- `$websocket` (fully supported starting with Safari 15).

- `$ping` (fully supported starting with Safari 14).

[regexrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#regexp-support
[safariregex]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker#Capture-URLs-by-pattern
[webkitmixeddomainsissue]: https://bugs.webkit.org/show_bug.cgi?id=226076
[domainmodifier]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#domain-modifier
[iftopurlissue]: https://github.com/AdguardTeam/SafariConverterLib/issues/20#issuecomment-2532818732
[#69]: https://github.com/AdguardTeam/SafariConverterLib/issues/69
[#70]: https://github.com/AdguardTeam/SafariConverterLib/issues/70
[#71]: https://github.com/AdguardTeam/SafariConverterLib/issues/71
[#72]: https://github.com/AdguardTeam/SafariConverterLib/issues/72
[#73]: https://github.com/AdguardTeam/SafariConverterLib/issues/73

#### Not supported

- `$app`
- `$header`
- `$method`
- `$strict-first-party` (to be supported in the future: [#64])
- `$strict-third-party` (to be supported in the future: [#65])
- `$to` (to be supported in the future: [#60])
- `$extension`
- `$stealth`
- `$cookie` (partial support in the future: [#54])
- `$csp`
- `$hls`
- `$inline-script`
- `$inline-font`
- `$jsonprune`
- `$xmlprune`
- `$network`
- `$permissions`
- `$redirect`
- `$redirect-rule`
- `$referrerpolicy`
- `$removeheader`
- `$removeparam`
- `$replace`
- `$urltransform`

[#64]: https://github.com/AdguardTeam/SafariConverterLib/issues/64
[#65]: https://github.com/AdguardTeam/SafariConverterLib/issues/65
[#60]: https://github.com/AdguardTeam/SafariConverterLib/issues/60
[#54]: https://github.com/AdguardTeam/SafariConverterLib/issues/54

### Cosmetic rules

Safari Converter supports most of the [cosmetic rules][cosmeticrules] although
only element hiding rules with basic CSS selectors are supported natively via
Safari Content Blocking, everything else needs to be interpreted by an
additional extension.

[cosmeticrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#cosmetic-rules

#### Limitations of cosmetic rules

- Specifying domains is subject of the same limitations as the `$domain`
  modifier of basic rules.

- [Non-basic rules modifiers][nonbasicmodifiers] are supported with some
  limitations:

  - `$domain` - the same limitations as everywhere else.
  - `$path` - supported, but if you use regular expressions, they will be
    limited to the subset of regex that is [supported by Safari][safariregex].
  - `$url` - to be supported in the future: [#68]

[nonbasicmodifiers]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#non-basic-rules-modifiers
[#68]: https://github.com/AdguardTeam/SafariConverterLib/issues/68

### Script/scriptlet rules

Safari Converter fully supports both [script rules][scriptrules] and
[scriptlet rules][scriptletrules]. However, these rules can only be interpreted
by a separate extension.

> [!WARNING]
> For scriptlet rules it is **very important** to run them as soon as possible
> when the page is loaded. The reason for that is that it's important to run
> earlier than the page scripts do. Unfortunately, with Safari there will always
> be a slight delay that can decrease the quality of blocking.

[scriptrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#javascript-rules
[scriptletrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#scriptlets

### HTML filtering rules

[HTML filtering rules][htmlfilteringrules] are **not supported** and will not be
supported in the future. Unfortunately, Safari does not provide necessary
technical capabilities to implement them.

[htmlfilteringrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/#html-filtering-rules

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

Push a new tag in `v*.*.*` format, then provided github action is intended to
build and publish new release with an asset binary.

### Third-party dependencies

- [Punycode][punycode]
- [ArgumentParser][argumentparser]

[punycode]: https://github.com/gumob/PunycodeSwift
[argumentparser]: https://github.com/apple/swift-argument-parser

TODO(ameshkov): !!! Update docs, add lint/format commands
TODO(ameshkov): !!! Explain how to update dependencies