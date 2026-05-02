# pokidle — passive Pokémon encounter daemon

**Status:** spec, awaiting plan
**Date:** 2026-05-02

## Summary

`pokidle` is a Bash systemd-user daemon that simulates a passive idle Pokémon-encounter game. It rotates through biomes every 3 hours, generating one Pokémon encounter and one held-item drop per hour. Encounters carry full battle data (level, IVs, EVs, nature, ability, moves, gender, shiny, optional held berry), are stored in SQLite, and surface as desktop notifications via `notify-send` with cached PokeAPI sprites as icons. A `pokidle list` CLI prints history with inline sprites (`catimg`) and can emit Pokémon Showdown set text via `--export`.

The project lives in the existing `bASH` repository alongside the generic `pokeapi` library wrapper, sharing its `lib/cache.bash`, `lib/http.bash`, and `lib/api.bash` for cached HTTP access.

## Goals

- Non-intrusive passive game that runs in the background as a `systemd --user` service.
- Per-encounter Pokémon data is rich enough to import directly into Pokémon Showdown.
- All encounter data persisted to SQLite for history and export.
- Encounter pool driven entirely by canonical PokeAPI `/location-area` data, expanded along evolution chains.
- Configuration via JSON (`biomes.json`) and environment variables — no hardcoded behavior beyond defaults.
- Stays polite to PokeAPI: 0.5 s sleep after every live fetch, aggressive filesystem caching.

## Non-goals

- No battle simulation, no XP, no party management.
- No competitive viability checks (any combination of moves/abilities is allowed; Showdown will validate on import).
- No internationalization (English-only labels for now).
- No GUI, no TUI app — only desktop notifications and CLI.
- No multi-user or networked play.

## Architecture overview

```
┌──────────────────────────────────────────────────────────────┐
│                       pokidle (entry)                        │
│   modes: daemon | tick | list | items | stats | current |    │
│          rebuild-pool | rebuild-biomes | clean | setup |     │
│          uninstall | status | help                           │
└──────────────────────────────┬───────────────────────────────┘
                               │
   ┌───────────────┬───────────┼─────────────┬────────────┐
┌──▼───┐    ┌──────▼─────┐ ┌───▼──────┐ ┌────▼─────┐ ┌────▼────┐
│biome │    │ encounter  │ │   db     │ │ notify   │ │showdown │
│rotate│    │pool build  │ │sqlite    │ │notify-   │ │set text │
│config│    │evo expand  │ │schema    │ │send      │ │export   │
│class.│    │stats gen   │ │CRUD      │ │sprite ico│ │         │
└──────┘    └──────┬─────┘ └──────────┘ └──────────┘ └─────────┘
                   │
            ┌──────▼──────────┐
            │   pokeapi lib   │  (existing: cache/http/api)
            │ + 0.5s rate-lim │
            └─────────────────┘
```

### Daemon control flow

```
pokidle daemon start
  ├─ load config (biomes.json, env)
  ├─ init_db (apply schema if missing)
  ├─ resume state (current biome session) from db
  └─ loop:
      ├─ if (now - biome_started_at) ≥ 3h:
      │    ├─ close current biome session
      │    ├─ pick new biome (random, ≠ current)
      │    ├─ open new biome session
      │    └─ notify-send "biome changed → <name>"
      ├─ schedule next pokemon tick at hour_start + rand(0,3600)
      ├─ schedule next item tick at hour_start + rand(0,3600)
      ├─ on pokemon tick: roll → save → notify
      ├─ on item tick: roll → save → notify
      └─ sleep until next event
```

### Per-encounter data flow

```
biome → cached pool (json) → roll species (weighted %) →
  fetch /pokemon + /pokemon-species + /evolution-chain (cached) →
  level (uniform min..max) → IVs random → EVs random ≤510 cap252 →
  nature random → ability (95% normal / 5% hidden) →
  4 moves random from ≤level union pool →
  gender from species.gender_rate → shiny roll (1/N) →
  held berry roll (15% × biome.berry_pool) →
  insert encounters row + notify-send w/ sprite icon
```

