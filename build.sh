#!/bin/bash

swift build -v -c release
mkdir -p bin
cp .build/release/ConverterTool bin

LIB_VERSION=$(node -p -e "require('./package.json').version")
touch bin/ConverterTool.json
echo "{\"version\": \"$LIB_VERSION\"}" > bin/ConverterTool.json
