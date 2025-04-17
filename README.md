# Safari Converter

This is a library that provides a compatibility layer between
[AdGuard filtering rules][adguardrules] and [Safari content blocking rules][safarirules].

[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[safarirules]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker

- [Converter](#converter)
    - [Using as a library](#using-as-a-library)
    - [Command-line interface](#command-line-interface)
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

Note that not every rule can be supported natively, so there's also a concept of
"advanced rules," the rules that have to be interpreted by a separate extension,
either a [WebExtension][safariwebextension] or a
[Safari App Extension][safariappextension].

[safariwebextension]: https://developer.apple.com/documentation/safariservices/safari-web-extensions
[safariappextension]: https://developer.apple.com/documentation/safariservices/safari-app-extensions

### Using as a library

You can check out the [demo project][safariblocker] to see how to use the
library. It showcases all the features of the library.

The first step is to use an instance of [ContentBlockerConverter] to convert
AdGuard rules into the rules that Safari understands.

```swift
    let result: ConversionResult = ContentBlockerConverter().convertArray(
        rules: lines,
        safariVersion: SafariVersion.autodetect(),
        advancedBlocking: true,
        maxJsonSizeBytes: nil,
        progress: nil
    )
```

> [!TIP]
> In order to keep parsing fast, we heavily rely on `UTF8View`. Users need to
> avoid extra conversion to UTF-8. Please make sure that the filter's content
> is stored with this encoding. You can ensure this by calling
> [`makeContiguousUTF8`][makecontiguousutf8] before splitting the filter
> content into rules to pass them to the converter. If the `String` is already
> contiguous, this call does not cost anything.

Once the conversion is finished, you'll have a [ConversionResult] object that
contains two important fields:

- `safariRulesJSON` - JSON with Safari content blocking rules. This JSON should
  be interpreted by [a content blocker][safarirules].
- `advancedRulesText` - AdGuard rules that need to be interpreted by
  web extension (or app extension). Please refer to the
  [extension's README][extension-readme] for details.

> [!IMPORTANT]
> Please read the [extension's README][extension-readme] for the explanation
> on how to use the advanced rules.

In addition to that you can use `ContentBlockerConverterVersion` class to get
the version of the library and its components in your app.

```swift
let version = ContentBlockerConverterVersion.library
let scriptletsVersion = ContentBlockerConverterVersion.scriptlets
let extendedCSSVersion = ContentBlockerConverterVersion.extendedCSS
```

[ConversionResult]: Sources/ContentBlockerConverter/ConversionResult.swift
[ContentBlockerConverter]: Sources/ContentBlockerConverter/ContentBlockerConverter.swift
[makecontiguousutf8]: https://developer.apple.com/documentation/swift/string/makecontiguousutf8()
[safariblocker]: https://github.com/ameshkov/safari-blocker
[extension-readme]: Extension/README.md

### Command-line interface

Converter can be built as a command-line tool with the following interface:

```text
OVERVIEW: Tool for converting rules to JSON or building the FilterEngine binary.

USAGE: ConverterTool <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  convert (default)       Convert AdGuard rules to Safari content blocking JSON
                          and advanced rules for a web extension.
  buildengine             Build the FilterEngine binary.

  See 'ConverterTool help <subcommand>' for detailed help.
```

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

- `$urlblock`, `$genericblock` is basically the same as `$document`, i.e., it
  disables all kinds of filtering on websites.

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

- `$jsinject` - rules with this modifier are converted to advanced blocking rules.
  Currently, `$jsinject` modifier can be used only as a single modifier in a rule. This
  limitation may be lifted in the future: [#73].

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

- Specifying domains is subject to the same limitations as the `$domain`
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

Please refer to [DEVELOPMENT.md](DEVELOPMENT.md) for details.

### Releasing new version

1. Choose the new version using [Semantic Versioning][semver].
2. Update the [CHANGELOG.md](CHANGELOG.md) and add new version
   information.
3. Run `VERSION=${version} make codegen` to update the version of the extension,
   and to generate `ContentBlockerConverterVersion`.
4. Make `Bump version to ${version}` commit.
5. Run `Converter - build for release` plan in Bamboo and override
   `release.version` variable.
6. This plan will add a new tag in `v*.*.*` format.
7. Run the linked `Converter - deploy` plan:
    - This plan will publish to NPM the new version of the library
      [@adguard/safari-extension][adguard-safari-extension]
    - It will also publish a new Github release to this repo.

[semver]: https://semver.org/
[adguard-safari-extension]: https://www.npmjs.com/package/@adguard/safari-extension

### Third-party dependencies

- [Punycode][punycode]
- [ArgumentParser][argumentparser]
- [swift-psl][swift-psl]

[punycode]: https://github.com/gumob/PunycodeSwift
[argumentparser]: https://github.com/apple/swift-argument-parser
[swift-psl]: https://github.com/ameshkov/swift-psl