## Biome system

### Config file

`config/biomes.json` ships with the repo as the template; `pokidle setup` copies it to `${POKIDLE_CONFIG_DIR:-$XDG_CONFIG_HOME/pokidle}/biomes.json`. Format:

```json
{
  "biomes": [
    {
      "id": "cave",
      "label": "Cave",
      "name_regex": "(?i)cave|cavern|grotto|tunnel|mine",
      "type_affinity": ["rock", "ground", "dark"],
      "berry_pool": ["rawst", "aspear", "chesto"],
      "item_pool":  ["everstone", "hard-stone", "smoke-ball"]
    }
  ],
  "fallback_biome": "wild"
}
```

### Initial biome list (18)

| id | label | name_regex hints | type affinity |
|---|---|---|---|
| cave | Cave | cave, cavern, grotto, tunnel, mine | rock, ground, dark |
| desert | Desert | desert, dunes, sand | ground, fire |
| forest | Forest | forest, woods, jungle | grass, bug |
| mountain | Mountain | mt-, mountain, peak, summit | rock, ice, flying |
| volcano | Volcano | volcano, crater, magma, lava | fire, rock |
| plain | Plain | route-\d+, meadow, field, plains | normal, flying, grass |
| savanna | Savanna | savanna, savannah | normal, fire, ground |
| safari | Safari | safari | (rare/exotic mons) |
| water | Water | lake, sea, ocean, beach, shore, bay | water |
| swamp | Swamp | swamp, marsh, bog, mire | grass, poison, water |
| ice | Ice | ice, frozen, snow, glacier, frost | ice |
| ruins | Ruins | ruins, tomb, tower, chamber | ghost, psychic, rock |
| urban | Urban | city, town, gym | normal, electric, steel |
| sky | Sky | sky, cloud, bell-tower-roof | flying, dragon |
| power-plant | Power Plant | power, plant, reactor, lab | electric, steel |
| graveyard | Graveyard | grave, cemetery, lost-tower | ghost |
| farm | Farm | (no canon match — manual area list or empty) | grass, normal |
| wild | Wild (fallback) | (catches everything else) | (any) |

### Classifier algorithm

Run once (or on `pokidle rebuild-biomes`) to assign every PokeAPI `/location-area` to one biome. Output cached at `${POKIDLE_CACHE_DIR}/biome-areas/<biome>.json`.

```
for each /location-area in PokeAPI:
  area_name = area.name
  area_types = union of types of all pokemon listed in area.pokemon_encounters
  best_biome = null
  best_score = 0
  for each biome in config:
    score = 0
    if biome.name_regex matches area_name: score += 10
    score += |biome.type_affinity ∩ area_types|       # type overlap count
    if score > best_score:
      best_biome = biome
      best_score = score
  assign area → best_biome (or fallback if score == 0)
```

### Berry & held-item distribution

- All ~64 PokeAPI berries assigned across the 18 biomes, themed by lore (status-cure berries → cave, fire-resist → volcano, etc.). Every berry lives in ≥1 biome's `berry_pool`.
- Held-items (PokeAPI `attribute=holdable` minus berries, ~150 items) similarly distributed across biome `item_pool` lists. Every item lives in ≥1 biome.
- Author-curated and shipped as `config/biomes.json`. End user may edit post-install.
- Validation at config load: any item in a `berry_pool` must be category `berries`; any item in an `item_pool` must have `attribute=holdable` and **not** be a berry. Invalid entries logged as warnings, ignored at runtime.

## Encounter pool build

Pool is built lazily on first encounter in a biome and cached at `${POKIDLE_CACHE_DIR}/pools/<biome>.json`. Auto-rebuilds when `biomes.json` mtime > pool mtime. Manual rebuild: `pokidle rebuild-pool [biome]`.

