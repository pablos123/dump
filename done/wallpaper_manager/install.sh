#!/usr/bin/env bash
CFLAGS="-g -Wall -Wextra $(pkg-config --cflags x11 libpng)"
LDFLAGS="$(pkg-config --libs x11 libpng)"

gcc ${CFLAGS} -o "${HOME}"/.local/bin/sws_image_c sws_image_c.c ${LDFLAGS}
gcc ${CFLAGS} -o "${HOME}"/.local/bin/sws_video_c sws_video_c.c ${LDFLAGS}
cp sws "${HOME}"/.local/bin/
