# Biome Redesign + Legendary Tick Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace area+regex biome classification with explicit type-derived biomes (every Pokémon / berry / held-item reachable). Drop `wild` biome. Add a daily-fire legendary tick with critical-urgency notifications.

**Architecture:** `config/biomes.json` reduces to `{id, label, types[]}`. `encounter_build_pool` now takes a `biome_id`, fetches `/type/{t}` per type, unions species, filters out legendaries/mythicals, tiers by `pokemon-species.capture_rate`, expands evolution chains (existing helpers), and bakes the derived berry pool into the saved pool file. Held items derive from a hardcoded `type → [items]` table in `lib/encounter.bash`. A new `lib/legendary.bash` holds the static legendary roster + roll helper. `pokidle tick legendary` is a new subcommand with a 7th daemon timer.

**Tech Stack:** Bash 5+, sqlite3, jq, bats-core. Existing `pokeapi_get` cache layer for `/type`, `/pokemon-species`, `/berry`.

**Spec:** `docs/superpowers/specs/2026-05-10-biome-redesign-and-legendaries-design.md`

---

## File map

- Modify `config/biomes.json` — rewrite to `{id,label,types}` schema, drop `wild`, drop `fallback_biome`.
- Modify `lib/biome.bash` — drop `biome_classify_area`, `_biome_area_types`; rewrite `biome_validate` (shape + coverage); add `biome_types_for` helper.
- Modify `lib/encounter.bash` — rewrite `encounter_build_pool` signature to take `biome_id`, replace `encounter_tier_for_pct` use with new `encounter_tier_for_capture_rate`, add `ENCOUNTER_HELD_ITEMS_BY_TYPE` / `ENCOUNTER_HELD_ITEMS_GENERIC`, rewrite `encounter_roll_item` + `encounter_roll_held_berry` to read derived pool.
- Create `lib/legendary.bash` — `LEGENDARY_SPECIES` array, `legendary_roll_species`, `legendary_build_encounter`.
- Modify `pokidle` — source new lib, drop `rebuild-biomes` + `pokidle_rebuild_biomes`, add `pokidle_tick_legendary`, wire 7th daemon timer, extend `_pokidle_announce_biome` to read pool size correctly, update `clean` to wipe legacy `biome-areas/`, update help text.
- Modify `lib/notify.bash` — `notify_pokemon` reads optional `is_legendary` flag, applies title prefix + urgency override + legendary sound.
- Modify `docs/notifications.md` — add legendary row + sound/urgency footnotes.
- Delete `tests/test-biome-classifier.bats`.
- Update `tests/test-biome-config.bats`, `tests/test-biome-rotation.bats`, `tests/test-encounter-pool.bats`, `tests/test-encounter-rolls.bats`.
- Create `tests/test-legendary.bats`.
- Add fixtures under `tests/fixtures/`: `type-grass.json`, `type-bug.json`, `type-fairy.json`, `type-poison.json`, `berry-pecha.json`, `berry-cheri.json`, `berry-chesto.json`, `pokemon-species-articuno.json`, `pokemon-species-pikachu.json`, `pokemon-species-pidgey.json`, `pokemon-species-bulbasaur.json`, plus existing fixtures.

## Conventions

- Test runner: `bats tests/<file>.bats`. Full suite: `bats tests/`.
- Each task is TDD: failing test first, run-fail, implement, run-pass, commit.
- Commits land per task. Branch: existing main (no feature branch, repo workflow).
- Caveman prose is fine in conversation but **plans, specs, code, and commit messages stay in normal mode**.

---

## Task 1: Drop wild biome + rewrite schema in config

**Files:**
- Modify: `config/biomes.json`
- Test: extend `tests/test-biome-config.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-biome-config.bats`:

```bash
@test "biome config: schema is {id,label,types[]} only, no regex/affinity/berries/items" {
    local cfg
    cfg="$(cat "$REPO_ROOT/config/biomes.json")"
    # Top-level fallback_biome removed.
    run jq -e 'has("fallback_biome")' <<< "$cfg"
    [ "$status" -ne 0 ]
    # No biome has a name_regex / type_affinity / berry_pool / item_pool.
    local bad
    bad="$(jq -r '[.biomes[] | select(
        has("name_regex") or has("type_affinity") or
        has("berry_pool") or has("item_pool")
    ) | .id] | length' <<< "$cfg")"
    [ "$bad" = "0" ]
    # Every biome has id/label/types with at least one type.
    local missing
    missing="$(jq -r '[.biomes[] | select(
        (has("id")|not) or (has("label")|not) or
        (has("types")|not) or (.types | length == 0)
    ) | (.id // "<none>")] | length' <<< "$cfg")"
    [ "$missing" = "0" ]
}

@test "biome config: wild biome no longer present" {
    run jq -e '.biomes[] | select(.id=="wild")' "$REPO_ROOT/config/biomes.json"
    [ "$status" -ne 0 ]
}

@test "biome config: all PokeAPI primary types appear in at least one biome" {
    local types=(
        normal fighting flying poison ground rock bug ghost steel
        fire water grass electric psychic ice dragon dark fairy
    )
    local union t
    union="$(jq -r '[.biomes[].types[]] | unique | .[]' "$REPO_ROOT/config/biomes.json")"
    for t in "${types[@]}"; do
        grep -Fxq "$t" <<< "$union" || {
            printf 'missing type coverage: %s\n' "$t" >&2
            return 1
        }
    done
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-biome-config.bats`
Expected: 3 new tests FAIL (schema still has regex/etc, wild present, coverage probably OK).

- [ ] **Step 3: Rewrite `config/biomes.json`**

Replace entire file with:

```json
{
  "biomes": [
    { "id": "cave",        "label": "Cave",        "types": ["rock", "ground", "dark", "fighting"] },
    { "id": "desert",      "label": "Desert",      "types": ["ground", "fire", "rock"] },
    { "id": "forest",      "label": "Forest",      "types": ["grass", "bug", "poison", "fairy"] },
    { "id": "mountain",    "label": "Mountain",    "types": ["rock", "ice", "flying", "ground"] },
    { "id": "volcano",     "label": "Volcano",     "types": ["fire", "rock", "dragon"] },
    { "id": "plain",       "label": "Plain",       "types": ["normal", "flying", "grass", "fairy"] },
    { "id": "savanna",     "label": "Savanna",     "types": ["normal", "fire", "ground", "fighting"] },
    { "id": "safari",      "label": "Safari",      "types": ["normal", "grass", "bug", "water"] },
    { "id": "water",       "label": "Water",       "types": ["water", "ice"] },
    { "id": "swamp",       "label": "Swamp",       "types": ["grass", "poison", "water", "ground"] },
    { "id": "ice",         "label": "Ice",         "types": ["ice", "water"] },
    { "id": "ruins",       "label": "Ruins",       "types": ["ghost", "psychic", "rock", "dark"] },
    { "id": "urban",       "label": "Urban",       "types": ["normal", "electric", "steel", "poison"] },
    { "id": "sky",         "label": "Sky",         "types": ["flying", "dragon", "fairy"] },
    { "id": "power-plant", "label": "Power Plant", "types": ["electric", "steel", "fire"] },
    { "id": "graveyard",   "label": "Graveyard",   "types": ["ghost", "dark", "poison"] },
    { "id": "farm",        "label": "Farm",        "types": ["grass", "normal", "bug", "fairy"] }
  ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-biome-config.bats`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add config/biomes.json tests/test-biome-config.bats
git commit -m "pokidle: rewrite biomes.json to {id,label,types} schema, drop wild

Drops name_regex / type_affinity / berry_pool / item_pool fields and the
fallback_biome top-level. Pool/berry/item derivation moves into
encounter.bash (next commits). wild biome removed: catch-all is unnecessary
once every type is covered by ≥2 type-derived biomes."
```

---

## Task 2: Rewrite `biome_validate` for new schema

**Files:**
- Modify: `lib/biome.bash` (rewrite `biome_validate`, drop `biome_classify_area`, `_biome_area_types`, `BIOME_MIN_POOL_SIZE`-aware `_biome_pool_size` keep, add `biome_types_for`)
- Test: extend `tests/test-biome-config.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-biome-config.bats`:

```bash
@test "biome_validate: passes on current config" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib biome
    run biome_validate
    [ "$status" -eq 0 ]
}

@test "biome_validate: fails when a biome has no types" {
    local tmp
    tmp="$(mktemp -d)"
    cp "$REPO_ROOT/config/biomes.json" "$tmp/biomes.json"
    jq '.biomes[0].types = []' "$tmp/biomes.json" > "$tmp/biomes.json.new"
    mv "$tmp/biomes.json.new" "$tmp/biomes.json"
    POKIDLE_CONFIG_DIR="$tmp" POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CONFIG_DIR POKIDLE_REPO_ROOT
    load_lib biome
    run biome_validate
    [ "$status" -ne 0 ]
}

@test "biome_validate: fails when duplicate id" {
    local tmp
    tmp="$(mktemp -d)"
    jq '.biomes[1].id = .biomes[0].id' "$REPO_ROOT/config/biomes.json" > "$tmp/biomes.json"
    POKIDLE_CONFIG_DIR="$tmp" POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CONFIG_DIR POKIDLE_REPO_ROOT
    load_lib biome
    run biome_validate
    [ "$status" -ne 0 ]
}

@test "biome_validate: fails when an 18-list type is uncovered" {
    local tmp
    tmp="$(mktemp -d)"
    # Strip 'psychic' from ruins (its only home).
    jq '(.biomes[] | select(.id=="ruins") | .types) |= map(select(. != "psychic"))' \
        "$REPO_ROOT/config/biomes.json" > "$tmp/biomes.json"
    POKIDLE_CONFIG_DIR="$tmp" POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CONFIG_DIR POKIDLE_REPO_ROOT
    load_lib biome
    run biome_validate
    [ "$status" -ne 0 ]
    [[ "$output" == *psychic* ]]
}

