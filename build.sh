#!/bin/bash

swift build -v -c release
mkdir -p bin
cp .build/release/ConverterTool bin
