#!/bin/bash

mkdir -p bin

swift build -v -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/ConverterTool bin

rm -rf .build
