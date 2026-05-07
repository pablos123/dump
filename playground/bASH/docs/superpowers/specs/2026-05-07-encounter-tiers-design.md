# Encounter Rarity Tiers — Design

Date: 2026-05-07
Status: Approved (pending implementation plan)

## Problem

Today's encounter pool (`lib/encounter.bash`, `encounter_build_pool` /
`encounter_roll_pool_entry`):

- Aggregates raw PokeAPI `chance` per species across area+version rows, walks
  the evolution chain assigning child stages a halved pct, then **normalizes
  the whole pool to sum to 100%**.
- Roll path scans entries one by one, computing a cumulative float total in
  `awk` and comparing against a uniform 0–100 float draw.

Two problems:

1. The per-biome pct normalization is opaque — once normalized, the value
   carries no clear meaning. A 2% entry in cave doesn't relate to a 2% entry
   in forest.
2. The roll loop spawns `awk` and N `jq` invocations per entry, on every
   encounter. Slow and over-engineered for what should be "pick a species".

## Goal

Replace the per-entry weighted roll with a two-step rarity-tier roll:

1. Pick a tier with fixed weights.
2. Pick a species uniformly from the chosen tier's array.

Use the raw aggregated chance only at pool-build time, to bucket each species
into a tier. After bucketing, the numeric pct is discarded.

## Non-goals

- No change to encounter stat math, ability/move/IV/EV/nature/gender rolls.
- No change to held-berry or item-pool rolls.
- No change to the biomes config (`config/biomes.json`).
- No change to the PokeAPI HTTP cache (`POKEAPI_CACHE_DIR`).

## Design

### Tier classification (build time)

Constants in `lib/encounter.bash`:

```bash
ENCOUNTER_TIERS=(common uncommon rare very_rare)

# pct >= MIN[i] AND pct < MIN[i-1] (or +inf for i=0) places species in tier i.
ENCOUNTER_TIER_PCT_MIN=(25 10 3 0)

# Fixed roll weights, sum=100. Index aligned with ENCOUNTER_TIERS.
ENCOUNTER_TIER_ROLL_WEIGHT=(60 25 12 3)
```

Bucket rule, given aggregated `pct` (integer sum of all
`encounter_details[].chance` rows for the species across the biome's areas
and matching version filter):

| pct range  | tier      |
| ---------- | --------- |
| `>= 25`    | common    |
| `10..24`   | uncommon  |
| `3..9`     | rare      |
| `< 3`      | very_rare |

The pct value is computed exactly as today (`group_by(.species) | sum(chance)`)
but is no longer normalized to 100% and is **not stored** in the final pool.

### Evolution chain expansion

Same chain walk as today (`encounter_walk_chain`) — root + each evolved stage
gets an entry with its own min/max level.

Tier of evolved stages = root tier shifted one step rarer per stage, clamped
at `very_rare`:

| root tier | stage 1   | stage 2    |
| --------- | --------- | ---------- |
| common    | uncommon  | rare       |
| uncommon  | rare      | very_rare  |
| rare      | very_rare | very_rare  |
| very_rare | very_rare | very_rare  |

Levels: stage 0 uses `[area_min, area_max]`; stage N uses
`[ max(min_level_evo, parent_max+10), parent_max+10 + (area_max-area_min) ]`
exactly as today.

### Deduping across roots

A species can be reached via multiple roots (e.g., the same area lists Zubat
and the chain expansion of another root also walks into Zubat — unlikely, but
form-aliases or cross-root chains can hit it). Rule: if the same species
appears in multiple tiers after expansion, **keep the entry from the
most-common tier** (common > uncommon > rare > very_rare). This means a
species seen directly is never demoted to a rarer tier just because some
other root's chain produced it at a lower stage.

The kept entry's `min` / `max` come from the kept tier's source row — the
losing entry is dropped entirely, levels and all. Within a single tier,
duplicate species (same root listed twice) are merged: `min = min(...)`,
`max = max(...)`.

### Pool file schema (v2)

`~/.cache/pokidle/pools/<biome>.json`:

```json
{
  "biome": "cave",
  "built_at": "2026-05-07T18:30:00Z",
  "gen_filter": [],
  "schema": 2,
  "tiers": {
    "common":    [{"species": "zubat",  "min": 5, "max": 12}],
    "uncommon":  [{"species": "geodude","min": 6, "max": 13}],
    "rare":      [{"species": "onix",   "min": 8, "max": 15}],
    "very_rare": [{"species": "golbat", "min": 22,"max": 29}]
  }
}
```

