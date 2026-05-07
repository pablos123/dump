# Encounter Rarity Tiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the per-entry weighted roll in `lib/encounter.bash` with a two-step rarity-tier roll. Use raw PokeAPI chance only at build time to bucket species into 4 tiers; pick a tier with fixed weights, then pick uniformly inside.

**Architecture:** Extend `lib/encounter.bash` with tier constants and two pure helpers (`encounter_tier_for_pct`, `encounter_tier_shift`). Rewrite `encounter_build_pool` to emit a v2 pool shape (`{schema:2, tiers:{common:[…], …}}`). Rewrite `encounter_roll_pool_entry` as a fixed-weight tier roll + uniform pick with forward fallback. Update `encounter_pool_save` to embed the new shape, `encounter_pool_load` to reject v1 files, and the `pokidle rebuild-pool` CLI to wipe stale pool files and print tier counts.

**Tech Stack:** Bash 5+, `jq`, `bats-core`. Existing test helpers stub `pokeapi_get` from fixtures under `tests/fixtures/`.

**Spec:** `docs/superpowers/specs/2026-05-07-encounter-tiers-design.md`

---

## File map

- Modify `lib/encounter.bash` — add tier constants and helpers; rewrite `encounter_build_pool`, `encounter_pool_save`, `encounter_pool_load`, `encounter_roll_pool_entry`.
- Modify `pokidle` — adjust `pokidle_rebuild_pool` to wipe `$POKIDLE_CACHE_DIR/pools` when no biome arg and print per-tier counts.
- Modify `tests/test-encounter-pool.bats` — drop pct-normalization assertions, add tier-shape, classifier-boundary, evo-shift, multi-root, schema-guard, fallback tests.
- No new fixtures needed: the existing `rustboro-route-area` + `evolution-chain-142` (treecko/grovyle/sceptile) cover the tier and shift cases. New tests synthesize pool JSON inline.

## Conventions

- Run all tests with: `bats tests/test-encounter-pool.bats`
- Single test: `bats tests/test-encounter-pool.bats -f "<pattern>"`
- After each task that touches `lib/encounter.bash`, run the full file. After each task that touches `pokidle`, run `bats tests/test-cli.bats` too if it exists and is fast.

---

## Task 1: Tier constants + `encounter_tier_for_pct`

