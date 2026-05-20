# Configuration

Every knob is an environment variable. The daemon reads them from its
environment, so set them in the systemd unit (`Environment=...` in
`~/.config/systemd/user/pokidle.service`, or via
`systemctl --user edit pokidle.service`) and run
`systemctl --user daemon-reload && systemctl --user restart pokidle.service`.
For one-off CLI runs, prefix the command: `POKIDLE_SHINY_RATE=8 pokidle tick pokemon`.

Notification and sound variables are covered in
[notifications.md](notifications.md); they are cross-referenced but not
repeated in full here.

## Paths

All paths follow the XDG Base Directory spec.

| Variable | Default | Purpose |
|----------|---------|---------|
| `POKIDLE_CONFIG_DIR` | `$XDG_CONFIG_HOME/pokidle` (`~/.config/pokidle`) | Holds `biomes.json`. |
| `POKIDLE_DATA_DIR` | `$XDG_DATA_HOME/pokidle` (`~/.local/share/pokidle`) | Holds the SQLite DB and the asset symlinks (`biomes/`, `notify/`, `sounds/`). |
| `POKIDLE_CACHE_DIR` | `$XDG_CACHE_HOME/pokidle` (`~/.cache/pokidle`) | Encounter pools (`pools/`) and downloaded sprites (`sprites/`). |
| `POKIDLE_DB_PATH` | `$POKIDLE_DATA_DIR/pokidle.db` | SQLite database file. |

PokeAPI client (shared with the standalone `pokeapi` CLI):

| Variable | Default | Purpose |
|----------|---------|---------|
| `POKEAPI_CACHE_DIR` | `$XDG_CACHE_HOME/pokeapi` | On-disk cache of raw PokeAPI JSON responses. |
| `POKEAPI_BASE_URL` | `https://pokeapi.co/api/v2` | API base URL. Point at a mirror or local cache if desired. |
| `POKEAPI_USER_AGENT` | `pokeapi-bash/0.1` | `User-Agent` header sent with every request. |
| `POKEAPI_RATE_LIMIT_SLEEP` | `0.5` | Seconds to sleep after each live fetch (cache misses only). Falls back to `POKIDLE_RATE_LIMIT_SLEEP` if that is set. |
| `POKIDLE_RATE_LIMIT_SLEEP` | unset | Alias source for `POKEAPI_RATE_LIMIT_SLEEP`. |

## Tick cadence

Each event kind has its own interval in **seconds**. The daemon fires a kind
when its timer elapses; intervals get a small random jitter within the next
clock hour.

| Variable | Default | Event |
|----------|---------|-------|
| `POKIDLE_POKEMON_INTERVAL` | `3600` (1 h) | Wild Pokemon encounter. |
| `POKIDLE_ITEM_INTERVAL` | `3600` (1 h) | Held-item drop. |
| `POKIDLE_LEVEL_INTERVAL` | `3600` (1 h) | Level-up pass over current-week catches. |
| `POKIDLE_FRIENDSHIP_INTERVAL` | `1800` (30 min) | Friendship pass over current-week catches. |
| `POKIDLE_EVOLVE_INTERVAL` | `10800` (3 h) | Evolution pass over current-week catches. |
| `POKIDLE_LEGENDARY_INTERVAL` | `86400` (24 h) | Legendary spawn roll. |
| `POKIDLE_BIOME_HOURS` | `3` | Hours before the active biome rotates to a new one. |

`POKIDLE_TICK_FAST=1` switches the scheduler to a cadence-based mode (next
target in `[now, now + interval)`) for smoke tests like
`timeout 200 ./pokidle daemon`. Leave it unset in normal use.

## Odds and rolls

| Variable | Default | Meaning |
|----------|---------|---------|
| `POKIDLE_SHINY_RATE` | `1024` | Shiny odds are `1 / N`. Lower = more shinies. |
| `POKIDLE_BERRY_RATE` | `15` | Percent chance an encounter holds a berry (`0`–`100`). |
| `POKIDLE_HIDDEN_ABILITY_RATE` | `5` | Percent chance an encounter rolls its hidden ability. |

Per-tick level and friendship gains are fixed in code (each eligible
current-week catch has a 25% chance of `+1` level and a 50% chance of `+5`
friendship). They are not env-tunable.

## Evolution

| Variable | Default | Meaning |
|----------|---------|---------|
| `POKIDLE_EVOLVE_ENABLED` | `1` | `0` disables the evolution tick entirely. |

Evolution chance is tier-derived (common 25%, uncommon 15%, rare 8%,
very_rare 3%) and not env-tunable. Item-based evolutions require a matching
item to exist in `item_drops`, which is consumed on use.

## Legendaries

| Variable | Default | Meaning |
|----------|---------|---------|
| `POKIDLE_LEGENDARY_ENABLED` | `1` | `0` disables the legendary tick. |
| `POKIDLE_LEGENDARY_CHANCE` | `3` | Percent chance per legendary tick (daily) that one spawns. `0` = never, `100` = guaranteed (testing). |
| `POKIDLE_LEGENDARY_LEVEL_MIN` | `50` | Lower bound of legendary spawn level. |
| `POKIDLE_LEGENDARY_LEVEL_MAX` | `70` | Upper bound of legendary spawn level. |

The species is chosen at random among legendaries whose types intersect the
active biome's types (roster: `LEGENDARY_TYPES` in `lib/legendary.bash`).

## Display

| Variable | Default | Meaning |
|----------|---------|---------|
| `POKIDLE_IMG_WIDTH` | `16` | Sprite width (terminal cells) for `chafa` previews in `list` / `items`. chafa auto-selects kitty/sixel/iterm for pixel-perfect output, or symbol cells as fallback. No-op if `chafa` is not installed. |

## Notifications and sound

Toggles per event (`POKIDLE_NOTIFY_POKEMON`, `_ITEM`, `_BIOME`, `_EVOLVE`,
`_LEVEL`, `_FRIENDSHIP`), urgency overrides
(`POKIDLE_NOTIFY_URGENCY_SHINY`, `_LEGENDARY`), global gates
(`POKIDLE_NO_NOTIFY`, `POKIDLE_NO_SOUND`), the sound policy
(`POKIDLE_SOUND`), and per-kind sound paths (`POKIDLE_SOUND_<KIND>`) are
documented in full in [notifications.md](notifications.md).

## Internal / test-only

Not for normal use; set by the script or the test harness.

| Variable | Purpose |
|----------|---------|
| `POKIDLE_REPO_ROOT` | Repo root, derived from the script path at startup. |
| `POKIDLE_TICK_FAST` | Smoke-test scheduler mode (see Tick cadence). |
| `POKIDLE_TEST_SOURCE_ONLY` | When `1`, sourcing `pokidle` defines functions without dispatching a command. |
| `POKIDLE_TEST_SKIP_DISPATCH` | When `1`, skips the bottom-of-file command dispatch. |