### Algorithm

```
build_pool(biome):
  areas = read cache/biome-areas/<biome>.json
  raw_entries = []   # (species, min_lvl, max_lvl, chance_pct)

  for area_name in areas:
    area = pokeapi_get "location-area/<area_name>"        # cached, +0.5s sleep on live
    for pe in area.pokemon_encounters:
      species = pe.pokemon.name
      for vd in pe.version_details:
        version = vd.version.name
        if POKIDLE_GEN set and gen_of(version) ∉ POKIDLE_GEN: continue
        for ed in vd.encounter_details:
          # method union — every method kept, weighted by its native chance
          raw_entries += (species, ed.min_level, ed.max_level, ed.chance)

  # collapse duplicates per species
  base = collapse_by_species(raw_entries)
    # min = min(all mins), max = max(all maxes), chance = sum(chances)

  # evo-line expansion with halving %
  expanded = []
  for (species, min_lvl, max_lvl, pct) in base:
    delta = max_lvl - min_lvl
    chain = pokeapi_get "evolution-chain/<id>"            # via /pokemon-species
    stages = walk_chain(chain)                            # BFS, root stage_idx=0
    for (stage_idx, mon, evo_details, parent_max) in stages:
      if stage_idx == 0:
        e_min, e_max = min_lvl, max_lvl
      else:
        if evo_details.min_level is set:
          e_min = evo_details.min_level
        else:
          e_min = parent_max + 10                         # non-level evo offset
        e_max = e_min + delta
      e_pct = pct / (2 ** stage_idx)                      # halving rule
      expanded += (mon, e_min, e_max, e_pct)

  # renormalize whole pool to 100%
  total = sum(e.pct for e in expanded)
  for e in expanded: e.pct = e.pct * 100 / total

  write cache/pools/<biome>.json
```

### Edge cases

- **`gen_of(version)`**: static map covering all 9 generations and their version-groups.
- **Evolution branches** (Eevee, Gloom→Vileplume/Bellossom, etc.): every branch child sits at `stage_idx = parent_stage + 1` and is halved equally; multiple siblings split from the same parent each get the same percentage.
- **Stage indexing**: BFS over `evolution_chain.chain.evolves_to[]`, root = 0.
- **Method weighting**: methods kept as-is; their per-method `chance` field is used directly. Surf/fish methods naturally surface only on water-tagged areas because PokeAPI lists them only there.
- **Cache invalidation**: `pokidle clean` purges all caches (HTTP + pool + biome-areas + sprites). Confirmation prompt unless `--yes`.

### Pool storage format

```json
{
  "biome": "cave",
  "built_at": "2026-05-02T12:34:56Z",
  "gen_filter": ["1","3"],
  "entries": [
    {"species":"zubat","min":5,"max":8,"pct":18.4},
    {"species":"golbat","min":22,"max":25,"pct":9.2}
  ]
}
```

## Pokémon roll

### Pool entry selection

```
roll_pool_entry(biome):
  pool = read cache/pools/<biome>.json
  r = rand_float(0, 100)
  cum = 0
  for e in pool.entries:
    cum += e.pct
    if r <= cum: return e
  return pool.entries[-1]    # rounding fallback
```

### Encounter generation