Notes:

- Entries hold only `species`, `min`, `max`. No `pct`.
- `schema: 2` is a hard marker. Loader rejects anything without it.
- `gen_filter` and `built_at` keep their current meaning.

### Roll algorithm

`encounter_roll_pool_entry <pool_json>`:

```
roll = RANDOM % 100
cum  = 0
for i in 0..3:
    cum += ENCOUNTER_TIER_ROLL_WEIGHT[i]
    if roll < cum: tier_idx = i; break

# Empty-bucket forward fallback.
for step in 0..3:
    name = ENCOUNTER_TIERS[(tier_idx + step) % 4]
    arr  = .tiers[name]
    if length(arr) > 0: pick = arr[RANDOM % length(arr)]; break

print pick   # {species, min, max} JSON object
```

Pure integer arithmetic. Two `jq` calls (length, index). No `awk`, no float.

If all four tiers are empty, the function errors out — the pool was built
with no source data, which means the biome config is broken.

### Loader guard

`encounter_pool_load <biome>`:

- If file missing → error today: `no pool for <biome>`.
- If file present but `.schema != 2` → error
  `pool stale, run: pokidle pools rebuild`.
- Otherwise return file contents.

No silent rebuild on stale file. The user runs the rebuild command.

### Rebuild command

The CLI already has `pokidle rebuild-pool [biome]` (defined in `pokidle`
around `pokidle_rebuild_pool`). Reuse it. Two adjustments:

1. When no `biome` arg is passed, `rm -rf
   "${POKIDLE_CACHE_DIR:-$HOME/.cache/pokidle}/pools"` before the rebuild
   loop, so stale v1 files are removed even for biomes that no longer have
   an area list.
2. Update its summary line to print tier counts:
   `rebuilt pool: cave (common=12 uncommon=4 rare=2 very_rare=1)`.

Area discovery is already cached at `${POKIDLE_CACHE_DIR}/biome-areas/<biome>.json`
by the separate `pokidle rebuild-biomes` command. `rebuild-pool` only reads
those files — it does not refetch `location-area` lists.

Critically: `rebuild-pool` does **not** touch `POKEAPI_CACHE_DIR` (default
`~/.cache/pokeapi`). The existing `pokidle clean` command nukes the HTTP
cache too, so users **must not** use `clean` for this migration — the
right command is `rebuild-pool` alone. With a warm HTTP cache the rebuild
is fully offline.

## Tests

`tests/test-encounter-pool.bats`:

- `encounter_build_pool` returns a v2 pool with `tiers.{common,uncommon,rare,very_rare}` arrays and no `pct` field on entries.
- pct→tier classifier: boundary values 25 → common, 24 → uncommon, 10 → uncommon, 9 → rare, 3 → rare, 2 → very_rare, 0 → very_rare.
- Evo shift: a root in `common` produces stage 1 in `uncommon`, stage 2 in `rare`. Root in `rare` produces stages in `very_rare`.
- Multi-root collision: same species reachable from a `common` root and a `rare` root ends up in `common` only.
- `encounter_pool_save` / `encounter_pool_load` round-trip preserves `schema: 2`.
- `encounter_pool_load` on a v1 file (no `schema` field) fails with the rebuild hint.
- `encounter_roll_pool_entry`:
  - Returns one of the species present in the pool.
  - With only `very_rare` populated, fixed-weight roll still returns it (forward fallback).
  - With all tiers empty, errors out.

## Migration

One-time, user-driven, after deploying the code change:

```
pokidle rebuild-pool
```

That wipes `${POKIDLE_CACHE_DIR}/pools` and rebuilds every biome from cached
`biome-areas/*.json` and the warm `POKEAPI_CACHE_DIR`. Do **not** run
`pokidle clean` — it would also wipe the HTTP cache and force a full
re-download.

Until the rebuild runs, every encounter will fail with `pool stale, run:
pokidle rebuild-pool` (the v2 schema guard). That's the intended UX —
explicit, one-shot, no silent rebuild.

## Out of scope (not in this change)

- Per-biome tuning of tier weights or boundaries.
- Persisting tier identity on the encounter row in DB (the encounter object
  doesn't need it; the tier is a roll mechanic, not an attribute).
- Migration path that auto-rebuilds in-place — explicitly rejected.
