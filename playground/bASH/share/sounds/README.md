# pokidle sound assets

Three short OGG Vorbis clips ship here:

| File | When played |
|------|-------------|
| `encounter.ogg` | every encounter (when `POKIDLE_SOUND=always`) |
| `shiny.ogg`     | shiny encounters (when `POKIDLE_SOUND=shiny` — default — or `always`) |
| `legendary.ogg` | every legendary spawn (ignores `POKIDLE_SOUND`); falls back to shiny → encounter if missing |

Setup symlinks `share/sounds` → `$POKIDLE_DATA_DIR/sounds`, so the daemon resolves files via the data dir.

## How the daemon resolves sound files

For each kind, first match wins:

| Priority | Variable / path |
|----------|-----------------|
| 1 | `$POKIDLE_SOUND_<KIND>` (full path override) |
| 2 | `$POKIDLE_DATA_DIR/sounds/<kind>.ogg` |

Missing file → silent skip, no error.

Playback uses `paplay` (PulseAudio) if available, else `aplay` (ALSA).

## Playback policy (`$POKIDLE_SOUND`)

| Value | Behaviour |
|-------|-----------|
| `shiny` (default) | shiny encounters only |
| `always` | every encounter |
| `never` | disable sound entirely |

`POKIDLE_NO_SOUND=1` disables sound regardless of policy. Legendary ignores both — it always plays if its file is found.

## Replacing the bundled clips

Bundled clips are synthetic sine-wave placeholders (`ffmpeg sine=...`). Drop a replacement at the same path to override, or set `$POKIDLE_SOUND_<KIND>` to point elsewhere.

CC0 sources:
- <https://freesound.org> (filter: CC0)
- <https://opengameart.org> (filter: CC0 / CC-BY)

Convert with:

```sh
ffmpeg -i source.wav -c:a libvorbis -q:a 4 share/sounds/<kind>.ogg
```
