# Evolution + Level-Up + Friendship Loops — Design

Date: 2026-05-09
Status: Pending plan + implementation

## Problem

Encounters in `encounters` table are static after insert. They never level up,
never evolve. The world feels frozen. Goal: add two background loops that
make the encounter set evolve over time, mirroring real-game progression
without requiring active play.

## Goals

1. **Level-up loop:** every hour, each current-week encounter has a small
   chance to gain a level. Stats are recomputed in place.
2. **Friendship loop:** every 30 min, each current-week encounter has a
   chance to gain friendship. Used by friendship-gated evolutions.
3. **Evolution loop:** every biome rotation, each current-week encounter is
   checked for evolution eligibility. On a tier-weighted roll, it evolves —
   species, dex_id, sprite, and stats updated in place.

## Non-goals

- No tracking of affection, beauty, party composition, weather, trade
  partners, or held items. These conditions remain "soft" (always-viable)
  for evolutions that depend on them.
- No backfill. Encounters predating the loop deployment are not retroactively
  leveled or evolved; they only enter the candidate set if they fall within
  the current ISO week (Mon 00:00 local — Sun 23:59 local).
- One schema change only: add `friendship` column to `encounters`. No new
  tables.

## Definitions

- **Current-week candidates:** rows in `encounters` whose `encountered_at`
  (Unix seconds) falls in the current ISO week, computed locally.
  - Monday 00:00 local → Sunday 23:59:59 local.
  - Reset every Monday.
- **Tier of an encounter** at evolution time: the tier the species occupies
  in the *current biome's* cached pool. If the species is not present in any
  tier of the current biome's pool, default to `common`.

## Schema change

```sql
ALTER TABLE encounters ADD COLUMN friendship INTEGER NOT NULL DEFAULT 70;
```

`70` is PokeAPI's most-common base_happiness — applied to legacy rows that
predate the change (idle decay/growth doesn't apply to them anyway since
they fall outside the current-week window).

New encounters get the species' `base_happiness` from
`/pokemon-species/<sp>` (cached). Stored at insert time.

## Loop A — Level-up

### Trigger
Daemon-driven third timer alongside pokemon/item ticks. Persisted to
`daemon_state`.

- `POKIDLE_LEVEL_INTERVAL` (default `3600`, seconds).
- Daemon-state key: `last_level_tick_target`.
- Reuses the existing `_pokidle_next_tick_target` jitter helper.

### Per-iteration behavior

For each current-week candidate, in encounter-row order:

1. If `level >= 100`, skip.
2. Roll `RANDOM % 100`. If `>= 25`, skip (75% no-op rate).
3. `level := level + 1` (capped at 100).
4. Recompute `stats` from stored `ivs`, `evs`, `nature` and the new level.
   Base stats fetched via `pokeapi_get pokemon/<species>` (cache hit on warm
   builds).
5. UPDATE the encounter row: `level`, `stats` only.

### CLI

`pokidle tick level` runs one iteration manually (mirrors `tick pokemon` /
`tick item`). Same `--dry-run`, `--no-notify`, `--json` flags. JSON shape:

```json
{ "leveled": [{"id": 42, "species": "zigzagoon", "from": 5, "to": 6}, …] }
```

Notification: silent by default. `--no-notify` is the natural default;
`notify-send` only fires on `--notify-on-level` (out of scope for v1 — the
loop is too noisy to broadcast each level-up).

### Stats recomputation

Reuse `encounter_compute_all_stats` from `lib/encounter.bash`. Inputs:

- `base_json`: `.stats` from `/pokemon/<species>` (cached)
- `ivs_str`, `evs_str`: split from `encounters.ivs` / `.evs` JSON arrays
- `level`: new level
- `mods_str`: from `encounter_nature_mods <nature>`

## Loop B — Friendship

### Trigger

`POKIDLE_FRIENDSHIP_INTERVAL` (default `1800`, seconds — 30 min). 4th daemon
timer alongside pokemon/item/level. Persisted to `daemon_state` under
`last_friendship_tick_target`.

### Per-iteration behavior

For each current-week candidate, in encounter-row order:

1. If `friendship >= 255`, skip.
2. Roll `RANDOM % 100`. If `>= 50`, skip (50% no-op rate).
3. `friendship := min(255, friendship + 5)`.
4. UPDATE the encounter row: `friendship` only.

### CLI

`pokidle tick friendship` runs one iteration manually. `--dry-run`,
`--no-notify`, `--json`. JSON shape:

```json
{ "befriended": [{"id": 42, "species": "golbat", "from": 70, "to": 75}, …] }
```

Daemon mode: silent. No notification per friendship gain.

## Loop C — Evolution

### Trigger
Fires once per biome rotation, immediately after the new biome session is
opened. Hooked into the daemon's `_pokidle_rotate_biome` flow (and into
`pokidle switch-biome`'s handler so manual rotations also trigger it).

`POKIDLE_EVOLVE_ENABLED` (default `1`) gates the loop. Setting `0` disables
without ripping out code.

### Per-candidate procedure

For each current-week candidate (rows ordered by `id` ASC for determinism):

