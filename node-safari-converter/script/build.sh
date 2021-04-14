#!/bin/bash

mkdir -p bin

swift build -v -c release --arch x86_64
swift build -v -c release --arch arm64

lipo -create .build/x86_64-apple-macosx/release/ConverterTool .build/arm64-apple-macosx/release/ConverterTool -output bin/ConverterTool

rm -rf .build