@test "biome_types_for: returns types for a biome id" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib biome
    run biome_types_for forest
    [ "$status" -eq 0 ]
    [[ "$output" == *grass* ]]
    [[ "$output" == *bug* ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-biome-config.bats`
Expected: new tests FAIL — old `biome_validate` doesn't know about `types[]` or coverage; `biome_types_for` doesn't exist.

- [ ] **Step 3: Rewrite `lib/biome.bash`**

Replace contents (drop `biome_classify_area`, `_biome_area_types`; rewrite `biome_validate`; add `biome_types_for`). Keep `biome_config_path`, `biome_load`, `biome_get`, `biome_ids`, `_biome_pool_size`, `_biome_eligible_ids`, `biome_pick_random`, `biome_pick_random_excluding`.

```bash
#!/usr/bin/env bash
# lib/biome.bash — biome config loader, lookup, rotation.

biome_config_path() {
    local p
    if [[ -n "${POKIDLE_CONFIG_DIR:-}" && -f "${POKIDLE_CONFIG_DIR}/biomes.json" ]]; then
        p="${POKIDLE_CONFIG_DIR}/biomes.json"
    elif [[ -n "${POKIDLE_REPO_ROOT:-}" && -f "${POKIDLE_REPO_ROOT}/config/biomes.json" ]]; then
        p="${POKIDLE_REPO_ROOT}/config/biomes.json"
    else
        printf 'biome_config_path: cannot find biomes.json\n' >&2
        return 1
    fi
    printf '%s' "$p"
}

biome_load() {
    local p
    p="$(biome_config_path)" || return 1
    cat "$p"
}

biome_get() {
    local id="$1"
    local out
    out="$(biome_load | jq --arg id "$id" '.biomes[] | select(.id==$id)')"
    [[ -n "$out" ]] || { printf 'biome_get: unknown biome %s\n' "$id" >&2; return 1; }
    printf '%s' "$out"
}

biome_ids() {
    biome_load | jq -r '.biomes[].id'
}

biome_types_for() {
    local id="$1"
    biome_get "$id" | jq -r '.types[]'
}

# Hardcoded PokeAPI primary types. The validator asserts every entry here
# appears in ≥1 biome's types[].
BIOME_PRIMARY_TYPES=(
    normal fighting flying poison ground rock bug ghost steel
    fire water grass electric psychic ice dragon dark fairy
)

biome_validate() {
    local cfg
    cfg="$(biome_load)" || return 1

    if ! jq -e 'has("biomes")' <<< "$cfg" > /dev/null; then
        printf 'biome_validate: missing biomes array\n' >&2
        return 1
    fi

    local missing
    missing="$(jq -r '[.biomes[] | select(
        (has("id")|not) or (has("label")|not) or
        (has("types")|not) or ((.types | type) != "array") or (.types | length == 0)
    ) | (.id // "<no-id>")] | .[]' <<< "$cfg")"
    if [[ -n "$missing" ]]; then
        printf 'biome_validate: biomes missing keys or empty types: %s\n' "$missing" >&2
        return 1
    fi

    local dupes
    dupes="$(jq -r '.biomes | group_by(.id) | map(select(length>1) | .[0].id) | .[]' <<< "$cfg")"
    if [[ -n "$dupes" ]]; then
        printf 'biome_validate: duplicate biome ids: %s\n' "$dupes" >&2
        return 1
    fi

    # Type coverage: every BIOME_PRIMARY_TYPES entry must appear in some biome.
    local union t
    union="$(jq -r '[.biomes[].types[]] | unique | .[]' <<< "$cfg")"
    for t in "${BIOME_PRIMARY_TYPES[@]}"; do
        if ! grep -Fxq "$t" <<< "$union"; then
            printf 'biome_validate: type %s not covered by any biome\n' "$t" >&2
            return 1
        fi
    done

    return 0
}

: "${BIOME_MIN_POOL_SIZE:=10}"

_biome_pool_size() {
    local id="$1"
    local p="${POKIDLE_CACHE_DIR:-$HOME/.cache/pokidle}/pools/$id.json"
    [[ -f "$p" ]] || { printf '0'; return; }
    jq '[.tiers[] | length] | add // 0' "$p"
}

_biome_eligible_ids() {
    local id n
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        n="$(_biome_pool_size "$id")"
        (( n > BIOME_MIN_POOL_SIZE )) && printf '%s\n' "$id"
    done < <(biome_ids)
}

biome_pick_random() {
    local ids n idx
    mapfile -t ids < <(_biome_eligible_ids)
    n="${#ids[@]}"
    (( n > 0 )) || { printf 'biome_pick_random: no biome with pool>%d entries\n' "$BIOME_MIN_POOL_SIZE" >&2; return 1; }
    idx=$((RANDOM % n))
    printf '%s' "${ids[$idx]}"
}

biome_pick_random_excluding() {
    local exclude="$1"
    local ids filtered idx n
    mapfile -t ids < <(_biome_eligible_ids)
    filtered=()
    local id
    for id in "${ids[@]}"; do
        [[ "$id" != "$exclude" ]] && filtered+=("$id")
    done
    n="${#filtered[@]}"
    (( n > 0 )) || { printf 'biome_pick_random_excluding: no eligible biome\n' >&2; return 1; }
    idx=$((RANDOM % n))
    printf '%s' "${filtered[$idx]}"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-biome-config.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/biome.bash tests/test-biome-config.bats
git commit -m "pokidle: rewrite biome_validate for type-derived schema

Drops biome_classify_area + _biome_area_types (regex+affinity classifier
is gone). Validator now checks shape (id/label/types[≥1]), no duplicate
ids, and that every PokeAPI primary type is covered by at least one
biome. Adds biome_types_for helper."
```

---

## Task 3: Delete classifier test file + drop `rebuild-biomes` subcommand

**Files:**
- Delete: `tests/test-biome-classifier.bats`
- Modify: `pokidle` (drop `pokidle_rebuild_biomes`, drop dispatcher case, drop help line)

- [ ] **Step 1: Run existing test to confirm it currently exercises dropped functions**

Run: `bats tests/test-biome-classifier.bats`
Expected: tests fail or error (functions `biome_classify_area` no longer exist after Task 2).

- [ ] **Step 2: Delete the file**

```bash
git rm tests/test-biome-classifier.bats
```

- [ ] **Step 3: Drop `pokidle_rebuild_biomes` from `pokidle`**

In `pokidle`, remove the entire `pokidle_rebuild_biomes()` function (~line 803-end of function, locate via `grep -n 'pokidle_rebuild_biomes' pokidle`). Also remove:

- Help-text line `  rebuild-biomes          Re-classify all /location-area` (around line 54).
- Dispatcher case `rebuild-biomes) pokidle_rebuild_biomes "$@" ;;` (around line 920).
- Update `clean` help text and behavior in Task 5.

- [ ] **Step 4: Run full bats suite**

Run: `bats tests/`
Expected: PASS (no test should reference the dropped subcommand; if any do, fix them inline now).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "pokidle: drop rebuild-biomes subcommand and classifier tests

The type-derived pool builder doesn't need a per-area classifier. Removes
the now-dead subcommand, its dispatcher line, help entry, and its test
file."
```

---

## Task 4: Add tier-by-capture-rate helper

**Files:**
- Modify: `lib/encounter.bash` (add new function, keep existing `encounter_tier_for_pct` for now — Task 7 removes its callers)
- Test: extend `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "encounter_tier_for_capture_rate: boundary values map to expected tiers" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib encounter
    [ "$(encounter_tier_for_capture_rate 255)" = "common" ]
    [ "$(encounter_tier_for_capture_rate 150)" = "common" ]
    [ "$(encounter_tier_for_capture_rate 149)" = "uncommon" ]
    [ "$(encounter_tier_for_capture_rate 75)"  = "uncommon" ]
    [ "$(encounter_tier_for_capture_rate 74)"  = "rare" ]
    [ "$(encounter_tier_for_capture_rate 25)"  = "rare" ]
    [ "$(encounter_tier_for_capture_rate 24)"  = "very_rare" ]
    [ "$(encounter_tier_for_capture_rate 3)"   = "very_rare" ]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/test-encounter-pool.bats -f capture_rate`
Expected: FAIL — function doesn't exist.

- [ ] **Step 3: Add the helper**

In `lib/encounter.bash`, immediately after the existing `encounter_tier_for_pct` function, add:

```bash
# capture_rate: PokeAPI value 0..255. Higher = easier to catch = more common.
# Thresholds: 150/75/25 bucket into common/uncommon/rare/very_rare.
encounter_tier_for_capture_rate() {
    local cr="$1"
    if   (( cr >= 150 )); then printf 'common'
    elif (( cr >= 75  )); then printf 'uncommon'
    elif (( cr >= 25  )); then printf 'rare'
    else                       printf 'very_rare'
    fi
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bats tests/test-encounter-pool.bats -f capture_rate`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "pokidle: add encounter_tier_for_capture_rate helper

Replaces the chance%-derived tier classifier. capture_rate is a stable
species attribute; the old chance% was area-encounter-specific and went
away with the type-derived rewrite."
```

---

## Task 5: Update `clean` to wipe biome-areas + handle stale pool schemas

**Files:**
- Modify: `pokidle` (`pokidle_clean` function)
- Test: extend `tests/test-cli.bats`

- [ ] **Step 1: Locate `pokidle_clean`**

`grep -n 'pokidle_clean\(\)' pokidle` — find the function definition.

- [ ] **Step 2: Write the failing test**

Append to `tests/test-cli.bats`:

```bash
@test "clean: removes biome-areas directory (legacy, no longer used)" {
    local tmpcache
    tmpcache="$(mktemp -d)"
    mkdir -p "$tmpcache/pools" "$tmpcache/biome-areas"
    : > "$tmpcache/pools/forest.json"
    : > "$tmpcache/biome-areas/forest.json"
    POKIDLE_CACHE_DIR="$tmpcache"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CACHE_DIR POKIDLE_REPO_ROOT
    run "$REPO_ROOT/pokidle" clean --yes
    [ "$status" -eq 0 ]
    [ ! -d "$tmpcache/pools" ]
    [ ! -d "$tmpcache/biome-areas" ]
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `bats tests/test-cli.bats -f "removes biome-areas"`
Expected: FAIL — current `clean` may or may not touch `biome-areas`.

- [ ] **Step 4: Update `pokidle_clean`**

In `pokidle`, modify `pokidle_clean` so it removes both `pools/` and `biome-areas/` under `POKIDLE_CACHE_DIR`. Example body (adjust to match current style):

```bash
pokidle_clean() {
    local force=0
    [[ "${1-}" == "--yes" ]] && force=1
    if (( ! force )); then
        printf 'Wipe %s/{pools,biome-areas}? [y/N] ' "$POKIDLE_CACHE_DIR"
        local ans; read -r ans
        [[ "$ans" =~ ^[Yy]$ ]] || { printf 'aborted\n'; return 0; }
    fi
    rm -rf -- "$POKIDLE_CACHE_DIR/pools" "$POKIDLE_CACHE_DIR/biome-areas"
    printf 'cleaned: pools/ biome-areas/\n'
}
```

Also update the `clean` help text in `usage()`:

```
  clean [--yes]           Purge pool cache + legacy biome-areas dir
```

- [ ] **Step 5: Run to verify it passes**

Run: `bats tests/test-cli.bats -f "removes biome-areas"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pokidle tests/test-cli.bats
git commit -m "pokidle: clean now also wipes legacy biome-areas dir

biome-areas was populated by the dropped rebuild-biomes step. Old installs
will have stale data there; clean now removes it idempotently."
```

---

## Task 6: Rewrite `encounter_build_pool` to take a biome_id and derive from types

**Files:**
- Modify: `lib/encounter.bash` (rewrite `encounter_build_pool`; keep `encounter_walk_chain` as-is)
- Test: rewrite the `build_pool` tests in `tests/test-encounter-pool.bats`
- Fixtures: add `type-grass.json`, `type-bug.json`, `pokemon-species-treecko.json`, `pokemon-species-grovyle.json`, `pokemon-species-sceptile.json`, `pokemon-species-caterpie.json`, `pokemon-species-metapod.json`, `pokemon-species-butterfree.json`, `evolution-chain-3.json` (caterpie)

- [ ] **Step 1: Create the fixtures**

Use trimmed real PokeAPI responses. Minimal shape per fixture:

`tests/fixtures/type-grass.json`:

```json
{ "name": "grass", "pokemon": [
    { "pokemon": { "name": "treecko" } }
] }
```

`tests/fixtures/type-bug.json`:

```json
{ "name": "bug", "pokemon": [
    { "pokemon": { "name": "caterpie" } }
] }
```

`tests/fixtures/pokemon-species-treecko.json`:

```json
{
    "name": "treecko",
    "capture_rate": 45,
    "base_happiness": 70,
    "is_legendary": false,
    "is_mythical": false,
    "evolution_chain": { "url": "https://pokeapi.co/api/v2/evolution-chain/142/" }
}
```

`tests/fixtures/pokemon-species-grovyle.json`, `-sceptile.json`: identical shape, names changed, capture_rate `45`, same evolution_chain url.

`tests/fixtures/pokemon-species-caterpie.json`:

```json
{
    "name": "caterpie",
    "capture_rate": 255,
    "is_legendary": false,
    "is_mythical": false,
    "evolution_chain": { "url": "https://pokeapi.co/api/v2/evolution-chain/3/" }
}
```

`-metapod.json` (255) and `-butterfree.json` (45) likewise.

`tests/fixtures/evolution-chain-3.json` is the standard caterpie chain — copy the format from existing `evolution-chain-142.json` but with caterpie → metapod (min_level 7) → butterfree (min_level 10).

- [ ] **Step 2: Write the failing test**

Replace the existing `build_pool: treecko area produces v2 tier shape` test in `tests/test-encounter-pool.bats` with:

```bash
@test "build_pool: type-derived produces tier shape, includes evolution stages" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR
    # Build a 2-type biome on disk so biome_load resolves it.
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    export POKIDLE_CONFIG_DIR
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cat > "$POKIDLE_CONFIG_DIR/biomes.json" <<EOF
{ "biomes": [
    { "id": "testbiome", "label": "Test", "types": ["grass", "bug"] }
] }
EOF
    load_lib biome
    load_lib encounter
    stub_pokeapi
    run encounter_build_pool testbiome
    [ "$status" -eq 0 ]
    # Tier shape present.
    local has_tiers
    has_tiers="$(jq 'has("tiers") and (.tiers | has("common") and has("uncommon") and has("rare") and has("very_rare"))' <<< "$output")"
    [ "$has_tiers" = "true" ]
    # caterpie (capture_rate 255) ends up in common.
    local cat_tier
    cat_tier="$(jq -r '.tiers | to_entries[] | select(.value | map(.species) | index("caterpie")) | .key' <<< "$output")"
    [ "$cat_tier" = "common" ]
    # metapod (255) is caterpie+1 stage → uncommon (tier_idx shifts).
    local meta_tier
    meta_tier="$(jq -r '.tiers | to_entries[] | select(.value | map(.species) | index("metapod")) | .key' <<< "$output")"
    [ "$meta_tier" = "uncommon" ]
    # treecko (45) → uncommon.
    local tre_tier
    tre_tier="$(jq -r '.tiers | to_entries[] | select(.value | map(.species) | index("treecko")) | .key' <<< "$output")"
    [ "$tre_tier" = "uncommon" ]
}

@test "build_pool: excludes legendary/mythical species" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    export POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR POKIDLE_CONFIG_DIR
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cat > "$POKIDLE_CONFIG_DIR/biomes.json" <<EOF
{ "biomes": [{ "id": "icytest", "label": "Icy", "types": ["ice"] }] }
EOF
    # Fixture lab: ice type only contains articuno (legendary).
    cat > "$BATS_TMPDIR/cfg.$$/type-ice.json" <<EOF
{ "name": "ice", "pokemon": [{ "pokemon": { "name": "articuno" } }] }
EOF
    # Copy fixture into the test fixtures path (or write a fixture inline).
    cp "$FIXTURE_DIR/type-grass.json" "$BATS_TMPDIR/cfg.$$/dummy.json"  # placeholder
    skip "Requires type-ice + pokemon-species-articuno fixtures - covered in legendary task"
}
```

(The second test is a stub-skip — full legendary fixture build comes in Task 13. The first test is the contract for the new builder.)

- [ ] **Step 3: Run to verify it fails**

Run: `bats tests/test-encounter-pool.bats -f "type-derived"`
Expected: FAIL — `encounter_build_pool testbiome` either errors (wrong signature) or returns empty.

- [ ] **Step 4: Rewrite `encounter_build_pool`**

Replace the existing `encounter_build_pool` function in `lib/encounter.bash` with:

```bash
# encounter_build_pool <biome_id>
# Emits a JSON object {tiers:{common:[],uncommon:[],rare:[],very_rare:[]}}
# where every entry is {species, min, max} (no pct). Type-derived: union
# species across biome.types[], filter out legendaries/mythicals,
# tier by capture_rate, expand evolution chain stages, dedup.
encounter_build_pool() {
    local biome_id="$1"
    if ! command -v biome_types_for > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi

    # 1. Union species across biome.types[].
    local types_list species_union='[]'
    types_list="$(biome_types_for "$biome_id")" || return 1
    local t
    while IFS= read -r t; do
        [[ -z "$t" ]] && continue
        local type_body
        type_body="$(pokeapi_get "type/$t")" || return 1
        species_union="$(jq -c --argjson e "$(jq -c '[.pokemon[].pokemon.name]' <<< "$type_body")" \
            '. + $e | unique' <<< "$species_union")"
    done <<< "$types_list"

    # 2. For each species: filter legendary/mythical; classify by capture_rate.
    local base='[]'
    local sp
    while IFS= read -r sp; do
        [[ -z "$sp" ]] && continue
        local spec
        spec="$(pokeapi_get "pokemon-species/$sp" 2>/dev/null)" || continue
        local is_leg is_myth cr
        is_leg="$(jq -r '.is_legendary // false' <<< "$spec")"
        is_myth="$(jq -r '.is_mythical // false' <<< "$spec")"
        [[ "$is_leg" == "true" || "$is_myth" == "true" ]] && continue
        cr="$(jq -r '.capture_rate // 45' <<< "$spec")"
        local tier tier_idx
        tier="$(encounter_tier_for_capture_rate "$cr")"
        tier_idx=-1
        local i
        for i in 0 1 2 3; do
            [[ "${ENCOUNTER_TIERS[$i]}" == "$tier" ]] && tier_idx=$i && break
        done
        base="$(jq -c --arg sp "$sp" --argjson ti "$tier_idx" \
            '. + [{species:$sp, tier_idx:$ti}]' <<< "$base")"
    done < <(jq -r '.[]' <<< "$species_union")

    # 3. Walk evolution chain per root species: expand stages, shift tier.
    local flat='[]'
    local n
    n="$(jq 'length' <<< "$base")"
    local seen_chains='[]'
    for (( i=0; i<n; i++ )); do
        local entry sp tier_idx
        entry="$(jq -c ".[$i]" <<< "$base")"
        sp="$(jq -r '.species' <<< "$entry")"
        tier_idx="$(jq -r '.tier_idx' <<< "$entry")"

        local spec chain_url chain_id
        spec="$(pokeapi_get "pokemon-species/$sp" 2>/dev/null)" || continue
        chain_url="$(jq -r '.evolution_chain.url' <<< "$spec")"
        [[ -z "$chain_url" || "$chain_url" == "null" ]] && {
            # No chain: just add the species at root level range.
            flat="$(jq -c --arg s "$sp" --argjson t "$tier_idx" \
                '. + [{species:$s, min:5, max:15, tier_idx:$t}]' <<< "$flat")"
            continue
        }
        chain_id="$(basename -- "${chain_url%/}")"

        # Skip if we've already processed this chain (multiple type-union
        # members can share a chain).
        if jq -e --arg c "$chain_id" 'index($c)' <<< "$seen_chains" > /dev/null; then
            continue
        fi
        seen_chains="$(jq -c --arg c "$chain_id" '. + [$c]' <<< "$seen_chains")"

        local chain stages
        chain="$(pokeapi_get "evolution-chain/$chain_id" 2>/dev/null)" || continue
        stages="$(encounter_walk_chain "$chain")"

        # Find the root tier_idx for this chain (use the species we're
        # iterating from as the anchor; tier shifts forward per stage).
        local stage_entries
        stage_entries="$(jq -c \
            --argjson root_idx "$tier_idx" --arg anchor "$sp" --argjson stages "$stages" '
            ($stages | map(.species) | index($anchor)) as $anchor_stage
            | $stages
            | sort_by(.stage_idx)
            | reduce .[] as $s (
                {expanded: [], by_idx: {}};
                ($s.stage_idx - ($anchor_stage // 0)) as $offset
                | (if $s.stage_idx == 0 then 5 else
                       (.by_idx[(($s.stage_idx - 1)|tostring)] // 15) + 1
                   end) as $emin_pre
                | (if $s.min_level_evo != null and $s.stage_idx > 0 then
                       $s.min_level_evo
                   else $emin_pre end) as $emin
                | ($emin + 10) as $emax
                | ([$root_idx + $offset, 3] | map(if . < 0 then 0 else . end) | min) as $tidx
                | .expanded += [{
                    species: $s.species, min: $emin, max: $emax, tier_idx: $tidx
                  }]
                | .by_idx[($s.stage_idx|tostring)] = $emax
              )
            | .expanded
        ' <<< 'null')"
        flat="$(jq -c --argjson e "$stage_entries" '. + $e' <<< "$flat")"
    done

    # 4. Collision dedup: same species in multiple tiers -> keep min tier_idx.
    local deduped
    deduped="$(jq -c '
        group_by(.species)
        | map(
            (min_by(.tier_idx)) as $win
            | {
                species: $win.species,
                min: ([.[] | select(.tier_idx == $win.tier_idx) | .min] | min),
                max: ([.[] | select(.tier_idx == $win.tier_idx) | .max] | max),
                tier_idx: $win.tier_idx
              }
          )
    ' <<< "$flat")"

    # 5. Bucket into tier arrays.
    jq -c --argjson tiers '["common","uncommon","rare","very_rare"]' '
        ($tiers | map({(.) : []}) | add) as $empty
        | reduce .[] as $e ($empty;
            ($tiers[$e.tier_idx]) as $name
            | .[$name] += [{species: $e.species, min: $e.min, max: $e.max}]
          )
        | {tiers: .}
    ' <<< "$deduped"
}
```

- [ ] **Step 5: Run to verify the contract test passes**

Run: `bats tests/test-encounter-pool.bats -f "type-derived"`
Expected: PASS.

Run the full file:

Run: `bats tests/test-encounter-pool.bats`
Expected: some legacy tests will FAIL (they pass an areas array, not a biome_id). Those are fixed in Task 7.

- [ ] **Step 6: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats tests/fixtures/
git commit -m "pokidle: rewrite encounter_build_pool to derive pool from biome types

Takes a biome_id, fetches /type/<t> per biome.types[], unions species,
filters out legendaries/mythicals, tiers by capture_rate, expands
evolution chain stages once per unique chain. Replaces area+chance%
classification."
```

---

## Task 7: Update `rebuild-pool` + legacy tests for new `encounter_build_pool` signature

**Files:**
- Modify: `pokidle` (`pokidle_rebuild_pool` function)
- Modify: `tests/test-encounter-pool.bats` (drop or fix areas-based tests)
- Modify: `tests/test-cli.bats` if it stubs `rebuild-pool`

- [ ] **Step 1: Locate and update `pokidle_rebuild_pool`**

In `pokidle`, replace `pokidle_rebuild_pool`:

```bash
pokidle_rebuild_pool() {
    local target="${1-}"
    local biomes
    if [[ -n "$target" ]]; then
        biomes="$target"
    else
        biomes="$(biome_ids)"
        rm -rf -- "$POKIDLE_CACHE_DIR/pools"
    fi
    local b
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        local pool
        pool="$(encounter_build_pool "$b")" || {
            printf 'rebuild-pool: build failed for %s\n' "$b" >&2
            continue
        }
        encounter_pool_save "$b" "$pool"
        local c u r v
        c="$(jq '.tiers.common    | length' <<< "$pool")"
        u="$(jq '.tiers.uncommon  | length' <<< "$pool")"
        r="$(jq '.tiers.rare      | length' <<< "$pool")"
        v="$(jq '.tiers.very_rare | length' <<< "$pool")"
        printf 'rebuilt pool: %s (common=%s uncommon=%s rare=%s very_rare=%s)\n' \
            "$b" "$c" "$u" "$r" "$v"
    done <<< "$biomes"
}
```

- [ ] **Step 2: Drop / replace legacy `build_pool` tests**

In `tests/test-encounter-pool.bats`, remove or rewrite the `build_pool: treecko area produces v2 tier shape` test (now replaced by the `type-derived` test). Same for any test passing `'["rustboro-route-area"]'` to `encounter_build_pool`.

- [ ] **Step 3: Run full pool test file**

Run: `bats tests/test-encounter-pool.bats`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add pokidle tests/test-encounter-pool.bats
git commit -m "pokidle: rebuild-pool now passes biome_id to encounter_build_pool

Drops the per-biome biome-areas read step: the new builder asks for /type
directly. Updates legacy pool tests to the new signature."
```

---

## Task 8: Add held-item type table; rewrite `encounter_roll_item`

**Files:**
- Modify: `lib/encounter.bash` (add `ENCOUNTER_HELD_ITEMS_BY_TYPE`, `ENCOUNTER_HELD_ITEMS_GENERIC`; rewrite `encounter_roll_item`)
- Test: extend `tests/test-encounter-rolls.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-rolls.bats`:

```bash
@test "encounter_roll_item: forest biome rolls a typed or generic held item" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib biome
    load_lib encounter
    # Stub pokeapi to avoid /item fetch.
    pokeapi_get() {
        # Return minimal item JSON; sprite_url empty.
        printf '{"sprites":{"default":""}}'
    }
    export -f pokeapi_get
    local out item
    out="$(encounter_roll_item forest)"
    item="$(jq -r '.item' <<< "$out")"
    # Forest types: grass, bug, poison, fairy. Expected member sample:
    case "$item" in
        miracle-seed|meadow-plate|rose-incense|rindo-berry|\
        silver-powder|insect-plate|shed-shell|tanga-berry|\
        poison-barb|toxic-plate|black-sludge|kebia-berry|\
        pixie-plate|roseli-berry|\
        leftovers|shell-bell|lucky-egg|amulet-coin|\
        smoke-ball|soothe-bell|exp-share|everstone) : ;;
        *) printf 'unexpected item for forest biome: %s\n' "$item" >&2; return 1 ;;
    esac
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/test-encounter-rolls.bats -f "forest biome rolls"`
Expected: FAIL — `encounter_roll_item` currently reads `biome.item_pool` (which no longer exists).

- [ ] **Step 3: Add the table + rewrite the roller**

In `lib/encounter.bash`, near the top (after the constant declarations), add:

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
    [steel]="metal-coat iron-plate metal-powder"
    [fairy]="pixie-plate roseli-berry"
)

declare -ga ENCOUNTER_HELD_ITEMS_GENERIC=(
    "leftovers" "shell-bell" "lucky-egg" "amulet-coin"
    "smoke-ball" "soothe-bell" "exp-share" "everstone"
)
```

Replace `encounter_roll_item`:

```bash
# encounter_roll_item <biome_id>
# Emits {"item": "<name>", "sprite_url": "<url|empty>"}.
encounter_roll_item() {
    local biome_id="$1"
    if ! command -v biome_types_for > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/biome.bash"
    fi
    local types_list pool=() seen=""
    types_list="$(biome_types_for "$biome_id")" || return 1
    local t item
    while IFS= read -r t; do
        [[ -z "$t" ]] && continue
        for item in ${ENCOUNTER_HELD_ITEMS_BY_TYPE[$t]:-}; do
            [[ "$seen" == *"|$item|"* ]] && continue
            pool+=("$item")
            seen+="|$item|"
        done
    done <<< "$types_list"
    for item in "${ENCOUNTER_HELD_ITEMS_GENERIC[@]}"; do
        [[ "$seen" == *"|$item|"* ]] && continue
        pool+=("$item")
        seen+="|$item|"
    done
    local n="${#pool[@]}"
    (( n > 0 )) || { printf 'encounter_roll_item: empty pool for biome %s\n' "$biome_id" >&2; return 1; }
    local idx=$((RANDOM % n))
    local name="${pool[$idx]}"
    local item_json sprite
    item_json="$(pokeapi_get "item/$name")" || return 1
    sprite="$(jq -r '.sprites.default // ""' <<< "$item_json")"
    jq -n --arg item "$name" --arg sprite "$sprite" '{item: $item, sprite_url: $sprite}'
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bats tests/test-encounter-rolls.bats -f "forest biome rolls"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-rolls.bats
git commit -m "pokidle: derive held-item pool from biome.types + hardcoded table

Adds ENCOUNTER_HELD_ITEMS_BY_TYPE keyed by all 18 PokeAPI types plus a
generic always-available pool. encounter_roll_item now unions the
per-type items + generics for the active biome — replaces the
config-file item_pool that's gone."
```

---

## Task 9: Auto-derive berry pool inside `encounter_build_pool`

**Files:**
- Modify: `lib/encounter.bash` (extend `encounter_build_pool` to attach `berries`; bump pool schema to 3; rewrite `encounter_roll_held_berry` to read from pool)
- Test: extend `tests/test-encounter-pool.bats` + `tests/test-encounter-rolls.bats`
- Fixtures: add `berry-pecha.json`, `berry-cheri.json`, `berry-chesto.json`, `berry-limit-100.json`

- [ ] **Step 1: Create the fixtures**

`tests/fixtures/berry-limit-100.json`:

```json
{ "count": 3, "results": [
    { "name": "cheri" }, { "name": "chesto" }, { "name": "pecha" }
] }
```

`tests/fixtures/berry-cheri.json`:

```json
{ "name": "cheri", "natural_gift_type": { "name": "fire" } }
```

`tests/fixtures/berry-chesto.json`:

```json
{ "name": "chesto", "natural_gift_type": { "name": "water" } }
```

`tests/fixtures/berry-pecha.json`:

```json
{ "name": "pecha", "natural_gift_type": { "name": "electric" } }
```

- [ ] **Step 2: Write the failing test**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "build_pool: attaches berries derived from natural_gift_type" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    export POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR POKIDLE_CONFIG_DIR
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cat > "$POKIDLE_CONFIG_DIR/biomes.json" <<EOF
{ "biomes": [
    { "id": "watery", "label": "Watery", "types": ["water"] }
] }
EOF
    load_lib biome
    load_lib encounter
    stub_pokeapi
    run encounter_build_pool watery
    [ "$status" -eq 0 ]
    local has_b
    has_b="$(jq 'has("berries") and (.berries | type == "array")' <<< "$output")"
    [ "$has_b" = "true" ]
    # chesto's natural_gift_type is water → included.
    local has_chesto
    has_chesto="$(jq -r '.berries | index("chesto") != null' <<< "$output")"
    [ "$has_chesto" = "true" ]
    # cheri is fire → excluded.
    local has_cheri
    has_cheri="$(jq -r '.berries | index("cheri") != null' <<< "$output")"
    [ "$has_cheri" = "false" ]
}

@test "pool save: schema version is 3" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR
    load_lib encounter
    encounter_pool_save fakebiome '{"tiers":{"common":[],"uncommon":[],"rare":[],"very_rare":[]},"berries":[]}'
    local sch
    sch="$(jq -r '.schema' "$POKIDLE_CACHE_DIR/pools/fakebiome.json")"
    [ "$sch" = "3" ]
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `bats tests/test-encounter-pool.bats -f "berries"`
Run: `bats tests/test-encounter-pool.bats -f "schema version is 3"`
Expected: FAIL.

- [ ] **Step 4: Extend `encounter_build_pool` to attach berries**

At the end of `encounter_build_pool`, after the tier-bucket emission, instead of emitting `{tiers: .}`, pipe through one more stage that collects berry names. Easier: do berry derivation as a separate step then merge.

After the existing tier-bucket emission, add (replacing the final `jq` invocation):

```bash
    local tiered
    tiered="$(jq -c --argjson tiers '["common","uncommon","rare","very_rare"]' '
        ($tiers | map({(.) : []}) | add) as $empty
        | reduce .[] as $e ($empty;
            ($tiers[$e.tier_idx]) as $name
            | .[$name] += [{species: $e.species, min: $e.min, max: $e.max}]
          )
    ' <<< "$deduped")"

    # 6. Derive berries by natural_gift_type intersection with biome.types.
    local berries='[]' berry_list
    berry_list="$(pokeapi_get "berry?limit=100" | jq -r '.results[].name')"
    local berry types_set
    types_set="$(jq -c --argjson t "$(printf '%s\n' $(biome_types_for "$biome_id") | jq -R . | jq -s .)" \
        '$t' <<< 'null')"
    while IFS= read -r berry; do
        [[ -z "$berry" ]] && continue
        local bj ngt
        bj="$(pokeapi_get "berry/$berry" 2>/dev/null)" || continue
        ngt="$(jq -r '.natural_gift_type.name // ""' <<< "$bj")"
        [[ -z "$ngt" ]] && continue
        if jq -e --arg t "$ngt" --argjson types "$types_set" '$types | index($t)' \
                <<< 'null' > /dev/null; then
            berries="$(jq -c --arg b "$berry" '. + [$b]' <<< "$berries")"
        fi
    done <<< "$berry_list"

    jq -c --argjson tiers "$tiered" --argjson berries "$berries" \
        '{tiers: $tiers, berries: $berries}'
```

Bump `encounter_pool_save` schema to 3:

```bash
encounter_pool_save() {
    local biome="$1" body_json="$2"
    local p
    p="$(encounter_pool_path "$biome")"
    mkdir -p -- "$(dirname -- "$p")"
    local body
    body="$(jq -c -n --arg b "$biome" --arg ts "$(date -u +%FT%TZ)" \
                  --argjson p "$body_json" '{
        biome: $b,
        built_at: $ts,
        schema: 3,
        tiers: $p.tiers,
        berries: ($p.berries // [])
    }')"
    printf '%s' "$body" > "$p"
}
```

- [ ] **Step 5: Rewrite `encounter_roll_held_berry` to read from pool**

Replace `encounter_roll_held_berry`:

```bash
encounter_roll_held_berry() {
    local biome_id="$1"
    local rate="${POKIDLE_BERRY_RATE:-15}"
    local roll=$((RANDOM % 100))
    if (( roll >= rate )); then
        printf 'null'
        return
    fi
    local p
    p="$(encounter_pool_path "$biome_id")"
    [[ -f "$p" ]] || { printf 'null'; return; }
    local berries n idx
    mapfile -t berries < <(jq -r '.berries[]?' "$p")
    n="${#berries[@]}"
    (( n > 0 )) || { printf 'null'; return; }
    idx=$((RANDOM % n))
    printf '%s' "${berries[$idx]}"
}
```

- [ ] **Step 6: Run to verify it passes**

Run: `bats tests/test-encounter-pool.bats -f "berries"`
Run: `bats tests/test-encounter-pool.bats -f "schema version is 3"`
Expected: PASS.

Run: `bats tests/test-encounter-rolls.bats`
Expected: PASS (existing tests, plus the held-berry path that now reads from the saved pool). If a test pre-populated `biome.berry_pool`, update it to write a pool fixture instead.

- [ ] **Step 7: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats tests/fixtures/berry-*.json
git commit -m "pokidle: bake berry pool into pool file (schema 3)

berries[] derives from PokeAPI natural_gift_type intersected with
biome.types[]. encounter_roll_held_berry reads from the pool file now.
Removes the dependence on config/biomes.json berry_pool field."
```

---

## Task 10: Extend `biome_validate` with berry + held-item coverage checks

**Files:**
- Modify: `lib/biome.bash`
- Modify: `tests/test-biome-config.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-biome-config.bats`:

```bash
@test "biome_validate: every held-item-type-key is covered by some biome" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib biome
    load_lib encounter
    run biome_validate
    [ "$status" -eq 0 ]
}

@test "biome_validate: fails when held-item-type key is uncovered" {
    local tmp
    tmp="$(mktemp -d)"
    # Drop psychic from ruins → no biome covers psychic → held-item key uncovered.
    jq '(.biomes[] | select(.id=="ruins") | .types) |= map(select(. != "psychic"))' \
        "$REPO_ROOT/config/biomes.json" > "$tmp/biomes.json"
    POKIDLE_CONFIG_DIR="$tmp" POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CONFIG_DIR POKIDLE_REPO_ROOT
    load_lib biome
    load_lib encounter
    run biome_validate
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run to verify they may pass already (type coverage subsumes held-item key coverage)**

Run: `bats tests/test-biome-config.bats -f "held-item"`
Expected: One passes if type coverage already implies item coverage; the second fails (because dropping psychic breaks type coverage at the basic check before this one runs). That's acceptable — the failing-uncovered test exercises the type-coverage path already. Refine if needed: pick a type only used by one biome that **isn't** in `BIOME_PRIMARY_TYPES`... but every PokeAPI type is in that list. So the held-item check is a subset of the type-coverage check.

**Decision:** the type-coverage check in Task 2 is *also* the held-item coverage check (`ENCOUNTER_HELD_ITEMS_BY_TYPE` keys == PokeAPI types). The new tests pass without changes. Mark the held-item-key check as documented in `biome_validate` comments rather than a separate validation.

- [ ] **Step 3: Add documentation comment to `biome_validate`**

In `lib/biome.bash`, above `biome_validate`, add:

```bash
# Validation rules:
#   1. Top-level .biomes array present.
#   2. Each biome has id, label, types[≥1].
#   3. No duplicate ids.
#   4. Every BIOME_PRIMARY_TYPES entry is covered by ≥1 biome's types.
#      This subsumes coverage of ENCOUNTER_HELD_ITEMS_BY_TYPE keys (same
#      18 type names) and is a necessary condition for full berry
#      coverage (every berry's natural_gift_type is one of these 18).
```

- [ ] **Step 4: Run tests**

Run: `bats tests/test-biome-config.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/biome.bash tests/test-biome-config.bats
git commit -m "pokidle: document type-coverage subsumes berry+item coverage"
```

---

## Task 11: Create `lib/legendary.bash` with roster + roll helper

**Files:**
- Create: `lib/legendary.bash`
- Test: create `tests/test-legendary.bats`

- [ ] **Step 1: Write the failing test**

Create `tests/test-legendary.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib legendary
}

@test "LEGENDARY_SPECIES: contains canonical gen-1 legendaries" {
    local got
    got=" ${LEGENDARY_SPECIES[*]} "
    [[ "$got" == *" articuno "* ]]
    [[ "$got" == *" zapdos "* ]]
    [[ "$got" == *" moltres "* ]]
    [[ "$got" == *" mewtwo "* ]]
    [[ "$got" == *" mew "* ]]
}

@test "LEGENDARY_SPECIES: contains gen-7+ entries" {
    local got
    got=" ${LEGENDARY_SPECIES[*]} "
    [[ "$got" == *" tapu-koko "* ]]
    [[ "$got" == *" zacian "* ]]
}

@test "legendary_roll_species: prints a name from LEGENDARY_SPECIES" {
    local out
    out="$(legendary_roll_species)"
    local got
    got=" ${LEGENDARY_SPECIES[*]} "
    [[ "$got" == *" $out "* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/test-legendary.bats`
Expected: FAIL (file doesn't load).

- [ ] **Step 3: Create `lib/legendary.bash`**

```bash
#!/usr/bin/env bash
# lib/legendary.bash — static legendary roster + roll helper.

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

legendary_roll_species() {
    local n="${#LEGENDARY_SPECIES[@]}"
    (( n > 0 )) || { printf 'legendary_roll_species: empty roster\n' >&2; return 1; }
    printf '%s' "${LEGENDARY_SPECIES[$((RANDOM % n))]}"
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bats tests/test-legendary.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/legendary.bash tests/test-legendary.bats
git commit -m "pokidle: add lib/legendary.bash with hardcoded roster

~90 species across gens 1-8. Roster is static (PokeAPI versions don't
re-flag legendaries); future gens are an append-only change."
```

---

## Task 12: Add `legendary_build_encounter` helper

**Files:**
- Modify: `lib/legendary.bash`
- Test: extend `tests/test-legendary.bats`
- Fixtures: add `pokemon-articuno.json`, `pokemon-species-articuno.json`

- [ ] **Step 1: Create fixtures**

`tests/fixtures/pokemon-articuno.json` (minimal — adapt from existing pokemon fixtures, set `id`, `stats[]`, `sprites`, `abilities`, `moves`, `types`).

`tests/fixtures/pokemon-species-articuno.json`:

```json
{
    "name": "articuno",
    "capture_rate": 3,
    "base_happiness": 0,
    "gender_rate": -1,
    "is_legendary": true,
    "is_mythical": false
}
```

- [ ] **Step 2: Write the failing test**

Append to `tests/test-legendary.bats`:

```bash
@test "legendary_build_encounter: returns encounter JSON with all required fields" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_LEVEL_MIN=50
    POKIDLE_LEGENDARY_LEVEL_MAX=70
    export POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_LEVEL_MIN POKIDLE_LEGENDARY_LEVEL_MAX
    load_lib encounter
    load_lib legendary
    stub_pokeapi
    local enc
    enc="$(legendary_build_encounter articuno forest)"
    [ -n "$enc" ]
    # Required fields.
    local sp lvl shiny is_leg
    sp="$(jq -r '.species' <<< "$enc")"
    lvl="$(jq -r '.level' <<< "$enc")"
    shiny="$(jq -r '.shiny' <<< "$enc")"
    is_leg="$(jq -r '.is_legendary' <<< "$enc")"
    [ "$sp" = "articuno" ]
    [ "$lvl" -ge 50 ] && [ "$lvl" -le 70 ]
    [[ "$shiny" =~ ^[01]$ ]]
    [ "$is_leg" = "true" ]
    # No held berry (legendaries don't carry biome berries).
    local berry
    berry="$(jq -r '.held_berry' <<< "$enc")"
    [ "$berry" = "null" ]
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `bats tests/test-legendary.bats -f "build_encounter"`
Expected: FAIL — function doesn't exist.

- [ ] **Step 4: Add the helper**

Append to `lib/legendary.bash`:

```bash
# legendary_build_encounter <species> <biome_id>
# Emits a JSON encounter object ready for db_insert_encounter (after
# adding session_id, encountered_at, sprite_path). Always sets
# .is_legendary=true and .held_berry=null.
legendary_build_encounter() {
    local sp="$1" biome="$2"
    if ! command -v encounter_natures_list > /dev/null; then
        # shellcheck disable=SC1091
        source "${POKIDLE_REPO_ROOT}/lib/encounter.bash"
    fi
    local poke
    poke="$(pokeapi_get "pokemon/$sp")" || return 1
    local dex_id sprite_url sprite_url_shiny
    dex_id="$(jq -r '.id' <<< "$poke")"
    sprite_url="$(jq -r '.sprites.front_default // ""' <<< "$poke")"
    sprite_url_shiny="$(jq -r '.sprites.front_shiny // ""' <<< "$poke")"

    local lo="${POKIDLE_LEGENDARY_LEVEL_MIN:-50}"
    local hi="${POKIDLE_LEGENDARY_LEVEL_MAX:-70}"
    local level ivs evs
    level="$(encounter_roll_level "$lo" "$hi")"
    ivs="$(encounter_roll_ivs)"
    evs="$(encounter_ev_split "$((RANDOM % 511))")"

    local natures n nature mods
    mapfile -t natures < <(encounter_natures_list)
    n="${#natures[@]}"
    nature="${natures[$((RANDOM % n))]}"
    mods="$(encounter_nature_mods "$nature")" || return 1

    local ability_obj ability is_hidden
    ability_obj="$(encounter_roll_ability "$sp")" || return 1
    ability="$(jq -r '.name' <<< "$ability_obj")"
    is_hidden="$(jq -r 'if .is_hidden then 1 else 0 end' <<< "$ability_obj")"

    local moves_json gender shiny
    moves_json="$(encounter_roll_moves "$sp" "$level")" || return 1
    gender="$(encounter_roll_gender "$sp")" || return 1
    shiny="$(encounter_roll_shiny)"

    local friendship
    friendship="$(encounter_roll_friendship "$sp")" || return 1

    local base_stats stats
    base_stats="$(jq -c '.stats' <<< "$poke")"
    stats="$(encounter_compute_all_stats "$base_stats" "$ivs" "$evs" "$level" "$mods")" || return 1

    local final_sprite="$sprite_url"
    [[ "$shiny" == "1" && -n "$sprite_url_shiny" ]] && final_sprite="$sprite_url_shiny"

    local ivs_json evs_json stats_json
    ivs_json="[$(printf '%s,' $ivs | sed 's/,$//')]"
    evs_json="[$(printf '%s,' $evs | sed 's/,$//')]"
    stats_json="[$(printf '%s,' $stats | sed 's/,$//')]"

    jq -n \
        --arg sp "$sp" --argjson dex "$dex_id" --argjson lvl "$level" \
        --arg nature "$nature" --arg ability "$ability" --argjson hidden "$is_hidden" \
        --arg gender "$gender" --argjson shiny "$shiny" \
        --argjson friendship "$friendship" \
        --argjson ivs "$ivs_json" --argjson evs "$evs_json" --argjson stats "$stats_json" \
        --argjson moves "$moves_json" --arg sprite "$final_sprite" '{
            species: $sp, dex_id: $dex, level: $lvl,
            nature: $nature, ability: $ability, is_hidden_ability: $hidden,
            gender: $gender, shiny: $shiny, held_berry: null,
            friendship: $friendship,
            ivs: $ivs, evs: $evs, stats: $stats,
            moves: $moves, sprite_url: $sprite,
            is_legendary: true
        }'
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `bats tests/test-legendary.bats`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/legendary.bash tests/test-legendary.bats tests/fixtures/pokemon-articuno.json tests/fixtures/pokemon-species-articuno.json
git commit -m "pokidle: add legendary_build_encounter helper

Mirrors encounter_roll_pokemon but with fixed level range
(POKIDLE_LEGENDARY_LEVEL_{MIN,MAX}, default 50-70), null held_berry,
and is_legendary=true marker for the notifier."
```

---

## Task 13: Add `pokidle tick legendary` subcommand

**Files:**
- Modify: `pokidle` (add `pokidle_tick_legendary`, wire dispatch)
- Test: extend `tests/test-cli.bats` or create a new test in `tests/test-legendary.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-legendary.bats`:

```bash
@test "tick legendary --dry-run: rolls but does not insert" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_CHANCE=100   # guarantee a spawn
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_CHANCE POKIDLE_NO_NOTIFY
    # Need a biome session.
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700000000);"
    run "$REPO_ROOT/pokidle" tick legendary --dry-run
    [ "$status" -eq 0 ]
    local count
    count="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$count" = "0" ]
}

@test "tick legendary --no-dry-run: inserts encounter when chance is 100" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_CHANCE=100
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_CHANCE POKIDLE_NO_NOTIFY
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700000000);"
    run "$REPO_ROOT/pokidle" tick legendary --no-dry-run --json
    [ "$status" -eq 0 ]
    local count is_in_roster sp
    count="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$count" = "1" ]
    sp="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT species FROM encounters LIMIT 1;")"
    # species is one of the legendaries.
    load_lib legendary
    is_in_roster=0
    local s
    for s in "${LEGENDARY_SPECIES[@]}"; do
        [[ "$s" == "$sp" ]] && is_in_roster=1 && break
    done
    [ "$is_in_roster" = "1" ]
}

@test "tick legendary: no spawn when chance is 0" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_CHANCE=0
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_CHANCE POKIDLE_NO_NOTIFY
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700000000);"
    run "$REPO_ROOT/pokidle" tick legendary --no-dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"no spawn"* ]]
    local count
    count="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$count" = "0" ]
}
```

(These tests hit the live PokeAPI cache for pokemon/species data. If the cache isn't warm in CI, they'll be slow; we accept that trade-off since the legendary roster is small.)

- [ ] **Step 2: Run to verify they fail**

Run: `bats tests/test-legendary.bats -f "tick legendary"`
Expected: FAIL — subcommand doesn't exist.

- [ ] **Step 3: Add `pokidle_tick_legendary`**

In `pokidle`, after the `pokidle_tick_evolve` function, add:

```bash
pokidle_tick_legendary() {
    local dry_run=1 no_notify=0 emit_json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)    dry_run=1; shift ;;
            --no-dry-run) dry_run=0; shift ;;
            --no-notify)  no_notify=1; shift ;;
            --json)       emit_json=1; shift ;;
            *) printf 'tick legendary: unknown flag %s\n' "$1" >&2; return 2 ;;
        esac
    done

    db_init

    local active sid biome
    active="$(db_active_biome_session)"
    if [[ -z "$active" ]]; then
        biome="$(biome_pick_random)"
        sid="$(db_open_biome_session "$biome" "$(date +%s)")"
    else
        IFS=$'\t' read -r sid biome _ <<< "$active"
    fi

    local chance="${POKIDLE_LEGENDARY_CHANCE:-3}"
    if (( RANDOM % 100 >= chance )); then
        if (( emit_json )); then
            jq -n '{spawned: false}'
        else
            printf 'legendary: no spawn this tick (chance=%s)\n' "$chance"
        fi
        return 0
    fi

    local species enc sprite_url sprite_path=""
    species="$(legendary_roll_species)"
    enc="$(legendary_build_encounter "$species" "$biome")" || return 1
    sprite_url="$(jq -r '.sprite_url // ""' <<< "$enc")"
    if [[ -n "$sprite_url" && "$no_notify" == "0" ]]; then
        sprite_path="$POKIDLE_CACHE_DIR/sprites/$species.png"
        mkdir -p -- "$(dirname -- "$sprite_path")"
        [[ -f "$sprite_path" ]] || curl -sS -o "$sprite_path" "$sprite_url" || sprite_path=""
    fi

    local label enc_with_meta
    label="$(biome_get "$biome" | jq -r '.label')"
    enc_with_meta="$(jq -c \
        --arg label "$label" --arg sp "$sprite_path" '
        . + {biome_label: $label, sprite_path: $sp}
    ' <<< "$enc")"

    if (( dry_run == 0 )); then
        local enc_for_db
        enc_for_db="$(jq -c \
            --argjson sid "$sid" --argjson ts "$(date +%s)" --arg sp "$sprite_path" '
            . + {session_id: $sid, encountered_at: $ts, sprite_path: $sp}
        ' <<< "$enc")"
        db_insert_encounter "$enc_for_db"
    fi

    if (( no_notify == 0 )) && [[ "${POKIDLE_NOTIFY_POKEMON:-1}" == "1" ]]; then
        notify_pokemon "$enc_with_meta"
    fi

    if (( emit_json )); then
        printf '%s\n' "$enc_with_meta"
    else
        jq -r '"legendary: \(.species) lvl \(.level) [\(.biome_label)]"' <<< "$enc_with_meta"
    fi
}
```

Source the new lib at the top of `pokidle`:

```bash
# shellcheck source=lib/legendary.bash
source "$POKIDLE_REPO_ROOT/lib/legendary.bash"
```

(Place after `lib/evolution.bash`.)

Wire dispatch in `pokidle_tick`:

```bash
        legendary)
            pokidle_tick_legendary "$@"
            return
            ;;
```

(Add to the existing dispatch case after `evolve)`.)

Update help text:

```
  tick <kind> [flags]      Run a single roll now (default: dry-run, no DB write)
                            kind: pokemon | item | level | friendship | evolve | legendary
```

- [ ] **Step 4: Run to verify they pass**

Run: `bats tests/test-legendary.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pokidle tests/test-legendary.bats
git commit -m "pokidle: add tick legendary subcommand

Daily-cadence tick. Per-fire chance gated by POKIDLE_LEGENDARY_CHANCE
(default 3%). On hit picks a random species from LEGENDARY_SPECIES,
builds an encounter via legendary_build_encounter, inserts under the
active biome session, notifies (via the existing notify_pokemon path —
extended in next commit)."
```

---

## Task 14: Wire daemon-side legendary timer

**Files:**
- Modify: `pokidle` (`pokidle_daemon` function)
- Test: extend `tests/test-daemon.bats` if it has a fast-mode smoke test

- [ ] **Step 1: Locate the daemon state-load + main-loop blocks**

`grep -n 'next_evolve' pokidle` — modify the two adjacent locations: the state restoration block (`pokidle:145-151`) and the main loop block (`pokidle:192-200`).

- [ ] **Step 2: Write the failing test**

Append to `tests/test-daemon.bats` (or wherever the daemon smoke test lives):

```bash
@test "daemon: persists last_legendary_tick_target on first start" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_TICK_FAST=1
    POKIDLE_NO_NOTIFY=1
    POKIDLE_LEGENDARY_CHANCE=0     # don't spawn during the smoke test
    POKIDLE_LEGENDARY_INTERVAL=86400
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_TICK_FAST POKIDLE_NO_NOTIFY POKIDLE_LEGENDARY_CHANCE POKIDLE_LEGENDARY_INTERVAL
    # Boot daemon for a couple seconds in background.
    timeout 5 "$REPO_ROOT/pokidle" daemon >/dev/null 2>&1 || true
    local val
    val="$(sqlite3 "$POKIDLE_DB_PATH" \
        "SELECT value FROM daemon_state WHERE key='last_legendary_tick_target';")"
    [ -n "$val" ]
    [[ "$val" =~ ^[0-9]+$ ]]
}
```

(Adjust `timeout` / startup pattern to match the existing daemon test if there is one. If the existing daemon smoke test scaffolding is different, reuse it.)

- [ ] **Step 3: Run to verify it fails**

Run: `bats tests/test-daemon.bats -f "last_legendary"`
Expected: FAIL — daemon doesn't set that state key yet.

- [ ] **Step 4: Wire the legendary timer in `pokidle_daemon`**

State restoration (after the `next_evolve` block):

```bash
    local next_legendary
    next_legendary="$(db_state_get last_legendary_tick_target)"
    if [[ -z "$next_legendary" || "$next_legendary" -le "$now" ]]; then
        next_legendary="$(_pokidle_next_tick_target "$now" "${POKIDLE_LEGENDARY_INTERVAL:-86400}")"
        db_state_set last_legendary_tick_target "$next_legendary" || \
            printf 'daemon: persist last_legendary_tick_target failed (continuing)\n' >&2
    fi
```

Main loop (after the `next_evolve` block):

```bash
        if (( now >= next_legendary )); then
            if [[ "${POKIDLE_LEGENDARY_ENABLED:-1}" == "1" ]]; then
                pokidle_tick legendary --no-dry-run --json > /dev/null \
                    || printf 'daemon: legendary tick failed (continuing)\n' >&2
            fi
            next_legendary="$(_pokidle_next_tick_target "$now" "${POKIDLE_LEGENDARY_INTERVAL:-86400}")"
            db_state_set last_legendary_tick_target "$next_legendary" || \
                printf 'daemon: persist last_legendary_tick_target failed (continuing)\n' >&2
        fi
```

Sleep budget (extend the existing chain):

```bash
        (( next_legendary < next_event )) && next_event=$next_legendary
```

- [ ] **Step 5: Run to verify it passes**

Run: `bats tests/test-daemon.bats -f "last_legendary"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pokidle tests/test-daemon.bats
git commit -m "pokidle: wire daemon legendary timer

7th timer (POKIDLE_LEGENDARY_INTERVAL=86400, gated by per-fire
POKIDLE_LEGENDARY_CHANCE in the tick itself). State key
last_legendary_tick_target persists across daemon restarts."
```

---

## Task 15: Extend `notify_pokemon` with legendary urgency + sound

**Files:**
- Modify: `lib/notify.bash`
- Test: extend `tests/test-notify.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-notify.bats`:

```bash
@test "notify_pokemon: legendary encounter emits LEGENDARY prefix + critical urgency" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_REPO_ROOT POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
    local enc out
    enc='{"species":"articuno","level":60,"nature":"timid","ability":"pressure","gender":"genderless","shiny":0,"held_berry":null,"biome_label":"Ice","stats":[210,180,200,240,220,230],"moves":["ice-beam"],"sprite_path":"","is_legendary":true}'
    out="$(notify_pokemon "$enc")"
    [[ "$out" == *"LEGENDARY"* ]]
    [[ "$out" == *"URGENCY: critical"* ]]
}

@test "notify_pokemon: shiny+legendary stacks prefixes" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_REPO_ROOT POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
    local enc out
    enc='{"species":"articuno","level":60,"nature":"timid","ability":"pressure","gender":"genderless","shiny":1,"held_berry":null,"biome_label":"Ice","stats":[210,180,200,240,220,230],"moves":["ice-beam"],"sprite_path":"","is_legendary":true}'
    out="$(notify_pokemon "$enc")"
    [[ "$out" == *"SHINY"* ]]
    [[ "$out" == *"LEGENDARY"* ]]
}

@test "notify_pokemon: non-legendary unchanged" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_REPO_ROOT POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
    local enc out
    enc='{"species":"pidgey","level":3,"nature":"jolly","ability":"keen-eye","gender":"M","shiny":0,"held_berry":null,"biome_label":"Plain","stats":[20,18,16,12,14,22],"moves":["tackle"],"sprite_path":""}'
    out="$(notify_pokemon "$enc")"
    [[ "$out" == *"URGENCY: normal"* ]]
    [[ "$out" != *"LEGENDARY"* ]]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats tests/test-notify.bats -f "LEGENDARY"`
Expected: FAIL.

- [ ] **Step 3: Update `notify_pokemon` + `_play_sound`**

In `lib/notify.bash`, update `notify_pokemon`:

```bash
notify_pokemon() {
    local enc="$1"
    local species level nature ability gender shiny held biome_label is_legendary
    species="$(jq -r '.species' <<< "$enc")"
    level="$(jq -r '.level' <<< "$enc")"
    nature="$(jq -r '.nature' <<< "$enc")"
    ability="$(jq -r '.ability' <<< "$enc")"
    gender="$(jq -r '.gender' <<< "$enc")"
    shiny="$(jq -r '.shiny' <<< "$enc")"
    held="$(jq -r '.held_berry // ""' <<< "$enc")"
    biome_label="$(jq -r '.biome_label // ""' <<< "$enc")"
    is_legendary="$(jq -r '.is_legendary // false' <<< "$enc")"

    local stats moves
    stats="$(jq -r '.stats | "HP \(.[0])  Atk \(.[1])  Def \(.[2])  SpA \(.[3])  SpD \(.[4])  Spe \(.[5])"' <<< "$enc")"
    moves="$(jq -r '.moves | join(", ")' <<< "$enc")"

    local sp_title nat_title abil_title
    sp_title="$(_titlecase_words "$species")"
    nat_title="$(_titlecase "$nature")"
    abil_title="$(_titlecase_words "$ability")"

    local prefix="" urgency="normal" sound_kind="encounter"
    if [[ "$shiny" == "1" && "$is_legendary" == "true" ]]; then
        prefix="[SHINY LEGENDARY ✨⚡] "
        urgency="${POKIDLE_NOTIFY_URGENCY_LEGENDARY:-critical}"
        sound_kind="legendary"
    elif [[ "$is_legendary" == "true" ]]; then
        prefix="[LEGENDARY ⚡] "
        urgency="${POKIDLE_NOTIFY_URGENCY_LEGENDARY:-critical}"
        sound_kind="legendary"
    elif [[ "$shiny" == "1" ]]; then
        prefix="[SHINY ✨] "
        urgency="${POKIDLE_NOTIFY_URGENCY_SHINY:-critical}"
        sound_kind="shiny"
    fi

    local title body icon
    title="${prefix}Lv.$level $sp_title"
    body="$biome_label  ·  $nat_title  ·  $abil_title"$'\n'"$stats"$'\n'"Moves: $moves"
    [[ -n "$held" && "$held" != "null" ]] && body+=$'\n'"Held: $held"

    icon="$(jq -r '.sprite_path // ""' <<< "$enc")"

    _emit "$title" "$body" "$urgency" "$icon"
    _play_sound "$sound_kind"
}
```

Update `_play_sound` to handle the `legendary` kind:

```bash
_play_sound() {
    local kind="$1"
    [[ "${POKIDLE_NO_SOUND:-0}" == "1" ]] && return 0
    local file=""
    case "$kind" in
        legendary)
            file="${POKIDLE_SOUND_LEGENDARY:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/legendary.ogg}"
            # Legendary sound plays unconditionally (ignores POKIDLE_SOUND policy).
            ;;
        shiny)
            file="${POKIDLE_SOUND_SHINY:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/shiny.ogg}"
            local policy="${POKIDLE_SOUND:-shiny}"
            case "$policy" in
                never) return 0 ;;
                shiny|always) ;;
                *) return 0 ;;
            esac
            ;;
        encounter)
            file="${POKIDLE_SOUND_ENCOUNTER:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/encounter.ogg}"
            local policy="${POKIDLE_SOUND:-shiny}"
            case "$policy" in
                never|shiny) return 0 ;;
                always) ;;
                *) return 0 ;;
            esac
            ;;
        *) return 0 ;;
    esac
    [[ -n "$file" && -f "$file" ]] || {
        # Legendary falls back to shiny then encounter.
        if [[ "$kind" == "legendary" ]]; then
            file="${POKIDLE_SOUND_SHINY:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/shiny.ogg}"
            [[ -f "$file" ]] || file="${POKIDLE_SOUND_ENCOUNTER:-${POKIDLE_DATA_DIR:-${POKIDLE_REPO_ROOT}/share}/sounds/encounter.ogg}"
        fi
        [[ -f "$file" ]] || return 0
    }
    if   command -v paplay >/dev/null; then paplay "$file" >/dev/null 2>&1 &
    elif command -v aplay  >/dev/null; then aplay  -q "$file" >/dev/null 2>&1 &
    fi
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bats tests/test-notify.bats`
Expected: PASS (all existing tests still pass; new tests pass).

- [ ] **Step 5: Commit**

```bash
git add lib/notify.bash tests/test-notify.bats
git commit -m "pokidle: notify_pokemon adds LEGENDARY prefix + urgency override

Reads optional .is_legendary from the encounter JSON. Legendaries get a
[LEGENDARY ⚡] prefix, critical urgency by default (override via
POKIDLE_NOTIFY_URGENCY_LEGENDARY), and play a dedicated sound
(POKIDLE_SOUND_LEGENDARY → fallback shiny → fallback encounter). Shiny
+ legendary stacks to [SHINY LEGENDARY ✨⚡]. Legendary sound plays
unconditionally (ignores POKIDLE_SOUND policy)."
```

---

## Task 16: Update `docs/notifications.md`

**Files:**
- Modify: `docs/notifications.md`

- [ ] **Step 1: Insert the legendary row + footnotes**

Replace the event table in `docs/notifications.md` with:

```markdown
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
```

Update the Global toggles table to add the legendary sound path:

```markdown
| `POKIDLE_SOUND_LEGENDARY`| share/sounds/legendary.ogg | path to legendary sound file              |
```

Also note in the prose that legendary spawns are gated by:

```markdown
## Legendary tick

`tick legendary` fires daily (`POKIDLE_LEGENDARY_INTERVAL=86400`, daemon-driven). Each fire rolls a per-tick chance gated by `POKIDLE_LEGENDARY_CHANCE` (default `3`, i.e. ~3% per day → ~1 spawn per ~33 days on average). Tunable; set to `0` to disable, `100` for guaranteed spawn (useful for testing). Spawns appear under the active biome session; the species is picked uniformly from the hardcoded `LEGENDARY_SPECIES` roster in `lib/legendary.bash`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/notifications.md
git commit -m "docs: document legendary tick + notification overrides"
```

---

## Task 17: Fix `_pokidle_announce_biome` pool-size bug + biome-rotation tests

**Files:**
- Modify: `pokidle` (`_pokidle_announce_biome` reads `.entries | length` which never existed in the v2 pool format; should sum tier lengths)
- Test: update `tests/test-biome-rotation.bats` if it asserts the notification body

- [ ] **Step 1: Verify the bug**

In `pokidle` ~line 221: `pool_size="$(jq '.entries | length' "$(encounter_pool_path "$biome")")"`. Schema 2/3 has `.tiers.<tier>[]`, no `.entries[]`. This silently returns `null` and the biome announce shows "0 species" or `null`.

- [ ] **Step 2: Write the failing test**

Append to `tests/test-biome-rotation.bats`:

```bash
@test "biome rotation announce: pool_size is sum of all tiers" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR POKIDLE_NO_NOTIFY
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    cat > "$POKIDLE_CACHE_DIR/pools/forest.json" <<EOF
{
    "biome": "forest", "schema": 3,
    "tiers": {
        "common": [{"species":"a"},{"species":"b"}],
        "uncommon": [{"species":"c"}],
        "rare": [],
        "very_rare": []
    },
    "berries": ["pecha","chesto"]
}
EOF
    # Source pokidle in test mode to access _pokidle_announce_biome.
    POKIDLE_TEST_SOURCE_ONLY=1
    export POKIDLE_TEST_SOURCE_ONLY
    source "$REPO_ROOT/pokidle"
    run _pokidle_announce_biome forest
    [ "$status" -eq 0 ]
    # Body should mention 3 species.
    [[ "$output" == *"3 species"* ]]
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `bats tests/test-biome-rotation.bats -f "pool_size"`
Expected: FAIL.

- [ ] **Step 4: Fix `_pokidle_announce_biome`**

In `pokidle`:

```bash
_pokidle_announce_biome() {
    local biome="$1"
    [[ "${POKIDLE_NOTIFY_BIOME:-1}" == "1" ]] || return 0
    local label pool_size berry_count
    label="$(biome_get "$biome" | jq -r '.label')"
    local p
    p="$(encounter_pool_path "$biome")"
    if [[ -f "$p" ]]; then
        pool_size="$(jq '[.tiers[] | length] | add // 0' "$p")"
        berry_count="$(jq '.berries | length' "$p")"
    else
        pool_size=0
        berry_count=0
    fi
    notify_biome_change "$label" "$pool_size" "$berry_count"
}
```

Also update `notify_biome_change` in `lib/notify.bash` so its second metric is "berries" rather than "items":

```bash
notify_biome_change() {
    local label="$1" pool_size="$2" berry_count="$3"
    local title="Biome changed → $label"
    local body="Encounters: $pool_size species, $berry_count berries"
    _emit "$title" "$body" "low" ""
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `bats tests/test-biome-rotation.bats`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pokidle lib/notify.bash tests/test-biome-rotation.bats
git commit -m "pokidle: fix biome announce pool-size (was reading dead .entries field)

Pool schema has been .tiers.<tier>[] since schema 2; the old announce
helper still read .entries which always returned null. Also retires the
'items' metric in favor of berry count, since item pools are now
type-derived at roll time (not bakeable into the pool file)."
```

---

## Task 18: Update `usage()` help text

**Files:**
- Modify: `pokidle`

- [ ] **Step 1: Rewrite the `usage()` heredoc to reflect the new tick kind + dropped subcommand**

```bash
usage() {
    cat <<'EOF'
pokidle — passive Pokémon encounter daemon.

Usage:
  pokidle <command> [args...]

Commands:
  daemon                  Run main loop (used by systemd unit)
  tick <kind> [flags]      Run a single roll now (default: dry-run, no DB write)
                            kind: pokemon | item | level | friendship | evolve | legendary
                            --no-dry-run    Persist DB writes
                            --no-notify     Skip notify-send
                            --json          Emit JSON to stdout
  list [filters]          Pretty list of pokemon encounters
  items [filters]         Pretty list of item drops
  stats                   Aggregates: totals, shinies, by biome, top species
  current                 Show current biome + counts
  rebuild-pool [biome]    Force pool rebuild (one or all; type-derived)
  switch-biome <biome>    Close active session, open new session in <biome>
  clean [--yes]           Purge pool cache + legacy biome-areas dir
  setup [--enable]        Install user systemd unit + config dirs
  uninstall               Disable + remove unit (DB/cache untouched)
  status                  systemctl status + last tick + current biome
  help, -h, --help        Show this help

See also:
  docs/superpowers/specs/2026-05-10-biome-redesign-and-legendaries-design.md
  docs/notifications.md  (event list + POKIDLE_NOTIFY_* env vars)
EOF
}
```

- [ ] **Step 2: Commit**

```bash
git add pokidle
git commit -m "pokidle: refresh help text — drops rebuild-biomes, adds tick legendary"
```

---

## Task 19: Full-suite smoke

**Files:** none modified — runs existing tests.

- [ ] **Step 1: Run the entire bats suite**

Run: `bats tests/`
Expected: ALL PASS.

If anything fails, fix inline (likely a test that hardcoded `wild` biome or referenced `biome_classify_area` or expected `.entries` in a pool file).

- [ ] **Step 2: Manual rebuild + tick smoke**

```bash
./pokidle clean --yes
./pokidle rebuild-pool          # rebuilds all 17 biomes from /type endpoints
./pokidle tick pokemon          # dry-run roll, verify no errors
./pokidle tick item             # dry-run roll, verify no errors
POKIDLE_LEGENDARY_CHANCE=100 ./pokidle tick legendary  # forced spawn
```

Expected: all four commands succeed. Legendary tick prints a legendary species line.

- [ ] **Step 3: Verify pool file shape**

```bash
jq 'keys' ~/.cache/pokidle/pools/forest.json
```

Expected output includes `["berries", "biome", "built_at", "schema", "tiers"]`. `.schema == 3`. `.berries` is a non-empty array.

- [ ] **Step 4: Commit nothing (smoke only); optional final tag**

If everything passes, push the branch:

```bash
git status                       # clean
git log --oneline -20            # review commit chain
git push origin main             # only if user requested push
```

---

## Self-review checklist

After writing this plan I re-read the spec and confirmed:

- **Spec § Goals 1-5**: covered by Tasks 1, 2, 6, 8, 9, 11-15.
- **Spec § Non-goals**: no schema/db changes in any task. No regional-form handling. No backfill — confirmed (legendary tick only inserts new rows; existing rows untouched).
- **Spec § New biome schema**: Task 1 (rewrite config) + Task 2 (validator) + Task 6 (build) read only `{id, label, types[]}`.
- **Spec § Proposed roster**: Task 1 ships the exact 17-biome roster.
- **Spec § Pool build algorithm steps 1-9**: Task 6 covers 1-7, Task 9 covers 8-9 (berries + schema 3).
- **Spec § Held-item type table**: Task 8.
- **Spec § Validator**: Task 2 (shape + type coverage) + Task 10 (documents berry/item subsumption).
- **Spec § Legendary roster**: Task 11.
- **Spec § Tick behavior**: Task 12 (build_encounter) + Task 13 (subcommand).
- **Spec § Daemon hook**: Task 14.
- **Spec § Notifications**: Task 15 (notify_pokemon) + Task 16 (docs).
- **Spec § Files removed**: Task 2 drops classifier/area helpers; Task 3 drops rebuild-biomes; Task 1 drops wild.
- **Spec § Migration**: Task 5 (clean wipes biome-areas).
- **Spec § Open questions**: psychic-single-biome accepted as-is; berry rate unchanged; legendary in stats out of scope.

No placeholders, no "TBD", no "similar to Task N". All code blocks are concrete.

Type / function-name consistency checked: `encounter_tier_for_capture_rate`, `biome_types_for`, `legendary_roll_species`, `legendary_build_encounter`, `ENCOUNTER_HELD_ITEMS_BY_TYPE`, `LEGENDARY_SPECIES`, `POKIDLE_LEGENDARY_{CHANCE,INTERVAL,LEVEL_MIN,LEVEL_MAX,ENABLED}`, `POKIDLE_NOTIFY_URGENCY_LEGENDARY`, `POKIDLE_SOUND_LEGENDARY` — all named identically across tasks.
