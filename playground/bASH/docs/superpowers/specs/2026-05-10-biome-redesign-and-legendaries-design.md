# Biome Redesign + Legendary Tick — Design

Date: 2026-05-10
Status: Pending plan + implementation

## Problem

Two issues with the current encounter system:

1. **Biomes are area-derived, opaque, and incomplete.**
   `biome_classify_area` (regex on `/location-area` names + type-affinity score)
   buckets every PokeAPI area into one biome, then `encounter_build_pool`
   sums chance% across areas to tier species. Effects:
   - Many species are unreachable — only species that appear in some
     `pokemon_encounters` list end up in a pool.
   - The `wild` biome is dead — fallback target with empty pool (0 entries,
     105 classified areas — `_biome_pool_size < BIOME_MIN_POOL_SIZE=10`,
     `biome_pick_random` skips it).
   - Several biomes are thin or shadowed by regex-order collisions
     (`graveyard` swallowed by `ruins`, `sky` shadowed by `ruins`, `farm`
     trivially small).
   - Berry pools and item pools are hand-curated per biome — easy to forget
     a type when adding a biome.

2. **Legendaries have zero special handling.** No `is_legendary` flag
   consulted, no tier override, no spawn ban. A legendary species that
   appears in any `/location-area` becomes a normal pool entry — bucketed by
   raw chance%, which for roamer-style high-chance encounters lands them in
   `common`. They notify like any other Pokémon.

## Goals

1. **Type-derived biomes.** Each biome declares a small set of Pokémon types
   (~4-5). The biome's pool is the union of species in those types,
   tier-classified by `pokemon-species.capture_rate`. Exhaustive: every
   type → ≥1 biome → every non-legendary species is reachable somewhere.
2. **Auto-derived berries and held items.**
   - Berries map to biomes via `berry.natural_gift_type`.
   - Held items map to biomes via a hardcoded `type → [items]` table in
     `lib/encounter.bash`.
   Both derived at pool build, validated as exhaustive.
3. **Drop weak regex classification.** Remove `biome_classify_area`, the
   `rebuild-biomes` subcommand, and the `biome-areas` cache.
4. **Delete `wild` biome.** With type-derived pools, every other biome is
   well-populated; the catch-all is no longer needed.
5. **Legendary tick.** New daemon tick fires daily, with a low per-fire
   chance, to drop a legendary Pokémon into the current biome session.
   Notifies with critical urgency + dedicated sound override.

## Non-goals

- No regional-form / mega / gigantamax handling. Species are referenced by
  default PokeAPI name; varieties remain ignored as they are today.
- No new database tables or columns. `encounters.species` already records
  the legendary by name — no flag column needed.
- No backfill / migration of historical encounters. Existing rows stay as
  they are; only the pool-building / roll-selecting code changes.
- No change to the level / friendship / evolve loops.

## New biome schema

`config/biomes.json`:

```json
{
  "biomes": [
    {
      "id": "forest",
      "label": "Forest",
      "types": ["grass", "bug", "poison", "fairy"]
    },
    ...
  ]
}
```

Fields removed: `name_regex`, `type_affinity`, `berry_pool`, `item_pool`,
top-level `fallback_biome`.

Required keys per entry: `id`, `label`, `types` (array, ≥1 entry).

### Proposed biome roster (17 biomes, every type covered ≥2×)

| biome        | types                                  |
|--------------|----------------------------------------|
| cave         | rock, ground, dark, fighting           |
| desert       | ground, fire, rock                     |
| forest       | grass, bug, poison, fairy              |
| mountain     | rock, ice, flying, ground              |
| volcano      | fire, rock, dragon                     |
| plain        | normal, flying, grass, fairy           |
| savanna      | normal, fire, ground, fighting         |
| safari       | normal, grass, bug, water              |
| water        | water, ice                             |
| swamp        | grass, poison, water, ground           |
| ice          | ice, water                             |
| ruins        | ghost, psychic, rock, dark             |
| urban        | normal, electric, steel, poison        |
| sky          | flying, dragon, fairy                  |
| power-plant  | electric, steel, fire                  |
| graveyard    | ghost, dark, poison                    |
| farm         | grass, normal, bug, fairy              |

Type coverage check (every PokeAPI primary type appears ≥1×, target ≥2×):

