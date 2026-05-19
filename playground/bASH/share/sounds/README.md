# pokidle sound assets

Seven short OGG Vorbis clips ship here:

| File | When played | Policy |
|------|-------------|--------|
| `encounter.ogg`  | every pokemon encounter         | only if `POKIDLE_SOUND=always` |
| `shiny.ogg`      | shiny encounters                | `POKIDLE_SOUND=shiny` (default) or `always` |
| `legendary.ogg`  | every legendary spawn           | `POKIDLE_SOUND=shiny` (default) or `always`; falls back shiny → encounter |
| `item.ogg`       | item drop notification          | only if `POKIDLE_SOUND=always` |
| `biome.ogg`      | biome rotation notification     | only if `POKIDLE_SOUND=always` |
| `level.ogg`      | level-up tick notification      | only if `POKIDLE_SOUND=always` |
| `friendship.ogg` | friendship tick notification    | only if `POKIDLE_SOUND=always` |

`POKIDLE_NO_SOUND=1` silences everything regardless of policy.

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
| `POKIDLE_SOUND=never` | disable every kind |
| `POKIDLE_SOUND=shiny` (default) | only shiny + legendary play |
| `POKIDLE_SOUND=always` | every kind plays |

Silence one kind individually with `POKIDLE_SOUND_<KIND>=` (empty string).

## Replacing the bundled clips

Bundled clips are synthetic sine-wave placeholders (`ffmpeg sine=...`). Drop a replacement at the same path to override, or set `$POKIDLE_SOUND_<KIND>` to point elsewhere.

CC0 sources:
- <https://freesound.org> (filter: CC0)
- <https://opengameart.org> (filter: CC0 / CC-BY)

Convert with:

```sh
ffmpeg -i source.wav -c:a libvorbis -q:a 4 share/sounds/<kind>.ogg
```
