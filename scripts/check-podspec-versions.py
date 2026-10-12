#!/usr/bin/env python3

"""Checks that bridge podspecs pin the same versions as Package.resolved.

Bridge podspecs (PunycodeSwift, swift-psl) describe third-party SwiftPM
dependencies for CocoaPods consumers. Their `spec.version` mirrors the version
SwiftPM resolves, so the two must stay in sync: an update of Package.resolved
without the matching bridge update silently ships a different library to
CocoaPods consumers.

Usage:
    python3 scripts/check-podspec-versions.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# SwiftPM package identity -> bridge podspec that mirrors it.
BRIDGES = {
    'punycodeswift': 'PunycodeSwift.podspec',
    'swift-psl': 'swift-psl.podspec',
}

VERSION_RE = re.compile(r"^\s*spec\.version = '([^']+)'", re.MULTILINE)


def resolved_versions():
    """Returns {identity: version} for every pinned SwiftPM dependency."""
    data = json.loads((ROOT / 'Package.resolved').read_text(encoding='utf-8'))

    versions = {}
    for pin in data['pins']:
        version = pin.get('state', {}).get('version')
        if version:
            versions[pin['identity']] = version
    return versions


def podspec_version(podspec):
    """Returns the `spec.version` of the given podspec file."""
    path = ROOT / podspec
    if not path.is_file():
        raise SystemExit(f'error: {podspec} does not exist')

    match = VERSION_RE.search(path.read_text(encoding='utf-8'))
    if match is None:
        raise SystemExit(f'error: no `spec.version` found in {podspec}')

    return match.group(1)


def main():
    versions = resolved_versions()
    failures = []

    for identity, podspec in BRIDGES.items():
        resolved = versions.get(identity)
        if resolved is None:
            failures.append(
                f'{podspec}: {identity} is missing from Package.resolved'
            )
            continue

        pinned = podspec_version(podspec)
        if pinned != resolved:
            failures.append(
                f'{podspec}: spec.version is {pinned!r}, but Package.resolved '
                f'pins {identity} to {resolved!r}'
            )
        else:
            print(f'ok: {podspec} matches {identity} {resolved}')

    if failures:
        for failure in failures:
            print(f'error: {failure}', file=sys.stderr)
        print(
            'hint: update the bridge podspec version together with '
            'Package.resolved',
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == '__main__':
    sys.exit(main())