```
roll_pokemon(entry):
  level = randint(entry.min_lvl, entry.max_lvl)        # uniform inclusive

  poke = pokeapi_get "pokemon/<species>"
  spec = pokeapi_get "pokemon-species/<species>"

  # IVs
  ivs = {hp,atk,def,spa,spd,spe: randint(0,31) each}

  # EVs: total T uniform [0,510], distribute across 6 stats capped 252 each
  evs = ev_split(randint(0,510))

  # Nature
  nature = random_pick(natures_list)                   # cached from /nature?limit=100

  # Ability
  abilities = poke.abilities
  hidden = [a for a in abilities if a.is_hidden]
  normal = [a for a in abilities if not a.is_hidden]
  hidden_rate = env POKIDLE_HIDDEN_ABILITY_RATE default 5
  if rand_pct() < hidden_rate and hidden: ability = random_pick(hidden)
  else:                                   ability = random_pick(normal)

  # Moves: 4 random from union ≤ level
  candidates = []
  for m in poke.moves:
    for vgd in m.version_group_details:
      if vgd.move_learn_method.name in {"level-up","machine","egg","tutor"}
         and vgd.level_learned_at <= level:
        candidates += m.move.name; break
  candidates = unique(candidates)
  moves = random_pick_n(candidates, min(4, len(candidates)))

  # Gender from gender_rate (0..8 = female-out-of-8; -1 = genderless)
  gr = spec.gender_rate
  if gr == -1: gender = "genderless"
  elif rand() < gr/8: gender = "F"
  else:               gender = "M"

  # Shiny
  shiny_rate = env POKIDLE_SHINY_RATE default 1024
  shiny = (randint(1, shiny_rate) == 1)

  # Held berry
  berry_rate = env POKIDLE_BERRY_RATE default 15        # percent
  if rand_pct() < berry_rate and biome.berry_pool not empty:
    held = random_pick(biome.berry_pool)
  else:
    held = null

  # Final stats
  stats = compute_stats(poke.stats, level, ivs, evs, nature)

  return Encounter(...)
```

### EV split

```
ev_split(T):
  evs = [0]*6
  remaining = T
  while remaining > 0:
    i = randint(0,5)
    if evs[i] >= 252: continue
    delta = min(remaining, randint(1, 252 - evs[i]))
    evs[i] += delta
    remaining -= delta
    if all evs[i] == 252: break
  return evs
```

### Stat formulas (gen 3+)

```
HP    = floor(((2*B + IV + floor(EV/4)) * level)/100) + level + 10
other = floor((floor(((2*B + IV + floor(EV/4)) * level)/100) + 5) * nature_mod)
nature_mod ∈ {0.9, 1.0, 1.1}
```

`nature_mod` resolved from PokeAPI `/nature/<name>` (`increased_stat`/`decreased_stat`). Bashful/Docile/Hardy/Quirky/Serious have no modifier (1.0 across the board).

## Item roll

```
roll_item(biome):
  pool = biome.item_pool
  if empty: fallback to wild biome's item_pool; if still empty, skip
  name = random_pick(pool)                             # flat random
  it = pokeapi_get "item/<name>"
  sprite_url = it.sprites.default                      # may be null
  sprite_path = download_if_missing(sprite_url)        # cache/sprites/items/<name>.png
  return Item(name, sprite_path, biome, ts=now)
```

Singleton drop. No stacking. If `sprites.default` is null, notification omits icon.

## Persistence

### Path

`${POKIDLE_DB_PATH:-$XDG_DATA_HOME/pokidle/pokidle.db}` (default `~/.local/share/pokidle/pokidle.db`).

### Schema

`schema.sql` applied via `CREATE TABLE IF NOT EXISTS` on daemon start. Schema version tracked in `daemon_state` for future migrations.