- normal: plain, savanna, safari, urban, farm (5)
- fighting: cave, savanna (2)
- flying: mountain, plain, sky (3)
- poison: forest, swamp, urban, graveyard (4)
- ground: cave, desert, mountain, savanna, swamp (5)
- rock: cave, desert, mountain, volcano, ruins (5)
- bug: forest, safari, farm (3)
- ghost: ruins, graveyard (2)
- steel: urban, power-plant (2)
- fire: desert, volcano, savanna, power-plant (4)
- water: safari, water, swamp, ice (4)
- grass: forest, plain, safari, swamp, farm (5)
- electric: urban, power-plant (2)
- psychic: ruins (1) — see open question
- ice: mountain, water, ice (3)
- dragon: volcano, sky (2)
- dark: cave, ruins, graveyard (3)
- fairy: forest, plain, sky, farm (4)

Open: psychic only in `ruins` (single biome). Acceptable — psychic is rare
type — but could add to `urban` or a new `temple` biome later.

## Pool build algorithm

`encounter_build_pool <biome_id>`:

1. Load biome config; extract `types[]`.
2. For each `t`: `pokeapi_get type/$t` → collect `pokemon[].pokemon.name`.
   Union across types, dedup.
3. For each species, `pokeapi_get pokemon-species/$species`:
   - Skip if `is_legendary == true || is_mythical == true`.
   - Read `capture_rate`. Map to tier:
     - `≥150` → common
     - `≥75`  → uncommon
     - `≥25`  → rare
     - `<25`  → very_rare
4. For each non-legendary, build base entry `{species, min, max, tier_idx}`
   with synthesized level range:
   - root (no evolution antecedent): `min=5, max=15`
5. Walk evolution chain (`evolution-chain` via species → URL → id) once per
   chain; reuse existing `encounter_walk_chain` helper. For each non-root
   stage:
   - `min = stage.min_level_evo // (parent_max + 10)`
   - `max = min + 10`
   - `tier_idx = min(parent_tier_idx + 1, 3)`  (shift toward very_rare)
   - Include the evolved species *only if* it is in the biome's type set —
     otherwise the tier-shifted slot is still added (matches today's
     behavior of expanding chain from any base encounter).

   Decision: **always include evolved stages**, even if their types don't
   overlap the biome. Rationale: today the pool's `evolution_apply` step
   re-classifies on evolution via `evolution_tier_lookup` and species
   identity, not biome type membership. Keeping evolved stages in the
   biome that contains the base preserves single-biome lifecycles
   (e.g., Eevee in plain → Espeon also in plain).

6. Collision dedup across the (per-species) flat list: same species in
   multiple tier slots → keep min tier_idx (most common), merge level
   ranges. Existing logic in `encounter_build_pool` Step 4 is preserved.
7. Bucket into tier arrays. Append `berries[]` derived in Step 8 (next).
8. **Berry derivation** (run inside `encounter_build_pool`):
   - For each PokeAPI berry (enumerate `/berry?limit=100`):
     `pokeapi_get berry/$name` → `.natural_gift_type.name`.
   - Include berry if its `natural_gift_type` ∈ `biome.types`.
   - Save into pool JSON as `.berries[]` (array of berry names).
   - Total berries ≈ 64; one-time cache hit per name.
9. Save resulting pool with new schema `version: 3`:
   ```json
   {
     "biome": "forest",
     "built_at": "...",
     "schema": 3,
     "tiers": { "common": [...], "uncommon": [...], "rare": [...], "very_rare": [...] },
     "berries": ["pecha", "chesto", ...]
   }
   ```

## Held-item type table

Hardcoded in `lib/encounter.bash`:

```bash
declare -gA ENCOUNTER_HELD_ITEMS_BY_TYPE=(
    [normal]="silk-scarf chilan-berry"
    [fire]="charcoal flame-plate heat-rock occa-berry"
    [water]="mystic-water sea-incense wave-incense splash-plate wacan-berry"
    [electric]="magnet zap-plate cell-battery wacan-berry"
    [grass]="miracle-seed meadow-plate rose-incense rindo-berry"
    [ice]="never-melt-ice icicle-plate icy-rock yache-berry"
    [fighting]="black-belt fist-plate muscle-band chople-berry"
    [poison]="poison-barb toxic-plate black-sludge kebia-berry"
    [ground]="soft-sand earth-plate shuca-berry"
    [flying]="sharp-beak sky-plate pretty-feather coba-berry"
    [psychic]="twisted-spoon mind-plate odd-incense payapa-berry"
    [bug]="silver-powder insect-plate shed-shell tanga-berry"
    [rock]="hard-stone stone-plate rock-incense charti-berry"
    [ghost]="spell-tag spooky-plate reaper-cloth kasib-berry"
    [dragon]="dragon-fang draco-plate dragon-scale haban-berry"
    [dark]="black-glasses dread-plate scope-lens colbur-berry"
    [steel]="metal-coat iron-plate metal-powder shuca-berry"
    [fairy]="pixie-plate roseli-berry"
)
```

