# pokidle sound assets

Drop `encounter.ogg` and `shiny.ogg` in this directory to enable sound
notifications. They will be played by the daemon (see `lib/notify.bash`,
`_play_sound`).

## How the daemon resolves sound files

For each sound kind (`encounter` / `shiny`), the first match wins:

| Priority | Variable / path |
|----------|-----------------|
| 1 | `$POKIDLE_SOUND_ENCOUNTER` or `$POKIDLE_SOUND_SHINY` (full path override) |
| 2 | `$POKIDLE_DATA_DIR/sounds/{encounter,shiny}.ogg` (post-install data dir) |
| 3 | `$POKIDLE_REPO_ROOT/share/sounds/{encounter,shiny}.ogg` (running from repo) |

If the resolved path does not exist the daemon skips playback silently — no
error, no crash.

Playback uses `paplay` (PulseAudio) if available, otherwise falls back to
`aplay` (ALSA).

## Playback policy (`$POKIDLE_SOUND`)

| Value | Behaviour |
|-------|-----------|
| `shiny` (default) | play only for shiny encounters |
| `always` | play for every encounter |
| `never` | disable sound entirely |

Set `POKIDLE_NO_SOUND=1` to disable sound regardless of policy.

## Suggestions for royalty-free sources

Two short clips (≤ 2 s each) work best. Good CC0 libraries:

- <https://freesound.org> (filter: CC0)
- <https://opengameart.org> (filter: CC0 / CC-BY)

## Converting to OGG Vorbis

`paplay` and `aplay` both handle OGG Vorbis well. To convert from any source
format:

```sh
ffmpeg -i encounter-source.wav -c:a libvorbis -q:a 4 share/sounds/encounter.ogg
ffmpeg -i shiny-source.wav     -c:a libvorbis -q:a 4 share/sounds/shiny.ogg
```

## Why no bundled assets?

The repo doesn't ship default sounds because we can't guarantee a clean
licensing chain for redistribution. Drop your own files here and
`lib/notify.bash` will pick them up automatically.