```sql
CREATE TABLE IF NOT EXISTS biome_sessions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    biome_id        TEXT NOT NULL,
    started_at      INTEGER NOT NULL,
    ended_at        INTEGER
);
CREATE INDEX IF NOT EXISTS idx_biome_sessions_active
    ON biome_sessions(ended_at) WHERE ended_at IS NULL;

CREATE TABLE IF NOT EXISTS encounters (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      INTEGER NOT NULL REFERENCES biome_sessions(id),
    encountered_at  INTEGER NOT NULL,
    species         TEXT NOT NULL,
    dex_id          INTEGER NOT NULL,
    level           INTEGER NOT NULL,
    nature          TEXT NOT NULL,
    ability         TEXT NOT NULL,
    is_hidden_ability INTEGER NOT NULL,
    gender          TEXT NOT NULL,
    shiny           INTEGER NOT NULL,
    held_berry      TEXT,
    iv_hp INTEGER, iv_atk INTEGER, iv_def INTEGER,
    iv_spa INTEGER, iv_spd INTEGER, iv_spe INTEGER,
    ev_hp INTEGER, ev_atk INTEGER, ev_def INTEGER,
    ev_spa INTEGER, ev_spd INTEGER, ev_spe INTEGER,
    stat_hp INTEGER, stat_atk INTEGER, stat_def INTEGER,
    stat_spa INTEGER, stat_spd INTEGER, stat_spe INTEGER,
    moves_json      TEXT NOT NULL,
    sprite_path     TEXT
);
CREATE INDEX IF NOT EXISTS idx_enc_session ON encounters(session_id);
CREATE INDEX IF NOT EXISTS idx_enc_shiny   ON encounters(shiny) WHERE shiny=1;
CREATE INDEX IF NOT EXISTS idx_enc_species ON encounters(species);
CREATE INDEX IF NOT EXISTS idx_enc_time    ON encounters(encountered_at);

CREATE TABLE IF NOT EXISTS item_drops (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      INTEGER NOT NULL REFERENCES biome_sessions(id),
    encountered_at  INTEGER NOT NULL,
    item            TEXT NOT NULL,
    sprite_path     TEXT
);
CREATE INDEX IF NOT EXISTS idx_item_session ON item_drops(session_id);
CREATE INDEX IF NOT EXISTS idx_item_time    ON item_drops(encountered_at);

CREATE TABLE IF NOT EXISTS daemon_state (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- e.g. ('schema_version','1'), ('last_pokemon_tick','...'), ('last_item_tick','...')
```

### Access pattern (`lib/db.bash`)

```bash
db_exec        "<sql>"        # DDL/INSERT/UPDATE
db_query       "<sql>"        # SELECT, tab-separated rows
db_query_json  "<sql>"        # JSON array via sqlite3 -json
```

Each call spawns a fresh `sqlite3` process. No long-lived connection. SQLite's auto-commit handles transactions per statement.

### Resume on daemon start

1. Read open `biome_session` (`ended_at IS NULL`).
   - If `(now - started_at) ≥ 3h`: close it, pick new biome, open new session.
   - Else: keep current session.
2. Read `daemon_state.last_pokemon_tick_target` / `last_item_tick_target`.
3. If a target is in the past, treat it as already fired (do not double-fire on restart). Schedule next tick.

## Notifications

### Backend

`notify-send` (libnotify) — hard runtime requirement.

### Pokémon encounter

```
title:   [SHINY ✨] Lv.42 Sceptile           (or  Lv.42 Sceptile)
body:    Cave  ·  Adamant  ·  Overgrow
         HP 142  Atk 198  Def 95  SpA 129  SpD 95  Spe 152
         Moves: leaf-blade, dragon-claw, earthquake, x-scissor
         Held: sitrus-berry                  (line omitted if no berry)
icon:    <cache>/sprites/<species>-front_default.png
            OR <cache>/sprites/<species>-front_shiny.png if shiny
urgency: normal (critical if shiny — overridable via POKIDLE_NOTIFY_URGENCY_SHINY)
hint:    string:desktop-entry:pokidle
```

### Item drop

```
title:   Found Soothe Bell
body:    Cave  ·  held-item
icon:    <cache>/sprites/items/soothe-bell.png  (omit if null)
urgency: low
```

### Biome change

```
title:   Biome changed → Volcano
body:    Encounters: <pool_size> species, <item_count> items
icon:    (none for now — future PNG set)
urgency: low
```

### Sound

- `POKIDLE_SOUND` ∈ `{shiny, always, never}`, default `shiny`.
- Played via `paplay` (PulseAudio) or `aplay` (ALSA), auto-detected: `command -v paplay || command -v aplay`.
- Bundled files at `share/sounds/encounter.ogg` and `share/sounds/shiny.ogg`. Override paths via `POKIDLE_SOUND_ENCOUNTER` / `POKIDLE_SOUND_SHINY`. Resolution order: env var → `${POKIDLE_DATA_DIR}/sounds/<name>.ogg` → repo `share/sounds/<name>.ogg`.

