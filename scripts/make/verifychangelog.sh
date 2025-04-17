#!/bin/bash
# This script checks that the version was added to CHANGELOG.md
# Usage: ./scripts/make/verifychangelog.sh <LIBRARY_VERSION>

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <LIBRARY_VERSION>"
    exit 1
fi

LIB_VERSION="$1"

# Check if the version is present in CHANGELOG.md
if ! grep -q "^## \[v$LIB_VERSION\]$" CHANGELOG.md; then
    echo "Error: Version $LIB_VERSION not found in CHANGELOG.md."
    echo "Please add \"## [v$LIB_VERSION]\" section and describe the changes."
    exit 1
fi
