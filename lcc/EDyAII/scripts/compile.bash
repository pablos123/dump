#!/usr/bin/env bash

ghc "$1" -Wall -Wno-type-defaults -o compiled || exit 1

echo "================================================="

./compiled