### Failure handling

`notify-send` non-zero exit is logged to journal but never aborts the daemon. Encounter is already persisted before notification is attempted.

## CLI

```
pokidle daemon                    Run main loop (used by systemd unit)
pokidle tick [pokemon|item]       Force a single roll now
    --dry-run                     Skip DB write (notification + stdout still fire)
    --no-notify                   Skip notify-send
    --json                        Emit JSON to stdout instead of pretty
pokidle list [filters]            History of pokemon encounters
pokidle items [filters]           History of item drops
pokidle stats                     Aggregate stats (totals, shinies, by biome, top species)
pokidle current                   Current biome + time-remaining + counts
pokidle rebuild-pool [biome]      Force pool rebuild (one or all)
pokidle rebuild-biomes            Re-run classifier on all /location-area
pokidle clean                     Purge http cache + pools (interactive confirm; --yes to skip)
pokidle setup [--enable]          Install user systemd unit + config dirs
pokidle uninstall                 Disable + remove unit (DB/cache untouched)
pokidle status                    systemctl status + last tick + current biome
pokidle help | -h | --help
```

### `list` / `items` filters

```
--shiny                Only shinies (list only)
--since <YYYY-MM-DD>   Encountered on/after date
--until <YYYY-MM-DD>   Encountered on/before date
--biome <id>           Filter by biome id
--species <name>       Filter by species name (substring match) (list only)
--item <name>          Filter by item name (substring match) (items only)
--nature <name>        Filter by nature (list only)
--min-iv-total <N>     Filter where sum(IVs) ≥ N (list only)
--limit <N>            Cap result count (default $POKIDLE_LIST_LIMIT, fallback 50)
--export               Emit Pokémon Showdown set text (list only)
--json                 Emit raw JSON array
```

### Pretty `list` output

```
┌────────────────────────────────────────────────────────────────┐
│ #1734  2026-05-01 14:23   Cave                                 │
│  <catimg sprite>   Lv.42 Sceptile ✨                            │
│                    Adamant · Overgrow · ♂                       │
│                    Stats:  142 / 198 / 95 / 129 / 95 / 152      │
│                    IVs:     31 / 28 /  19 / 31 / 24 / 30        │
│                    EVs:    252 /   0 /   0 /   6 / 0 / 252      │
│                    Moves: leaf-blade, dragon-claw, eq, x-scissor│
│                    Held:   sitrus-berry                         │
└────────────────────────────────────────────────────────────────┘
```

`catimg <sprite_path> -w $POKIDLE_CATIMG_WIDTH` rendered inline. If `catimg` is missing, the sprite line is omitted (text fallback). Detected once at startup.

### Showdown export (`list --export`)

```
Sceptile @ Sitrus Berry
Ability: Overgrow
Level: 42
Shiny: Yes
Adamant Nature
EVs: 252 HP / 6 SpA / 252 Spe
IVs: 31 HP / 28 Atk / 19 Def / 31 SpA / 24 SpD / 30 Spe
- Leaf Blade
- Dragon Claw
- Earthquake
- X-Scissor
```

Multiple sets separated by a blank line. `Shiny: Yes` only if shiny. `EVs:` line omits zero stats; `IVs:` line is always full. Item line uses `@ <Title-Cased Item>` only if `held_berry` non-null.

## Daemon + systemd

### Daemon loop sketch

