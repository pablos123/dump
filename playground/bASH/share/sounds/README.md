# pokidle sound assets

Seven short OGG Vorbis clips ship here:

| File | When played | Policy |
|------|-------------|--------|
| `encounter.ogg`  | every pokemon encounter            | only if `POKIDLE_SOUND=always` |
| `shiny.ogg`      | shiny encounters                   | `POKIDLE_SOUND=shiny` (default) or `always` |
| `legendary.ogg`  | every legendary spawn              | unconditional (falls back shiny → encounter) |
| `item.ogg`       | item drop notification             | unconditional |
| `biome.ogg`      | biome rotation notification        | unconditional |
| `level.ogg`      | level-up tick notification         | unconditional |
| `friendship.ogg` | friendship tick notification       | unconditional |

"Unconditional" = plays whenever the corresponding notification fires, ignoring `POKIDLE_SOUND`. `POKIDLE_NO_SOUND=1` still silences everything.

Setup symlinks `share/sounds` → `$POKIDLE_DATA_DIR/sounds`, so the daemon resolves files via the data dir.

## How the daemon resolves sound files

For each kind, first match wins:

| Priority | Variable / path |
|----------|-----------------|
| 1 | `$POKIDLE_SOUND_<KIND>` (full path override; set empty to disable that kind) |
| 2 | `$POKIDLE_DATA_DIR/sounds/<kind>.ogg` |

Recognised `<KIND>` values: `ENCOUNTER`, `SHINY`, `LEGENDARY`, `ITEM`, `BIOME`, `LEVEL`, `FRIENDSHIP`.

Missing file → silent skip, no error. Playback uses `paplay` (PulseAudio) if available, else `aplay` (ALSA).

## Global gates

| Variable | Effect |
|----------|--------|
| `POKIDLE_NO_SOUND=1` | disable sound for every kind |
| `POKIDLE_SOUND=never` | disable encounter + shiny (others still play) |
| `POKIDLE_SOUND=shiny` (default) | shiny plays, encounter silent |
| `POKIDLE_SOUND=always` | both encounter and shiny play |

Legendary, item, biome, level, friendship ignore `POKIDLE_SOUND`; silence them individually with `POKIDLE_SOUND_<KIND>=`.

## Replacing the bundled clips

Bundled clips are synthetic sine-wave placeholders (`ffmpeg sine=...`). Drop a replacement at the same path to override, or set `$POKIDLE_SOUND_<KIND>` to point elsewhere.

CC0 sources:
- <https://freesound.org> (filter: CC0)
- <https://opengameart.org> (filter: CC0 / CC-BY)

Convert with:

```sh
ffmpeg -i source.wav -c:a libvorbis -q:a 4 share/sounds/<kind>.ogg
```
