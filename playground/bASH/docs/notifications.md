# Notifications

All desktop notifications go through `notify-send` (lib/notify.bash). Each event has a `POKIDLE_NOTIFY_*` env var (`0` = silent, `1` = notify). Daemon and `pokidle tick ...` both honor them; the `--no-notify` CLI flag overrides to off.

| Event       | Trigger                                    | Default | Env var                      | Urgency  | Sound (file)           | Sound policy            |
|-------------|--------------------------------------------|---------|------------------------------|----------|------------------------|-------------------------|
| pokemon     | wild encounter (`tick pokemon`)            | on      | `POKIDLE_NOTIFY_POKEMON`     | normal   | encounter.ogg          | only `always`           |
| shiny       | shiny encounter (subset of pokemon)        | on      | `POKIDLE_NOTIFY_POKEMON`     | critical\* | shiny.ogg            | `shiny` (default) or `always` |
| legendary   | legendary encounter (`tick legendary`)     | on      | `POKIDLE_NOTIFY_POKEMON`     | critical\*\* | legendary.ogg\*\*\* | `shiny` (default) or `always` |
| item        | held-item drop (`tick item`)               | on      | `POKIDLE_NOTIFY_ITEM`        | low      | item.ogg               | only `always`           |
| biome       | biome rotation (daemon)                    | on      | `POKIDLE_NOTIFY_BIOME`       | low      | biome.ogg              | only `always`           |
| evolve      | evolution (`tick evolve`, per mon)         | on      | `POKIDLE_NOTIFY_EVOLVE`      | normal   | encounter.ogg          | only `always`           |
| level       | +1 level on current-week mon (per mon)     | off     | `POKIDLE_NOTIFY_LEVEL`       | low      | level.ogg              | only `always`           |
| friendship  | +5 friendship on current-week mon (per mon)| off     | `POKIDLE_NOTIFY_FRIENDSHIP`  | low      | friendship.ogg         | only `always`           |

\* Shiny urgency override: `POKIDLE_NOTIFY_URGENCY_SHINY` (default `critical`).
\*\* Legendary urgency override: `POKIDLE_NOTIFY_URGENCY_LEGENDARY` (default `critical`).
\*\*\* Legendary sound falls back `POKIDLE_SOUND_LEGENDARY` → `POKIDLE_SOUND_SHINY` → encounter sound if the file is missing. Like the shiny sound it plays under the default `shiny` policy, but `POKIDLE_SOUND=never` still silences it.

Note: `level` and `friendship` only iterate the **current-week** encounters (`db_list_current_week_encounters`). Older mons are never touched and never notify.

## Global toggles

| Var                      | Default  | Effect                                                      |
|--------------------------|----------|-------------------------------------------------------------|
| `POKIDLE_NO_NOTIFY`      | `0`      | `1` = print title/body to stdout instead of `notify-send`   |
| `POKIDLE_NO_SOUND`       | `0`      | `1` = never play any sound                                  |
| `POKIDLE_SOUND`          | `shiny`  | `never` \| `shiny` (shiny + legendary only) \| `always` (every kind) |
| `POKIDLE_SOUND_ENCOUNTER`| `$POKIDLE_DATA_DIR/sounds/encounter.ogg` | path to encounter sound file  |
| `POKIDLE_SOUND_SHINY`    | `$POKIDLE_DATA_DIR/sounds/shiny.ogg`     | path to shiny sound file      |
| `POKIDLE_SOUND_LEGENDARY`| `$POKIDLE_DATA_DIR/sounds/legendary.ogg` | path to legendary sound file  |
| `POKIDLE_SOUND_ITEM`     | `$POKIDLE_DATA_DIR/sounds/item.ogg`      | path to item sound file       |
| `POKIDLE_SOUND_BIOME`    | `$POKIDLE_DATA_DIR/sounds/biome.ogg`     | path to biome sound file      |
| `POKIDLE_SOUND_LEVEL`    | `$POKIDLE_DATA_DIR/sounds/level.ogg`     | path to level sound file      |
| `POKIDLE_SOUND_FRIENDSHIP`| `$POKIDLE_DATA_DIR/sounds/friendship.ogg` | path to friendship sound file |

Set any `POKIDLE_SOUND_<KIND>` to an empty string to silence that one kind.

## Legendary tick

`tick legendary` fires daily (`POKIDLE_LEGENDARY_INTERVAL=86400`, daemon-driven). Each fire rolls a per-tick chance gated by `POKIDLE_LEGENDARY_CHANCE` (default `3`, i.e. ~3% per day → ~1 spawn per ~33 days on average). Tunable; set to `0` to disable, `100` for guaranteed spawn (useful for testing). Spawns appear under the active biome session; the species is picked at random from the legendaries in the hardcoded `LEGENDARY_TYPES` roster (`lib/legendary.bash`) whose types intersect the active biome's types.