```bash
main_loop() {
    trap 'graceful_shutdown' INT TERM
    init_db
    biome="$(load_or_pick_biome)"
    schedule_next_pokemon_tick
    schedule_next_item_tick

    while :; do
        now=$(date +%s)
        if (( now - biome_started_at >= POKIDLE_BIOME_HOURS * 3600 )); then
            close_biome_session
            biome="$(pick_new_biome "$biome")"
            open_biome_session "$biome"
            notify_biome_change "$biome"
        fi
        if (( now >= next_pokemon_tick )); then
            entry="$(roll_pool_entry "$biome")"
            enc="$(roll_pokemon "$entry")"
            insert_encounter "$enc"
            notify_pokemon "$enc"
            schedule_next_pokemon_tick
        fi
        if (( now >= next_item_tick )); then
            item="$(roll_item "$biome")"
            insert_item "$item"
            notify_item "$item"
            schedule_next_item_tick
        fi
        sleep_until_next_event
    done
}

schedule_next_pokemon_tick() {
    local next_hour=$(( (now / 3600 + 1) * 3600 ))
    next_pokemon_tick=$(( next_hour + RANDOM % POKIDLE_POKEMON_INTERVAL ))
    db_set last_pokemon_tick_target "$next_pokemon_tick"
}
```

### systemd user unit

`~/.config/systemd/user/pokidle.service`:

```ini
[Unit]
Description=Pokidle passive pokemon encounter daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/pokidle daemon
Restart=on-failure
RestartSec=30
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
```

Installed by `pokidle setup`. Enabled by `pokidle setup --enable` or:

```
systemctl --user daemon-reload
systemctl --user enable --now pokidle.service
```

### Non-intrusive guarantees

- All notifications use `urgency=normal` or `low`; only shinies use `critical`.
- No focus-stealing (`notify-send` is non-focusing by design).
- Daemon sleeps between events (single `sleep` call to next tick), not a poll loop.
- HTTP rate-limited to 0.5 s after every live (cache-miss) fetch.

## Project layout

```
.
├── pokeapi                  # renamed from pokeapi.bash — generic API CLI
├── pokidle                  # NEW — game entry script (subcommand dispatcher)
├── lib/
│   ├── cache.bash           # existing
│   ├── http.bash            # existing — adds 0.5s post-fetch sleep
│   ├── api.bash             # existing — natures helpers already added
│   ├── biome.bash           # NEW — config load, classifier, biome rotation
│   ├── encounter.bash       # NEW — pool build, evo expand, pokemon/item rolls, stats
│   ├── db.bash              # NEW — sqlite wrappers, schema init, CRUD
│   ├── notify.bash          # NEW — notify-send + sound
│   └── showdown.bash        # NEW — Showdown set text formatter
├── config/
│   └── biomes.json          # NEW — 18 biomes, regex, type affinity, berry/item pools
├── share/
│   └── sounds/
│       ├── encounter.ogg
│       └── shiny.ogg
├── systemd/
│   └── pokidle.service      # template installed to ~/.config/systemd/user/
├── schema.sql               # NEW — sqlite schema applied on init_db
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-05-02-pokidle-design.md
```

## Dependencies

Runtime: `bash ≥4`, `curl`, `jq`, `sqlite3`, `libnotify-bin` (`notify-send`), `coreutils`.
Optional: `catimg` (sprite rendering in `list` output), `paplay` (PulseAudio) or `aplay` (ALSA).
Test: `bats-core` (or plain assertions).

## Error handling

- **API fetch fails**: log to journal at `warn`, skip this tick. Next tick retries.
- **DB write fails**: log at `error` + `notify-send -u critical "DB error"`. Daemon continues. Flag persisted in `daemon_state.last_db_error`.
- **Config invalid (biomes.json malformed)**: fail-fast at startup with clear message and non-zero exit.
- **Cache corruption (jq parse error)**: delete the offending cache file and refetch. Log at `info`.
- **Pool empty after build (biome has no areas)**: log at `warn`, fall through to fallback biome's pool for the encounter, then notify normally.

## Testing

