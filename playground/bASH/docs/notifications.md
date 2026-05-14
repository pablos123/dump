# Notifications

All desktop notifications go through `notify-send` (lib/notify.bash). Each event has a `POKIDLE_NOTIFY_*` env var (`0` = silent, `1` = notify). Daemon and `pokidle tick ...` both honor them; the `--no-notify` CLI flag overrides to off.

| Event       | Trigger                                    | Default | Env var                      | Urgency  | Sound          |
|-------------|--------------------------------------------|---------|------------------------------|----------|----------------|
| pokemon     | wild encounter (`tick pokemon`)            | on      | `POKIDLE_NOTIFY_POKEMON`     | normal   | encounter\*    |
| shiny       | shiny encounter (subset of pokemon)        | on      | `POKIDLE_NOTIFY_POKEMON`     | critical\*\* | shiny       |
| legendary   | legendary encounter (`tick legendary`)     | on      | `POKIDLE_NOTIFY_POKEMON`     | critical\*\*\* | legendary\*\*\*\* |
| item        | held-item drop (`tick item`)               | on      | `POKIDLE_NOTIFY_ITEM`        | low      | —              |
| biome       | biome rotation (daemon)                    | on      | `POKIDLE_NOTIFY_BIOME`       | low      | —              |
| evolve      | evolution (`tick evolve`, per mon)         | on      | `POKIDLE_NOTIFY_EVOLVE`      | normal   | encounter      |
| level       | +1 level on current-week mon (per mon)     | off     | `POKIDLE_NOTIFY_LEVEL`       | low      | —              |
| friendship  | +5 friendship on current-week mon (per mon)| off     | `POKIDLE_NOTIFY_FRIENDSHIP`  | low      | —              |

\* Encounter sound only plays when `POKIDLE_SOUND=always`.
\*\* Shiny urgency override: `POKIDLE_NOTIFY_URGENCY_SHINY` (default `critical`).
\*\*\* Legendary urgency override: `POKIDLE_NOTIFY_URGENCY_LEGENDARY` (default `critical`).
\*\*\*\* Legendary sound plays unconditionally (ignores `POKIDLE_SOUND` policy). Override path: `POKIDLE_SOUND_LEGENDARY`. Falls back to `POKIDLE_SOUND_SHINY` then encounter sound if the file is missing.

Note: `level` and `friendship` only iterate the **current-week** encounters (`db_list_current_week_encounters`). Older mons are never touched and never notify.

## Global toggles

| Var                      | Default  | Effect                                                      |
|--------------------------|----------|-------------------------------------------------------------|
| `POKIDLE_NO_NOTIFY`      | `0`      | `1` = print title/body to stdout instead of `notify-send`   |
| `POKIDLE_NO_SOUND`       | `0`      | `1` = never play any sound                                  |
| `POKIDLE_SOUND`          | `shiny`  | `never` \| `shiny` (only shinies) \| `always`               |
| `POKIDLE_SOUND_ENCOUNTER`| share/sounds/encounter.ogg | path to encounter sound file              |
| `POKIDLE_SOUND_SHINY`    | share/sounds/shiny.ogg     | path to shiny sound file                  |
| `POKIDLE_SOUND_LEGENDARY`| share/sounds/legendary.ogg | path to legendary sound file              |

## Legendary tick

`tick legendary` fires daily (`POKIDLE_LEGENDARY_INTERVAL=86400`, daemon-driven). Each fire rolls a per-tick chance gated by `POKIDLE_LEGENDARY_CHANCE` (default `3`, i.e. ~3% per day → ~1 spawn per ~33 days on average). Tunable; set to `0` to disable, `100` for guaranteed spawn (useful for testing). Spawns appear under the active biome session; the species is picked uniformly from the hardcoded `LEGENDARY_SPECIES` roster in `lib/legendary.bash`.
