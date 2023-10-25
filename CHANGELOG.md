# Safari Converter Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## v2.0.48

### Added

- Allow specifying the final CB json file size limit[#56](https://github.com/AdguardTeam/SafariConverterLib/issues/56)


## v2.0.43

### Fixed

- `$match-case` modifier does not work [#55](https://github.com/AdguardTeam/SafariConverterLib/issues/55).


## v2.0.40

### Changed

- Pseudo-classes `:not()` and `:is()` should be handled natively in the same way as `:has()`
  [#47](https://github.com/AdguardTeam/SafariConverterLib/issues/47).

### Fixed

- Do not split rules with many domains in the unless-domain and if-domain
  [#51](https://github.com/AdguardTeam/SafariConverterLib/issues/51).
- Exclude rules containing if-domain and unless-domain with regex values
  [#53](https://github.com/AdguardTeam/SafariConverterLib/issues/53).


## v2.0.39

### Fixed

- Handling provided Safari version for minor version as well, not just major one.


## v2.0.38

### Fixed

- Handling provided Safari version.

## v2.0.34

### Fixed

- Reverted native support of :has selector in the content blocker because safari 16 is not supporting it yet.
  Corresponding [bug](https://bugs.webkit.org/show_bug.cgi?id=248868).