Plus a small generic pool (sprinkled into every biome at low rate):

```bash
declare -ga ENCOUNTER_HELD_ITEMS_GENERIC=(
    "leftovers" "shell-bell" "lucky-egg" "amulet-coin"
    "smoke-ball" "soothe-bell" "exp-share" "everstone"
)
```

Roll: `encounter_roll_item <biome_id>` returns 1 item picked uniformly
from `(∪ ENCOUNTER_HELD_ITEMS_BY_TYPE[t] for t in biome.types) ∪
ENCOUNTER_HELD_ITEMS_GENERIC` (dedup).

## Validator

New `biome_validate` checks (in `lib/biome.bash`):

1. **Shape.** `.biomes` present, each entry has `id`, `label`, `types[≥1]`.
2. **Unique ids.** No duplicate biome ids.
3. **Type coverage.** Every PokeAPI primary type (18 hardcoded names)
   appears in ≥1 biome.types.
4. **Berry coverage.** Every PokeAPI berry's `natural_gift_type` ∈ ∪
   biome.types (i.e., the union of all biome types covers every berry type).
   Implementation: derive once via PokeAPI listing during validator,
   compare against type union.
5. **Held-item coverage.** Every key in `ENCOUNTER_HELD_ITEMS_BY_TYPE`
   appears in ∪ biome.types.

Failure on any → non-zero exit, daemon refuses to start (current behavior
preserved).

## Legendary tick

### Roster (hardcoded)

`lib/legendary.bash`:

```bash
declare -ga LEGENDARY_SPECIES=(
    # Gen 1
    articuno zapdos moltres mewtwo mew
    # Gen 2
    raikou entei suicune lugia ho-oh celebi
    # Gen 3
    regirock regice registeel latias latios kyogre groudon
    rayquaza jirachi deoxys
    # Gen 4
    uxie mesprit azelf dialga palkia heatran regigigas giratina
    cresselia phione manaphy darkrai shaymin arceus
    # Gen 5
    victini cobalion terrakion virizion tornadus thundurus reshiram
    zekrom landorus kyurem keldeo meloetta genesect
    # Gen 6
    xerneas yveltal zygarde diancie hoopa volcanion
    # Gen 7
    type-null silvally tapu-koko tapu-lele tapu-bulu tapu-fini
    cosmog cosmoem solgaleo lunala nihilego buzzwole pheromosa
    xurkitree celesteela kartana guzzlord necrozma magearna
    marshadow poipole naganadel stakataka blacephalon zeraora
    meltan melmetal
    # Gen 8
    zacian zamazenta eternatus kubfu urshifu zarude regieleki
    regidrago glastrier spectrier calyrex
)
```

(~90 entries. List is stable across PokeAPI versions; if a new generation
drops, append.)

### Tick behavior

`pokidle tick legendary [--no-dry-run] [--no-notify] [--json]`:

1. `db_init`. Resolve active biome session (open one if none, same as
   `tick pokemon`).
2. Roll: `RANDOM % 100 < POKIDLE_LEGENDARY_CHANCE` (default `3`).
   If miss, emit "legendary: no spawn this tick" and exit.
3. Pick `species = LEGENDARY_SPECIES[RANDOM % N]`.
4. Build encounter: level rolled in `[POKIDLE_LEGENDARY_LEVEL_MIN:=50,
   POKIDLE_LEGENDARY_LEVEL_MAX:=70]`. IVs/EVs/nature/ability/moves/gender/
   shiny/friendship via the existing `encounter_roll_*` helpers.
   `held_berry = null` (legendaries don't carry biome berries — they are
   visitors). Sprite cached via existing path.
