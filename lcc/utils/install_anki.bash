#!/usr/bin/env bash

sudo apt install libxcb-xinerama0 libxcb-cursor0 libnss3 zstd

cd ~/Downloads || exit 1

wget https://github.com/ankitects/anki/releases/download/25.09/anki-launcher-25.09-linux.tar.zst
tar xaf anki-launcher-25.09-linux.tar.zst
cd anki-launcher-25.09-linux || exit 1

sudo ./install.sh

anki
