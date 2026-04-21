#!/usr/bin/env bash

ghc "$1" -Wall -Wno-type-defaults -o compiled >/dev/null

./compiled
