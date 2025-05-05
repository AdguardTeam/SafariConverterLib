# Safari Converter Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

Nothing here so far.

## [v3.0.0]

### Added `ContentBlockerConverterVersion` [#78]

The library now exposes the version of its components and of the library itself.
This information can be useful to the apps that are using that library. For
example, to print it to the about page.

[#78]: https://github.com/AdguardTeam/SafariConverterLib/issues/78

### Added [FilterEngine]

One of the main challenges when developing Safari extension is its async nature.
For a content blocker it is critically important to be inject scripts and styles
as soon as possible; in the ideal scenario it should be injected before page own
scripts are executed.

There are several challenges here:

1. Messaging between the parts of the extension is not free. It takes several
   milliseconds to send a message and wait for a response. We need to avoid
   adding any overhead on top of it.

2. The native host initialization time is very important. The problem is that
   in the case of both Safari Web Extension and Safari App Extension the native
   extension host process is ephemeral and does not persist for a long time,
   even a very short period of inactivity is enough to cause the process to be
   terminated. Initialization time of an empty extension may take ~100ms which
   is by itself is a very high cost, but we should avoid making it higher.

Therefore, in order to solve these challenges we need to provide
an implementation of a filtering engine that is focused on two points:

- Fast initialization
- Fast rules lookup

In order to achieve that we developed `FilterEngine`. This `FilterEngine` is
based on a binary trie implementation which allows zero-time deserialization
and fast rules lookup at the same time.

[FilterEngine]: ./Sources/FilterEngine/FilterEngine.swift

### Added [@adguard/safari-extension][extensionreadme] and [WebExtension]

[FilterEngine] is a rather low-level component and integrating it would take
a lot of work. To avoid that we implemented two new high-level components:

- [WebExtension] takes care of the engine serialization and deserialization.
- [@adguard/safari-extension][extensionreadme] is a javascript module that
  should be used by the browser extension.

> [!IMPORTANT]
> If you're migrating from a different scheme, you need to make sure that the
> new [WebExtension] can seamlessly replace the old one without requesting the
> user to open the app (i.e. migration is done in the extension). The easiest
> way to achieve that would be to create `./webext` directory in the shared
> container and placing the plain text advanced rules there to
> `./webext/rules.txt`. [WebExtension] will be able to detect that the
> serialized engine is missing and will rebuild it.

[extensionreadme]: ./Extension/README.md
[WebExtension]: ./Sources/FilterEngine/WebExtension.swift

### Added `SafariVersion.autodetect()`

Every app that uses SafariConverterLib had to come up with the Safari version
auto-detection code. Adding this function will save some time.

### Changed `ContentBlockerConverter`

Several deprecated arguments were removed from the `convertArray` function:

- Removed `optimize` flag as it does provide any real value to the users.
- Removed `advancedBlockingFormat`. The old engine that was using `json`
  format is removed so now only plain text advanced rules format is required.

### Changed `CommandLineWrapper`

- In accordance to the changes of `ContentBlockerConverter.convertArray()` we
  changed the arguments that the command line wrapper accepts.
- Added `--input-path` option for specifying the file with source AdGuard rules.

  Now there are two options of passing the rules to the tool: stdin (default)
  or via an `--input-path` file.
- Added `buildengine` command that builds the `FilterEngine` serialized binary.

### Removed node module

AdGuard for Safari will soon switch from Electron so the node wrapper is not
required anymore.

[v3.0.0]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v3.0.0

## [v2.1.1]

### Performance

Several important changes were made to the conversion code that allowed us to
increase the library's performance by about **~4 times**.

CPU profiler results before the changes:

![Profiler results before changes][profilebefore]

CPU profiler results after the changes:

![Profiler results after changes][profileafter]

Here's how it was achieved:

- Conversion logic does not use `NSString` anymore. In the past, when the
  library was initially developed, we discovered that the native `String`
  performance was far from ideal for tasks like parsing. Back then, we thought
  that the solution would be to switch to `NSString`, and it did partly help,
  although it was never ideal.

  Since then, a lot of things have changed in Swift. `String`
  [switched][swiftutf8] to UTF-8 storage and received quite a lot of performance
  improvements. Note that `NSString` is UTF-16 and keeping using it creates
  additional overhead because of that.

  Now it's time to start using `String` again, but it still needs to be done
  very carefully to avoid spending extra time on reading graphemes instead of
  reading characters.

  > [!TIP]
  > In order to keep parsing fast, we heavily rely on `UTF8View`. Users need to
  > avoid extra conversion to UTF-8. Please make sure that the filter's content
  > is stored with this encoding. You can ensure this by calling
  > [`makeContiguousUTF8`][makecontiguousutf8] before splitting the filter
  > content into rules to pass them to the converter. If the `String` is already
  > contiguous, this call does not cost anything.
- Improved the way `$badfilter` rules are interpreted. The library was using a
  simple ineffective algorithm without any "indexing". Now `$badfilter` rules
  are grouped by the rule pattern, which significantly speeds up searching for
  a matching `$badfilter` rule.
- Switched to one-pass algorithms in several places: `NetworkRuleParser`,
  `SimpleRegex`, `SafariRegex`, `CosmeticRuleMarker`, parsing `$domain`.
- Replaced `enum` with `OptionSet` for handling `NetworkRule` modifiers and
  content types.

[profilebefore]: https://cdn.adtidy.org/content/blog/articles/safari_converter_2_1/profile_before.png
[profileafter]: https://cdn.adtidy.org/content/blog/articles/safari_converter_2_1/profile_after.png
[swiftutf8]: https://www.swift.org/blog/utf8-string/
[makecontiguousutf8]: https://developer.apple.com/documentation/swift/string/makecontiguousutf8()

### Added

- Added `$from` as an alias of `$domain`: [#60] (partly, yet to support `$to`)

[#60]: https://github.com/AdguardTeam/SafariConverterLib/issues/60

### Changed

- Improved the `domain.TLD` implementation. There is still no full support for
  matching `domain.TLD` (although, [in the future][iftopurlissue] we'll be able
  to support it better), but it should still be better now. Instead of replacing
  `.TLD` with the seemingly randomly selected top 200 TLDs we now rely on the
  [filters stats][toptld] and we hope it makes this feature more useful.

- Refactoring

    - Removed `SafariService`; `SafariVersion` is now passed down to the
    underlying code instead of relying on a singleton.

    - Removed `allTests`; it's not required anymore in modern Swift.

    - Moved the logic from `ConversionResult` to `Distributor`.

    - Improved unit tests, adding quite a lot of cases that were not covered by
    tests before.

[iftopurlissue]: https://github.com/AdguardTeam/SafariConverterLib/issues/20
[toptld]: https://github.com/AdguardTeam/FiltersRegistry/blob/master/scripts/wildcard-domain-processor/wildcard_domains.json

### Fixed

- Improved Safari-compatible regular expression validation. In the past we
  relied on a set of simple validation regular expressions that were checking
  for known unsupported sequences. Now the check does not rely on any regular
  expressions (which made it much faster), but at the same time it is more
  thorough and careful. Check out `SafariRegex` to see how it's done.

[v2.1.1]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.1.1

## [v2.0.48]

### Added

- Allow specifying the final CB JSON file size limit: [#56]

[#56]: https://github.com/AdguardTeam/SafariConverterLib/issues/56

[v2.0.48]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.0.48

## [v2.0.43]

### Fixed

- `$match-case` modifier does not work: [#55]

[#55]: https://github.com/AdguardTeam/SafariConverterLib/issues/55

[v2.0.43]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.0.43

## [v2.0.40]

### Changed

- Pseudo-classes `:not()` and `:is()` should be handled natively in the same
  way as `:has()`: [#47]

[#47]: https://github.com/AdguardTeam/SafariConverterLib/issues/47

### Fixed

- Do not split rules with many domains in the `unless-domain` and `if-domain`: [#51]
- Exclude rules containing `if-domain` and `unless-domain` with regex values: [#53]

[#51]: https://github.com/AdguardTeam/SafariConverterLib/issues/51
[#53]: https://github.com/AdguardTeam/SafariConverterLib/issues/53

[v2.0.40]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.0.40

## [v2.0.39]

### Added

- Support for the native `:has()` pseudo-class in Safari 16.4 and later [#43].
  However, its ExtendedCss implementation can still be enforced using the `#?#` rule marker.

### Fixed

- Handling provided Safari version for minor version as well, not just the major
  one.

[v2.0.39]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.0.39
[#43]: https://github.com/AdguardTeam/SafariConverterLib/issues/43

## [v2.0.38]

### Fixed

- Handling provided Safari version.

[v2.0.38]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.0.38

## [v2.0.34]

### Fixed

- Reverted native support of `:has` selector in the content blocker because
  Safari 16 is not supporting it yet.
  Corresponding [bug][webkit248868].

[webkit248868]: https://bugs.webkit.org/show_bug.cgi?id=248868

[v2.0.34]: https://github.com/AdguardTeam/SafariConverterLib/releases/tag/v2.0.34