5. Insert into `encounters` table (under current `session_id`) when
   `--no-dry-run`.
6. Emit notification (`notify_pokemon` with `is_legendary: true` flag,
   see next section).

### Daemon hook

In `pokidle_daemon`:

```bash
local next_legendary
next_legendary="$(db_state_get last_legendary_tick_target)"
if [[ -z "$next_legendary" || "$next_legendary" -le "$now" ]]; then
    next_legendary="$(_pokidle_next_tick_target "$now" "${POKIDLE_LEGENDARY_INTERVAL:-86400}")"
    db_state_set last_legendary_tick_target "$next_legendary"
fi
```

Then in main loop:

```bash
if (( now >= next_legendary )); then
    pokidle_tick legendary --no-dry-run --json > /dev/null \
        || printf 'daemon: legendary tick failed (continuing)\n' >&2
    next_legendary="$(_pokidle_next_tick_target "$now" "${POKIDLE_LEGENDARY_INTERVAL:-86400}")"
    db_state_set last_legendary_tick_target "$next_legendary"
fi
```

`(( next_legendary < next_event ))` added to the sleep-budget calc.

## Notifications

Extend `notify_pokemon` in `lib/notify.bash`: encounter JSON gets an
optional `is_legendary` boolean. When set:

- Title prefix: `[LEGENDARY ⚡]` (shiny override still takes priority if
  both — `[SHINY LEGENDARY ✨⚡]`).
- Urgency: `${POKIDLE_NOTIFY_URGENCY_LEGENDARY:-critical}`.
- Sound: play `POKIDLE_SOUND_LEGENDARY` (path; defaults to
  `${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/legendary.ogg`).
  Falls back to `POKIDLE_SOUND_SHINY` then encounter sound. Plays
  unconditionally on legendary regardless of `POKIDLE_SOUND` policy
  (mirrors shiny behavior).

Reuses `POKIDLE_NOTIFY_POKEMON` gate. No new toggle env var (per design
discussion).

### `docs/notifications.md` updates

Add **legendary** row to the event table:

| legendary | legendary encounter (subset of pokemon) | on | `POKIDLE_NOTIFY_POKEMON` | critical\*\*\* | legendary\*\*\*\* |

Add footnotes:

- `***` Legendary urgency override: `POKIDLE_NOTIFY_URGENCY_LEGENDARY`
  (default `critical`).
- `****` Legendary sound plays unconditionally (ignores `POKIDLE_SOUND`
  policy); override path: `POKIDLE_SOUND_LEGENDARY`.

## Files removed / dropped from existing code

- `biome_classify_area` (lib/biome.bash:96-145)
- `_biome_area_types` (lib/biome.bash:81-91)
- `pokidle_rebuild_biomes` (pokidle:803-...)
- `rebuild-biomes` subcommand dispatcher line
- `~/.cache/pokidle/biome-areas/` directory (purge in `clean`)
- `wild` biome entry in `config/biomes.json`
- `fallback_biome` top-level field
- `name_regex`, `type_affinity`, `berry_pool`, `item_pool` fields per biome
- `tests/test-biome-classifier.bats` (delete entirely)

## Migration

1. User runs `pokidle clean` (after upgrade). Cleans pools + biome-areas.
2. User runs `pokidle rebuild-pool` (no biome arg = all). Rebuilds with
   new algorithm; biome-areas is gone, no `rebuild-biomes` step needed.
3. Daemon restarts. Legendary timer fires fresh.

Legacy pool files (`schema: 2`) become stale. `encounter_pool_load` reads
whatever's on disk; mismatched-schema pools will look fine to old readers,
but new fields (`.berries[]`) won't be there. To prevent silent partial
state, bump schema check: `encounter_pool_load` warns + force-rebuilds if
`schema != 3`.

## Open questions

1. **psychic single-biome.** Add psychic to `urban` types, or accept
   single-biome coverage as the floor? Current spec leaves as-is.
2. **Berry rate vs item rate.** Today `POKIDLE_BERRY_RATE=15` % chance per
   encounter. With auto-derive, biome berry pools will vary in size — does
   the rate need rebalancing? Spec keeps `15` as-is, revisit empirically.
3. **Legendary in stats output.** `pokidle stats` doesn't differentiate
   legendaries today. Worth a follow-up: add `is_legendary` derived column
   in `pokidle list / stats`. Out of scope for this plan.