```
species  := encounter.species
chain    := evolution chain via /pokemon-species/<species> → /evolution-chain/<id>
next_evos := chain entries one stage after the candidate's species
viable    := []

for evo in next_evos:
    # Hard filters (must pass strictly):
    if evo.required_gender exists and encounter.gender != evo.required_gender:
        continue
    if evo.min_level exists and encounter.level < evo.min_level:
        continue
    if evo.time_of_day in {"day","night"} and current_time_of_day != evo.time_of_day:
        continue
    if evo.known_move exists and evo.known_move not in encounter.moves:
        continue
    if evo.known_move_type exists and no move of that type in encounter.moves:
        continue
    if evo.relative_physical_stats exists:
        atk := encounter.stats[1]; def := encounter.stats[2]
        if rule == 1 and not (atk > def): continue
        if rule == -1 and not (def > atk): continue
        if rule == 0 and atk != def: continue
    if evo.min_happiness exists and encounter.friendship < evo.min_happiness:
        continue

    # Item path:
    if evo has evolution_item or held_item or trigger == "use-item":
        item_name := evo.evolution_item.name (or held_item.name)
        if item_drops has at least one row with item = item_name:
            viable += {evo: evo, kind: "item", item: item_name}
        # else: skip — strict requirement
        continue

    # Soft / synthetic path: affection, beauty, trade, party_*, weather,
    # upside_down, special triggers, anything else not strictly checkable.
    # Always viable.
    viable += {evo: evo, kind: "synthetic"}

if viable empty: skip candidate

# Tier roll. Tier looked up in the CURRENT biome's pool.
tier := lookup_tier_in_pool(active_biome, species)   # default "common" if absent
chance := {common: 25, uncommon: 15, rare: 8, very_rare: 3}[tier]
if RANDOM % 100 >= chance: skip candidate

# Pick path uniformly:
choice := viable[RANDOM % len(viable)]

if choice.kind == "item":
    sqlite: DELETE FROM item_drops WHERE item = choice.item
            ORDER BY id ASC LIMIT 1
            (use a temporary CTE since SQLite supports DELETE with subselect)

# Build the evolved encounter:
new_species := choice.evo.species
new_dex_id  := /pokemon/<new_species>.id
new_sprite  := /pokemon/<new_species>.sprites.front_(default|shiny per is_shiny)
new_stats   := encounter_compute_all_stats(new base, ivs, evs, level, mods)

UPDATE encounters
SET species=new_species, dex_id=new_dex_id, sprite_url=new_sprite, stats=new_stats
WHERE id=encounter.id
```

### Tier lookup

```
lookup_tier_in_pool(biome, species):
    pool := encounter_pool_load(biome)
    for tier_name in (common, uncommon, rare, very_rare):
        if any entry in pool.tiers[tier_name] has species == species: return tier_name
    return "common"
```

### CLI

`pokidle tick evolve` runs one iteration manually for the active biome.
`--dry-run`, `--no-notify`, `--json`. JSON shape:

```json
{ "evolved": [{"id": 42, "from": "zigzagoon", "to": "linoone",
               "kind": "synthetic"}, …] }
```

Notification: silent (each evolution is rare-ish; daemon mode emits a
`notify-send` per evolution by default, similar to pokemon ticks).

## Schema

One column added to `encounters` (see Schema change section above):

- `friendship INTEGER NOT NULL DEFAULT 70`

Reused unchanged:

- `encounters` (UPDATE: level, stats, friendship, species, dex_id, sprite_url)
- `item_drops` (DELETE on item-path evolution)
- `daemon_state` (new keys: `last_level_tick_target`,
  `last_friendship_tick_target`)

## Tests

`tests/test-evolution.bats`, `tests/test-leveling.bats`,
`tests/test-friendship.bats` (new files):

**Leveling:**
- `pokidle tick level --dry-run` outputs JSON with `leveled` array.
- One eligible candidate (level 5, current week): with `RANDOM` stubbed to
  produce roll < 25, level becomes 6 and stats recompute.
- Candidate at level 100 → skipped.
- Candidate older than current week → skipped.

**Friendship:**
- `pokidle tick friendship --dry-run` outputs JSON with `befriended` array.
- Eligible candidate: roll < 50 → friendship += 5.
- Candidate at 255 → skipped.
- New encounter inserts `friendship` from species' `base_happiness`.
- Cap at 255 verified.

**Evolution:**
- Hard filters block evos: female-required + male encounter → skipped;
  level-required + below threshold → skipped; item-required + item not in
  `item_drops` → skipped; time-of-day mismatch → skipped;
  min_happiness-required + friendship below → skipped.
- Soft synthetic path: zigzagoon level 3 with synthetic ralts→linoone-like
  setup → still viable, evolves on tier-pass roll.
- Item path: eevee + water-stone in item_drops + tier-pass roll → evolves to
  vaporeon, item_drops loses one water-stone row.
- Friendship path: golbat at friendship=220+ → eligible for crobat (strict),
  evolves on tier-pass roll.
- Branching evos (eevee with multiple stones in DB): viable list contains
  every stone-backed path; uniform pick verified by stubbed RANDOM.
- Tier lookup: pokemon present in pool → its tier used; pokemon absent →
  defaults to common (uses 25%).
- Current-week filter: encounter outside this week not touched.

## Migration / rollout

One schema migration: `ALTER TABLE encounters ADD COLUMN friendship …`.
Applied idempotently in `db_init` (existing logic — schema bumps land via
the same `IF NOT EXISTS` / pragma path used elsewhere in `lib/db.bash`).

Loops respect `POKIDLE_EVOLVE_ENABLED`. Missing
`last_{level,friendship}_tick_target` defaults to "fire on next iteration."

## Out of scope

- Notifications per level-up or friendship gain.
- Held-item slot on encounters (currently only `held_berry`).
- Affection / beauty tracking.
- Mega evolution / Gigantamax / regional forms.
