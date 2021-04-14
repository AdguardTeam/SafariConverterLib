#!/bin/bash

mkdir -p bin/x64
mkdir -p bin/arm64

swift build -v -c release --arch x86_64
cp .build/x86_64-apple-macosx/release/ConverterTool bin/x64

swift build -v -c release --arch arm64
cp .build/arm64-apple-macosx/release/ConverterTool bin/arm64

rm -rf .build
