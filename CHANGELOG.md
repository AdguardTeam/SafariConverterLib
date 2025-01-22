# Safari Converter Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Filtering Engine

One of the main challenges when developing Safari extension is its async nature.
For a content blocker it is critically important to be inject scripts and styles
as soon as possible; in the ideal scenario it should be injected before page own
scripts are executed.

* TODO: Remove json format for advanced blocking
* TODO: Update `safari-blocker` and make samples for both WebExtension and AppExtension.
* TODO: Add more text to justification
* TODO: Explain what was removed (ContentBlockerEngine)
* TODO: Explain what was added (FilterEngine) and how to use it
* TODO: Update and test the console tool
* TODO: Update and test the node module
* TODO: Remove `optimize` flag

## 2.1.1

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

## v2.0.48

### Added

- Allow specifying the final CB JSON file size limit: [#56]

[#56]: https://github.com/AdguardTeam/SafariConverterLib/issues/56

## v2.0.43

### Fixed

- `$match-case` modifier does not work: [#55]

[#55]: https://github.com/AdguardTeam/SafariConverterLib/issues/55

## v2.0.40

### Changed

- Pseudo-classes `:not()` and `:is()` should be handled natively in the same
  way as `:has()`: [#47]

[#47]: https://github.com/AdguardTeam/SafariConverterLib/issues/47

### Fixed

- Do not split rules with many domains in the `unless-domain` and `if-domain`: [#51]
- Exclude rules containing `if-domain` and `unless-domain` with regex values: [#53]

[#51]: https://github.com/AdguardTeam/SafariConverterLib/issues/51
[#53]: https://github.com/AdguardTeam/SafariConverterLib/issues/53

## v2.0.39

### Fixed

- Handling provided Safari version for minor version as well, not just the major
  one.

## v2.0.38

### Fixed

- Handling provided Safari version.

## v2.0.34

### Fixed

- Reverted native support of `:has` selector in the content blocker because
  Safari 16 is not supporting it yet.
  Corresponding [bug][webkit248868].

[webkit248868]: https://bugs.webkit.org/show_bug.cgi?id=248868
