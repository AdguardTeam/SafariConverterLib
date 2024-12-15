# Safari Converter Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Performance

Several important changes were made to the conversion code that allowed to
increase the library performance **~5 times**.

Here's how it was achieved:

- Conversion logic does not use `NSString` anymore.
- Improved the way `$badfilter` rules are interpreted.
- Switched to one-pass algorithms in several places: `NetworkRuleParser`,
  `SimpleRegex`, `SafariRegex`, `CosmeticRuleMarker`.
- Replaced `enum` with `OptionSet` for handling `NetworkRule` modifiers and
  content types.

- Complete refactoring of the conversion logic.
- TODO(ameshkov): !!! Add the full list of changes.

### Changed

- Improved the `domain.TLD` implementation.
  TODO: Explain

- Refactoring

  - Removed `SafariService`, `SafariVersion` is now correctly passed to the
    underlying code instead of relying on a singleton.
  
  - Removed `allTests`, it's not required anymore in modern Swift.
  
  - Moved the logic from `ConversionResult` to `Distributor`.

### Fixed

- Improved regular expression validation.
  TODO: Explain

## v2.0.48

### Added

- Allow specifying the final CB json file size limit: [#56]

[#56]: https://github.com/AdguardTeam/SafariConverterLib/issues/56

## v2.0.43

### Fixed

- `$match-case` modifier does not work: [#55]

[#55]: https://github.com/AdguardTeam/SafariConverterLib/issues/55

## v2.0.40

### Changed

- Pseudo-classes `:not()` and `:is()` should be handled natively in the sam
  way as `:has()`: [#47]

[#47]: https://github.com/AdguardTeam/SafariConverterLib/issues/47

### Fixed

- Do not split rules with many domains in the `unless-domain` and `if-domain`: [#51]
- Exclude rules containing `if-domain` and `unless-domain` with regex values: [#53]

[#51]: https://github.com/AdguardTeam/SafariConverterLib/issues/51
[#53]: https://github.com/AdguardTeam/SafariConverterLib/issues/53

## v2.0.39

### Fixed

- Handling provided Safari version for minor version as well, not just major
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
