#!/bin/sh
#
# Sets `spec.version` in every podspec that describes this repository to the
# given version. The bridge podspecs (PunycodeSwift, swift-psl) describe
# third-party packages and are left untouched.
#
# Usage:
#   scripts/update-podspec-versions.sh v4.4.0
#   scripts/update-podspec-versions.sh 4.4.0

set -eu

if [ $# -ne 1 ]; then
    echo "usage: $(basename "$0") <version>" >&2
    exit 2
fi

version=${1#v}

if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'; then
    echo "error: '$1' is not a semantic version (expected vX.Y.Z or X.Y.Z)" >&2
    exit 1
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
updated=0

for podspec in "$root"/*.podspec; do
    # Bridge podspecs point at third-party repositories.
    grep -q 'AdguardTeam/SafariConverterLib' "$podspec" || continue

    perl -pi -e "s|^([ \t]*)spec\.version = '[^']*'|\${1}spec.version = '$version'|" "$podspec"
    echo "updated $(basename "$podspec") to $version"
    updated=$((updated + 1))
done

if [ "$updated" -eq 0 ]; then
    echo "error: no podspecs of this repository found in $root" >&2
    exit 1
fi