- **Unit-style** (`tests/test-*.bash`, bats-core or plain `set -e` scripts):
  - Pool build with canned `/location-area` JSON fixtures.
  - Evo expansion math (linear chains, branches like Eevee, non-level evos).
  - EV split bounds (`sum ≤ 510`, `each ≤ 252`, total distribution coverage).
  - Stat formula vs known-good values (e.g. lvl-100 Garchomp with 31 IVs / 252 Atk / Adamant).
  - Nature lookup + modifier resolution.
  - Gender roll distribution (statistical, e.g. 1000 rolls of 7/8 species, expect ≈87.5% F).
  - Shiny roll under fixed seed.
- **Integration**: `pokidle tick pokemon --dry-run --no-notify --json` end-to-end against real cache; assert valid JSON and required keys.
- **DB**: `POKIDLE_DB_PATH=:memory:` for tests.

## Environment-variable matrix

| Variable | Default | Purpose |
|---|---|---|
| `POKIDLE_GEN` | (all) | CSV generation filter, e.g. `1,3,5` |
| `POKIDLE_SHINY_RATE` | `1024` | 1/N shiny odds |
| `POKIDLE_BERRY_RATE` | `15` | % chance pokemon holds berry |
| `POKIDLE_HIDDEN_ABILITY_RATE` | `5` | % chance ability rolls hidden |
| `POKIDLE_BIOME_HOURS` | `3` | Hours per biome window |
| `POKIDLE_POKEMON_INTERVAL` | `3600` | Seconds between pokemon ticks (offset random within) |
| `POKIDLE_ITEM_INTERVAL` | `3600` | Seconds between item ticks |
| `POKIDLE_SOUND` | `shiny` | `shiny` / `always` / `never` |
| `POKIDLE_SOUND_ENCOUNTER` | (bundled) | Override encounter sound path |
| `POKIDLE_SOUND_SHINY` | (bundled) | Override shiny sound path |
| `POKIDLE_NO_NOTIFY` | `0` | Skip `notify-send` (testing) |
| `POKIDLE_NO_SOUND` | `0` | Skip sound regardless of policy |
| `POKIDLE_NOTIFY_URGENCY_SHINY` | `critical` | libnotify urgency override |
| `POKIDLE_DB_PATH` | `$XDG_DATA_HOME/pokidle/pokidle.db` | SQLite file |
| `POKIDLE_CONFIG_DIR` | `$XDG_CONFIG_HOME/pokidle` | Holds biomes.json |
| `POKIDLE_CACHE_DIR` | `$XDG_CACHE_HOME/pokidle` | Pool / sprite / API cache |
| `POKIDLE_DATA_DIR` | `$XDG_DATA_HOME/pokidle` | DB + sound assets |
| `POKIDLE_FALLBACK_BIOME` | `wild` | Biome assigned to unmatched areas |
| `POKIDLE_LIST_LIMIT` | `50` | Default `--limit` for `list`/`items` |
| `POKIDLE_CATIMG_WIDTH` | `16` | Sprite width in `list` output |
| `POKIDLE_LOG_LEVEL` | `info` | `debug` / `info` / `warn` / `error` |
| `POKIDLE_RATE_LIMIT_SLEEP` | `0.5` | Sleep seconds after live API fetch |
| `POKEAPI_BASE_URL` | (lib default) | Inherited from pokeapi lib |
| `POKEAPI_USER_AGENT` | (lib default) | Inherited from pokeapi lib |
| `POKEAPI_CACHE_DIR` | (lib default) | Inherited from pokeapi lib (separate from `POKIDLE_CACHE_DIR`) |

## Open questions deferred to plan/implementation

- Exact biome → berry / held-item mappings (curation work to author all entries while building `biomes.json`).
- Per-biome manual area overrides (e.g. `farm`, which has no canon match) — fixed list of synthetic encounters or just empty pool that defers to fallback.
- Sound asset sourcing (royalty-free files to bundle).
- Whether to ship `pokidle install-service` as a wrapper around `setup` for legibility, or make `setup --enable` the only path.
