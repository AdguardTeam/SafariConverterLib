#!/usr/bin/env python3

"""Generates `ContentBlockerConverterVersion.swift` for CocoaPods consumers.

SwiftPM gets the constant from the `GenerateVersion` build-tool plugin
(`Plugins/GenerateVersion/plugin.swift`), and CocoaPods does not run build-tool
plugins. This script produces the same file from the same inputs, so that both
consumers see the same values:

* the library version is the first released heading in `CHANGELOG.md`;
* the component versions are the JavaScript dependencies in
  `Extension/package.json`, with the range operators stripped.

Usage:
    python3 scripts/generate-content-blocker-converter-version.py [output]
"""

import json
import re
import sys
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / 'CHANGELOG.md'
PACKAGE_JSON = ROOT / 'Extension' / 'package.json'
DEFAULT_OUTPUT = Path('ContentBlockerConverterVersion.swift')

RELEASED_HEADING_RE = re.compile(r'^## \[([^\]]+)\]')
RANGE_OPERATORS = '^~>=<'

TEMPLATE = '''// This file is generated. Do not edit, and do not commit it: the version lives
// in CHANGELOG.md only.

/// Version information for the SafariConverterLib and its components. It can be
/// used in the apps that are using this library.
public enum ContentBlockerConverterVersion {
    /// Version of SafariConverterLib and @adguard/safari-extension.
    public static let library = "$library"

    /// Version of @adguard/scriptlets (component of the JS library).
    public static let scriptlets = "$scriptlets"

    /// Version of @adguard/extended-css (component of the JS library).
    public static let extendedCSS = "$extendedCSS"
}
'''


def library_version():
    """Returns the first released version of the changelog."""
    for line in CHANGELOG.read_text(encoding='utf-8').splitlines():
        match = RELEASED_HEADING_RE.match(line)
        if match and match.group(1)[:1].isdigit():
            return match.group(1)

    raise SystemExit(f'error: no released version found in {CHANGELOG}')


def component_version(name):
    """Returns the version of a JavaScript dependency without its range operators."""
    dependencies = json.loads(PACKAGE_JSON.read_text(encoding='utf-8'))['dependencies']
    if name not in dependencies:
        raise SystemExit(f'error: {name} is not a dependency of {PACKAGE_JSON}')

    return dependencies[name].strip(RANGE_OPERATORS)


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    output.write_text(
        Template(TEMPLATE).substitute(
            library=library_version(),
            scriptlets=component_version('@adguard/scriptlets'),
            extendedCSS=component_version('@adguard/extended-css'),
        ),
        encoding='utf-8',
    )
    print(f'generated {output}')


if __name__ == '__main__':
    main()