**Files:**
- Modify: `lib/encounter.bash` (top of file, after the `ENCOUNTER_STATS` line at :6)
- Test: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "encounter_tier_for_pct: boundary values map to expected tiers" {
    [ "$(encounter_tier_for_pct 100)" = "common" ]
    [ "$(encounter_tier_for_pct 25)"  = "common" ]
    [ "$(encounter_tier_for_pct 24)"  = "uncommon" ]
    [ "$(encounter_tier_for_pct 10)"  = "uncommon" ]
    [ "$(encounter_tier_for_pct 9)"   = "rare" ]
    [ "$(encounter_tier_for_pct 3)"   = "rare" ]
    [ "$(encounter_tier_for_pct 2)"   = "very_rare" ]
    [ "$(encounter_tier_for_pct 0)"   = "very_rare" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/test-encounter-pool.bats -f "encounter_tier_for_pct"`
Expected: FAIL with `command not found: encounter_tier_for_pct` (or similar).

- [ ] **Step 3: Write minimal implementation**

Insert into `lib/encounter.bash` immediately after the `ENCOUNTER_STATS` array (around line 6):

```bash
# Rarity tier definitions. ENCOUNTER_TIER_PCT_MIN[i] is the inclusive lower
# bound of tier ENCOUNTER_TIERS[i]; tiers are listed common-first.
ENCOUNTER_TIERS=(common uncommon rare very_rare)
ENCOUNTER_TIER_PCT_MIN=(25 10 3 0)
ENCOUNTER_TIER_ROLL_WEIGHT=(60 25 12 3)

encounter_tier_for_pct() {
    local pct="$1" i
    for i in 0 1 2 3; do
        if (( pct >= ENCOUNTER_TIER_PCT_MIN[i] )); then
            printf '%s' "${ENCOUNTER_TIERS[$i]}"
            return
        fi
    done
    printf 'very_rare'
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/test-encounter-pool.bats -f "encounter_tier_for_pct"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "encounter: add tier classifier helper"
```

---

## Task 2: `encounter_tier_shift`

**Files:**
- Modify: `lib/encounter.bash` (below `encounter_tier_for_pct`)
- Test: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "encounter_tier_shift: shifts one step rarer per stage and clamps" {
    [ "$(encounter_tier_shift common 0)"    = "common" ]
    [ "$(encounter_tier_shift common 1)"    = "uncommon" ]
    [ "$(encounter_tier_shift common 2)"    = "rare" ]
    [ "$(encounter_tier_shift common 3)"    = "very_rare" ]
    [ "$(encounter_tier_shift common 4)"    = "very_rare" ]
    [ "$(encounter_tier_shift uncommon 1)"  = "rare" ]
    [ "$(encounter_tier_shift rare 1)"      = "very_rare" ]
    [ "$(encounter_tier_shift very_rare 2)" = "very_rare" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/test-encounter-pool.bats -f "encounter_tier_shift"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/encounter.bash` directly below `encounter_tier_for_pct`:

```bash
# Shift a tier name N steps toward "very_rare", clamped.
encounter_tier_shift() {
    local tier="$1" steps="$2" i base target
    base=-1
    for i in 0 1 2 3; do
        if [[ "${ENCOUNTER_TIERS[$i]}" == "$tier" ]]; then
            base=$i
            break
        fi
    done
    if (( base < 0 )); then
        printf 'encounter_tier_shift: bad tier %s\n' "$tier" >&2
        return 1
    fi
    target=$(( base + steps ))
    (( target > 3 )) && target=3
    printf '%s' "${ENCOUNTER_TIERS[$target]}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/test-encounter-pool.bats -f "encounter_tier_shift"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "encounter: add tier-shift helper"
```

---

## Task 3: Drop legacy build_pool tests that assert the old shape

The two pre-existing tests "build_pool: single area with treecko -> 3-entry pool, halved %, normalized to 100" and "build_pool: grovyle gets level 16-(16+delta), sceptile 36-(36+delta) where delta=2" assert the old `[{species,min,max,pct}]` shape with normalized pct. They will be replaced in Task 4. Removing them first keeps the test suite green between tasks.

**Files:**
- Modify: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Delete obsolete tests**

Open `tests/test-encounter-pool.bats`. Delete the two `@test` blocks at lines 34–52 ("build_pool: single area with treecko ...") and 54–65 ("build_pool: grovyle gets level 16-(16+delta) ...").

Also update the round-trip test at line 87 (`encounter_pool_save and encounter_pool_load round-trip`). The old assertion `n="$(jq '.entries | length' <<< "$output")"` and the inline pool array no longer match. Delete that test as well — it gets replaced in Task 5.

Delete the test at line 99 ("encounter_roll_pool_entry returns one of the pool species") — replaced in Task 6.

- [ ] **Step 2: Run remaining tests to verify suite is green**

Run: `bats tests/test-encounter-pool.bats`
Expected: PASS (only the two helper tests from Task 1/2 plus the chain-walk tests run).

- [ ] **Step 3: Commit**

```bash
git add tests/test-encounter-pool.bats
git commit -m "tests: drop legacy build_pool/save/roll tests for tier rewrite"
```

---

## Task 4: Rewrite `encounter_build_pool` to emit v2 tier shape

**Files:**
- Modify: `lib/encounter.bash:277-395` (replace the body of `encounter_build_pool`)
- Test: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "build_pool: treecko area produces v2 tier shape, no pct in entries" {
    local areas='["rustboro-route-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    # Output is the inner object {tiers:{...}} — encounter_pool_save wraps it.
    local has_tiers
    has_tiers="$(jq 'has("tiers")' <<< "$output")"
    [ "$has_tiers" = "true" ]
    local has_pct
    has_pct="$(jq '[.tiers[][] | has("pct")] | any' <<< "$output")"
    [ "$has_pct" = "false" ]
}

@test "build_pool: treecko (chance=40) is common; grovyle uncommon; sceptile rare" {
    local areas='["rustboro-route-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    local treecko_tier grovyle_tier sceptile_tier
    treecko_tier="$(jq -r '.tiers | to_entries[] | select(.value[].species=="treecko") | .key' <<< "$output")"
    grovyle_tier="$(jq -r '.tiers | to_entries[] | select(.value[].species=="grovyle") | .key' <<< "$output")"
    sceptile_tier="$(jq -r '.tiers | to_entries[] | select(.value[].species=="sceptile") | .key' <<< "$output")"
    [ "$treecko_tier"  = "common" ]
    [ "$grovyle_tier"  = "uncommon" ]
    [ "$sceptile_tier" = "rare" ]
}

@test "build_pool: grovyle level 16-18, sceptile 36-38, treecko 5-7" {
    local areas='["rustboro-route-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    local t_min t_max g_min g_max s_min s_max
    t_min="$(jq -r '.tiers.common[]    | select(.species=="treecko")  | .min' <<< "$output")"
    t_max="$(jq -r '.tiers.common[]    | select(.species=="treecko")  | .max' <<< "$output")"
    g_min="$(jq -r '.tiers.uncommon[]  | select(.species=="grovyle")  | .min' <<< "$output")"
    g_max="$(jq -r '.tiers.uncommon[]  | select(.species=="grovyle")  | .max' <<< "$output")"
    s_min="$(jq -r '.tiers.rare[]      | select(.species=="sceptile") | .min' <<< "$output")"
    s_max="$(jq -r '.tiers.rare[]      | select(.species=="sceptile") | .max' <<< "$output")"
    [ "$t_min" = "5" ]  && [ "$t_max" = "7" ]
    [ "$g_min" = "16" ] && [ "$g_max" = "18" ]
    [ "$s_min" = "36" ] && [ "$s_max" = "38" ]
}

@test "build_pool: empty tiers are present as empty arrays" {
    local areas='["rustboro-route-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    local vr
    vr="$(jq '.tiers.very_rare | type' <<< "$output")"
    [ "$vr" = "array" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-encounter-pool.bats -f "build_pool"`
Expected: FAIL — `encounter_build_pool` still returns the v1 array.

- [ ] **Step 3: Replace `encounter_build_pool`**

In `lib/encounter.bash`, replace the entire `encounter_build_pool` function (current lines 277-395) with this implementation. The chain-walk and pct-aggregation logic is preserved; the bucketing and dedup are new; the final normalize step is removed.

```bash
# encounter_build_pool <areas_json_array> <gen_csv>
# Emits a JSON object {tiers:{common:[],uncommon:[],rare:[],very_rare:[]}}
# where every entry is {species, min, max} (no pct). Entries are tier-bucketed
# from the aggregated raw chance and chain-shifted one tier per evolution
# stage, clamped at very_rare. On species collision across tiers, the
# most-common tier wins.
encounter_build_pool() {
    local areas_json="$1" gen_csv="$2"

    # 1. Aggregate raw rows from each area, optionally filtered by generation.
    local raw='[]'
    local area
    while IFS= read -r area; do
        [[ -z "$area" ]] && continue
        local area_json
        area_json="$(pokeapi_get "location-area/$area")" || return 1
        local rows
        rows="$(jq -c '
            .pokemon_encounters[] |
            .pokemon.name as $sp |
            .version_details[] |
            .version.name as $ver |
            .encounter_details[] |
            {species: $sp, min: .min_level, max: .max_level, chance: .chance, version: $ver}
        ' <<< "$area_json")"
        local row
        while IFS= read -r row; do
            [[ -z "$row" ]] && continue
            if [[ -n "$gen_csv" ]]; then
                local v g
                v="$(jq -r '.version' <<< "$row")"
                g="$(encounter_gen_of "$v")"
                local match=0
                IFS=',' read -ra wanted <<< "$gen_csv"
                local w
                for w in "${wanted[@]}"; do
                    [[ "$w" == "$g" ]] && match=1 && break
                done
                (( match )) || continue
            fi
            raw="$(jq -c --argjson r "$row" '. + [$r]' <<< "$raw")"
        done <<< "$rows"
    done <<< "$(jq -r '.[]' <<< "$areas_json")"

    # 2. Per-species aggregate min/max/sum(chance).
    local base
    base="$(jq -c '
        group_by(.species) | map({
            species: (.[0].species),
            min: ([.[].min] | min),
            max: ([.[].max] | max),
            pct: ([.[].chance] | add)
        })
    ' <<< "$raw")"

    # 3. Walk evolution chain for each root, classify each stage into a tier.
    #    Output a flat list of {species, min, max, tier_idx}.
    local flat='[]'
    local entries entry
    entries="$(jq -c '.[]' <<< "$base")"
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local sp min max pct delta root_tier root_idx
        sp="$(jq -r '.species' <<< "$entry")"
        min="$(jq -r '.min' <<< "$entry")"
        max="$(jq -r '.max' <<< "$entry")"
        pct="$(jq -r '.pct' <<< "$entry")"
        delta=$((max - min))
        root_tier="$(encounter_tier_for_pct "$pct")"
        root_idx=-1
        local i
        for i in 0 1 2 3; do
            [[ "${ENCOUNTER_TIERS[$i]}" == "$root_tier" ]] && root_idx=$i && break
        done

        # Resolve form -> base species for the chain lookup.
        local poke_obj species_name
        poke_obj="$(pokeapi_get "pokemon/$sp")" || return 1
        species_name="$(jq -r '.species.name' <<< "$poke_obj")"

        local spec chain_url chain_id chain stages
        spec="$(pokeapi_get "pokemon-species/$species_name")" || return 1
        chain_url="$(jq -r '.evolution_chain.url' <<< "$spec")"
        chain_id="$(basename -- "${chain_url%/}")"
        chain="$(pokeapi_get "evolution-chain/$chain_id")" || return 1
        stages="$(encounter_walk_chain "$chain")"

        local stage_entries
        stage_entries="$(jq -c \
            --argjson root_min "$min" --argjson root_max "$max" --argjson delta "$delta" \
            --argjson root_idx "$root_idx" --argjson stages "$stages" '
            $stages
            | sort_by(.stage_idx)
            | reduce .[] as $s (
                {expanded: [], by_idx: {}};
                if $s.stage_idx == 0 then
                    .expanded += [{
                        species: $s.species, min: $root_min, max: $root_max,
                        tier_idx: $root_idx
                    }]
                    | .by_idx[($s.stage_idx|tostring)] = $root_max
                else
                    (.by_idx[(($s.stage_idx - 1)|tostring)]) as $parent_max |
                    (if $s.min_level_evo != null then $s.min_level_evo
                     else ($parent_max + 10) end) as $emin |
                    ([$root_idx + $s.stage_idx, 3] | min) as $tidx |
                    .expanded += [{
                        species: $s.species, min: $emin, max: ($emin + $delta),
                        tier_idx: $tidx
                    }]
                    | .by_idx[($s.stage_idx|tostring)] = ($emin + $delta)
                end
              )
            | .expanded
        ' <<< 'null')"
        flat="$(jq -c --argjson e "$stage_entries" '. + $e' <<< "$flat")"
    done <<< "$entries"

    # 4. Collision dedup: same species in multiple tiers -> keep min tier_idx
    #    (= most common). Within a tier, merge duplicate species.
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
    jq -c --argjson tiers "$(printf '%s' "[\"common\",\"uncommon\",\"rare\",\"very_rare\"]")" '
        ($tiers | map({(.) : []}) | add) as $empty
        | reduce .[] as $e ($empty;
            ($tiers[$e.tier_idx]) as $name
            | .[$name] += [{species: $e.species, min: $e.min, max: $e.max}]
          )
        | {tiers: .}
    ' <<< "$deduped"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-encounter-pool.bats`
Expected: PASS for the four new build_pool tests plus existing helper and chain-walk tests.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "encounter: build pool as tier buckets, drop pct normalization"
```

---

## Task 5: `encounter_pool_save` v2 + `encounter_pool_load` schema guard

**Files:**
- Modify: `lib/encounter.bash:402-423` (`encounter_pool_save`, `encounter_pool_load`)
- Test: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "encounter_pool_save writes schema:2 and tiers wrapper" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    local pool='{"tiers":{"common":[{"species":"zubat","min":5,"max":8}],"uncommon":[],"rare":[],"very_rare":[]}}'
    encounter_pool_save cave "$pool"
    local saved
    saved="$(cat "$POKIDLE_CACHE_DIR/pools/cave.json")"
    [ "$(jq -r '.schema' <<< "$saved")" = "2" ]
    [ "$(jq -r '.biome' <<< "$saved")" = "cave" ]
    [ "$(jq -r '.tiers.common[0].species' <<< "$saved")" = "zubat" ]
    [ "$(jq '.tiers.uncommon | type' <<< "$saved")" = "\"array\"" ]
}

@test "encounter_pool_load returns full v2 file on read" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    local pool='{"tiers":{"common":[{"species":"zubat","min":5,"max":8}],"uncommon":[],"rare":[],"very_rare":[]}}'
    encounter_pool_save cave "$pool"
    run encounter_pool_load cave
    [ "$status" -eq 0 ]
    [ "$(jq -r '.schema' <<< "$output")" = "2" ]
    [ "$(jq -r '.tiers.common[0].species' <<< "$output")" = "zubat" ]
}

@test "encounter_pool_load rejects v1 file without schema field" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    cat > "$POKIDLE_CACHE_DIR/pools/cave.json" <<'EOF'
{"biome":"cave","entries":[{"species":"zubat","min":5,"max":8,"pct":50}]}
EOF
    run encounter_pool_load cave
    [ "$status" -ne 0 ]
    [[ "$output" == *"rebuild-pool"* ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-encounter-pool.bats -f "encounter_pool_save|encounter_pool_load"`
Expected: FAIL — `encounter_pool_save` writes the old `entries` shape; `encounter_pool_load` doesn't check schema.

- [ ] **Step 3: Replace `encounter_pool_save` and `encounter_pool_load`**

In `lib/encounter.bash`, replace the existing `encounter_pool_save` (currently lines 402-415) and `encounter_pool_load` (currently lines 417-423) with:

```bash
encounter_pool_save() {
    local biome="$1" body_json="$2"
    local p
    p="$(encounter_pool_path "$biome")"
    mkdir -p -- "$(dirname -- "$p")"
    local body
    body="$(jq -c -n --arg b "$biome" --arg ts "$(date -u +%FT%TZ)" \
                  --arg gen "${POKIDLE_GEN:-}" --argjson p "$body_json" '{
        biome: $b,
        built_at: $ts,
        gen_filter: ($gen | if . == "" then [] else split(",") end),
        schema: 2,
        tiers: $p.tiers
    }')"
    printf '%s' "$body" > "$p"
}

encounter_pool_load() {
    local biome="$1"
    local p
    p="$(encounter_pool_path "$biome")"
    [[ -f "$p" ]] || { printf 'encounter_pool_load: no pool for %s\n' "$biome" >&2; return 1; }
    local body schema
    body="$(cat "$p")"
    schema="$(jq -r '.schema // 0' <<< "$body")"
    if [[ "$schema" != "2" ]]; then
        printf 'encounter_pool_load: pool stale for %s, run: pokidle rebuild-pool\n' "$biome" >&2
        return 1
    fi
    printf '%s' "$body"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-encounter-pool.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "encounter: pool save/load v2 schema with stale guard"
```

---

## Task 6: Rewrite `encounter_roll_pool_entry`

**Files:**
- Modify: `lib/encounter.bash:425-444`
- Test: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-encounter-pool.bats`:

```bash
@test "encounter_roll_pool_entry returns species from a populated tier" {
    local pool='{"schema":2,"tiers":{"common":[{"species":"zubat","min":5,"max":8}],"uncommon":[],"rare":[],"very_rare":[]}}'
    run encounter_roll_pool_entry "$pool"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.species' <<< "$output")" = "zubat" ]
    [ "$(jq -r '.min'     <<< "$output")" = "5" ]
    [ "$(jq -r '.max'     <<< "$output")" = "8" ]
}

@test "encounter_roll_pool_entry falls back forward when only very_rare populated" {
    local pool='{"schema":2,"tiers":{"common":[],"uncommon":[],"rare":[],"very_rare":[{"species":"mew","min":40,"max":40}]}}'
    run encounter_roll_pool_entry "$pool"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.species' <<< "$output")" = "mew" ]
}

@test "encounter_roll_pool_entry errors when all tiers empty" {
    local pool='{"schema":2,"tiers":{"common":[],"uncommon":[],"rare":[],"very_rare":[]}}'
    run encounter_roll_pool_entry "$pool"
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/test-encounter-pool.bats -f "encounter_roll_pool_entry"`
Expected: FAIL — current implementation reads `.entries[]`.

- [ ] **Step 3: Replace `encounter_roll_pool_entry`**

In `lib/encounter.bash`, replace the entire function body (currently lines 425-444) with:

```bash
# Roll a pool entry from a v2 pool {schema:2, tiers:{...}}.
# Pick a tier by fixed weights, walk forward to the next non-empty tier on
# empty bucket, then pick uniformly inside. Errors out if every tier empty.
encounter_roll_pool_entry() {
    local pool="$1"
    local roll=$((RANDOM % 100))
    local cum=0 i tier_idx=0 step name n arr_idx
    for i in 0 1 2 3; do
        cum=$(( cum + ENCOUNTER_TIER_ROLL_WEIGHT[i] ))
        if (( roll < cum )); then
            tier_idx=$i
            break
        fi
    done
    for step in 0 1 2 3; do
        name="${ENCOUNTER_TIERS[$(( (tier_idx + step) % 4 ))]}"
        n="$(jq --arg t "$name" '.tiers[$t] | length' <<< "$pool")"
        if (( n > 0 )); then
            arr_idx=$(( RANDOM % n ))
            jq -c --arg t "$name" --argjson i "$arr_idx" '.tiers[$t][$i]' <<< "$pool"
            return 0
        fi
    done
    printf 'encounter_roll_pool_entry: pool has no entries in any tier\n' >&2
    return 1
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/test-encounter-pool.bats`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/encounter.bash tests/test-encounter-pool.bats
git commit -m "encounter: tier-weighted roll w/ forward fallback"
```

---

## Task 7: Multi-root collision test

This guards the dedup rule (the species-collision case) with a synthetic test that doesn't depend on a real PokeAPI fixture. It seeds the chain-walking logic by stubbing `pokeapi_get` to return an evolution chain that contains a species also present as a direct encounter in the area.

**Files:**
- Modify: `tests/test-encounter-pool.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/test-encounter-pool.bats`. This re-stubs `pokeapi_get` to return inline JSON for one specific synthetic case so we don't need new files.

```bash
@test "build_pool: species seen in two tiers ends up in the most-common one" {
    # Synthetic area: 'aaa' (chance 50 -> common) whose evolution chain also
    # contains 'bbb'. Separately, 'bbb' is its own entry with chance 5 -> rare.
    # After dedup, bbb must land in uncommon (common+1 from chain shift),
    # not rare.
    pokeapi_get() {
        case "$1" in
            location-area/synthetic-area)
                cat <<'JSON'
{"name":"synthetic-area","pokemon_encounters":[
  {"pokemon":{"name":"aaa"},"version_details":[{"version":{"name":"emerald"},
    "encounter_details":[{"min_level":5,"max_level":7,"chance":50,"method":{"name":"walk"}}]}]},
  {"pokemon":{"name":"bbb"},"version_details":[{"version":{"name":"emerald"},
    "encounter_details":[{"min_level":20,"max_level":22,"chance":5,"method":{"name":"walk"}}]}]}
]}
JSON
                ;;
            pokemon/aaa) printf '{"id":1,"species":{"name":"aaa"}}' ;;
            pokemon/bbb) printf '{"id":2,"species":{"name":"bbb"}}' ;;
            pokemon-species/aaa) printf '{"evolution_chain":{"url":"https://x/evolution-chain/1/"}}' ;;
            pokemon-species/bbb) printf '{"evolution_chain":{"url":"https://x/evolution-chain/2/"}}' ;;
            evolution-chain/1)
                printf '%s' '{"chain":{"species":{"name":"aaa"},"evolution_details":[],"evolves_to":[{"species":{"name":"bbb"},"evolution_details":[{"min_level":16}],"evolves_to":[]}]}}'
                ;;
            evolution-chain/2)
                printf '%s' '{"chain":{"species":{"name":"bbb"},"evolution_details":[],"evolves_to":[]}}'
                ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get

    local areas='["synthetic-area"]'
    run encounter_build_pool "$areas" ""
    [ "$status" -eq 0 ]
    local bbb_tier
    bbb_tier="$(jq -r '.tiers | to_entries[] | select(.value[].species=="bbb") | .key' <<< "$output")"
    [ "$bbb_tier" = "uncommon" ]
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bats tests/test-encounter-pool.bats -f "two tiers"`
Expected: PASS — Task 4's `min_by(.tier_idx)` rule already handles this.

- [ ] **Step 3: Commit**

```bash
git add tests/test-encounter-pool.bats
git commit -m "tests: cover multi-root tier collision dedup"
```

---

## Task 8: `pokidle rebuild-pool` wipe + tier counts

**Files:**
- Modify: `pokidle:442-465` (`pokidle_rebuild_pool`)

- [ ] **Step 1: Read current implementation**

Open `pokidle` and locate `pokidle_rebuild_pool` (around line 442). The current body iterates biomes (or one target), reads `biome-areas/<b>.json`, calls `encounter_build_pool`, saves, and prints `rebuilt pool: <b> (<n> entries)`.

- [ ] **Step 2: Replace with wipe-aware tier-aware version**

Replace the function body with:

```bash
pokidle_rebuild_pool() {
    local target="${1-}"
    local biomes
    if [[ -n "$target" ]]; then
        biomes="$target"
    else
        biomes="$(biome_ids)"
        # No biome arg = full rebuild. Wipe stale pool files first so
        # leftover v1 (or removed-biome) files don't linger.
        rm -rf -- "$POKIDLE_CACHE_DIR/pools"
    fi
    local b
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        local areas_path="$POKIDLE_CACHE_DIR/biome-areas/$b.json"
        if [[ ! -f "$areas_path" ]]; then
            printf 'rebuild-pool: no area list for biome %s — run rebuild-biomes first\n' "$b" >&2
            continue
        fi
        local areas pool
        areas="$(cat "$areas_path")"
        pool="$(encounter_build_pool "$areas" "${POKIDLE_GEN:-}")"
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

- [ ] **Step 3: Smoke-test the CLI**

If you have a development checkout with cached `biome-areas/*.json` files and a warm `POKEAPI_CACHE_DIR`, run:

```bash
./pokidle rebuild-pool cave
```

Expected: a single line `rebuilt pool: cave (common=N uncommon=N rare=N very_rare=N)` and a v2 file at `~/.cache/pokidle/pools/cave.json` containing `"schema": 2`.

If you don't have warm caches, skip this manual check — the bats suite covers correctness.

- [ ] **Step 4: Commit**

```bash
git add pokidle
git commit -m "pokidle: wipe pools dir on full rebuild, print tier counts"
```

---

## Task 9: Final verification

**Files:** none (read-only)

- [ ] **Step 1: Run the full encounter test suite**

Run: `bats tests/test-encounter-pool.bats tests/test-encounter-rolls.bats tests/test-encounter-stats.bats`
Expected: all PASS.

- [ ] **Step 2: Confirm `encounter_roll_pokemon` still works against v2 entries**

`encounter_roll_pokemon` (line 449 of `lib/encounter.bash`) only reads `.species`, `.min`, `.max` from the entry — same fields the new pool emits. No code change required, but the existing test `tests/test-encounter-rolls.bats:199` exercises the full path and should pass without modification.

If `tests/test-encounter-rolls.bats` does fail, inspect the failure — it likely points at a fixture or a path the pool-shape change accidentally broke. Fix in place.

- [ ] **Step 3: Run shellcheck on modified files**

Run: `shellcheck lib/encounter.bash pokidle`
Expected: no new warnings introduced by this change. Pre-existing warnings can be left.

- [ ] **Step 4: Commit any fix-ups (if needed)**

If the prior step required code changes, commit:

```bash
git add lib/encounter.bash pokidle tests/
git commit -m "encounter: address shellcheck/test fallout from tier rewrite"
```

If nothing changed, skip.

---

## Self-review notes

Spec coverage:
- Tier classification + boundaries → Task 1.
- Tier shift rule → Task 2.
- Pool build (bucket + dedup, no normalization, no pct in entries) → Task 4.
- Pool schema v2 + load guard → Task 5.
- Tier-weighted roll + forward fallback + all-empty error → Task 6.
- Multi-root dedup keeps most-common tier → Task 4 implementation, Task 7 covering test.
- `rebuild-pool` wipes pool dir + prints tier counts; HTTP cache untouched → Task 8.
- Migration ("user runs `pokidle rebuild-pool`") → covered by the existing CLI flow plus Task 8.

Type/name consistency:
- `encounter_tier_for_pct` and `encounter_tier_shift` defined in Tasks 1/2; no later task renames them.
- `ENCOUNTER_TIERS`, `ENCOUNTER_TIER_PCT_MIN`, `ENCOUNTER_TIER_ROLL_WEIGHT` referenced consistently.
- Pool object key is `tiers` everywhere (build, save, load, roll). Schema marker is `schema: 2` in save and load.

Placeholders: none. Each step shows the exact bash to add or replace.
