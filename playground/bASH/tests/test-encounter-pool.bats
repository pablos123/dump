#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib encounter
    stub_pokeapi
}

@test "walk_chain: treecko line yields 3 stages with correct levels" {
    local chain
    chain="$(cat "$FIXTURE_DIR/evolution-chain-142.json")"
    run encounter_walk_chain "$chain"
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "3" ]
    local treecko_stage grovyle_stage sceptile_stage
    treecko_stage="$(jq -r '.[] | select(.species=="treecko") | .stage_idx' <<< "$output")"
    grovyle_stage="$(jq -r '.[] | select(.species=="grovyle") | .stage_idx' <<< "$output")"
    sceptile_stage="$(jq -r '.[] | select(.species=="sceptile") | .stage_idx' <<< "$output")"
    [ "$treecko_stage" = "0" ]
    [ "$grovyle_stage" = "1" ]
    [ "$sceptile_stage" = "2" ]
    local grovyle_min sceptile_min
    grovyle_min="$(jq -r '.[] | select(.species=="grovyle") | .min_level_evo' <<< "$output")"
    sceptile_min="$(jq -r '.[] | select(.species=="sceptile") | .min_level_evo' <<< "$output")"
    [ "$grovyle_min" = "16" ]
    [ "$sceptile_min" = "36" ]
}

@test "walk_chain: eevee line yields 3 stages with null min_level for non-level evos" {
    local chain
    chain="$(cat "$FIXTURE_DIR/evolution-chain-67.json")"
    run encounter_walk_chain "$chain"
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "3" ]
    local vaporeon_min
    vaporeon_min="$(jq -r '.[] | select(.species=="vaporeon") | .min_level_evo // "null"' <<< "$output")"
    [ "$vaporeon_min" = "null" ]
}

@test "encounter_pool_path returns biome-specific cache path" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    run encounter_pool_path cave
    [ "$output" = "$POKIDLE_CACHE_DIR/pools/cave.json" ]
}

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
    vr="$(jq -r '.tiers.very_rare | type' <<< "$output")"
    [ "$vr" = "array" ]
}

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

@test "evolution_tier_lookup returns tier name for species in pool" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    cat > "$POKIDLE_CACHE_DIR/pools/cave.json" <<'EOF'
{"biome":"cave","schema":2,"tiers":{
  "common":[{"species":"zubat","min":5,"max":8}],
  "uncommon":[{"species":"golbat","min":22,"max":25}],
  "rare":[],"very_rare":[]
}}
EOF
    source "$REPO_ROOT/lib/evolution.bash"
    [ "$(evolution_tier_lookup cave zubat)" = "common" ]
    [ "$(evolution_tier_lookup cave golbat)" = "uncommon" ]
    [ "$(evolution_tier_lookup cave mew)" = "common" ]   # absent → default
}

@test "evolution_next_stages returns species + evolution_details one stage past root" {
    source "$REPO_ROOT/lib/evolution.bash"
    local chain='{"chain":{
      "species":{"name":"eevee"},"evolution_details":[],
      "evolves_to":[
        {"species":{"name":"vaporeon"},"evolution_details":[
          {"item":{"name":"water-stone"},"trigger":{"name":"use-item"}}],
         "evolves_to":[]},
        {"species":{"name":"jolteon"},"evolution_details":[
          {"item":{"name":"thunder-stone"},"trigger":{"name":"use-item"}}],
         "evolves_to":[]}]}}'
    run evolution_next_stages "$chain" eevee
    [ "$status" -eq 0 ]
    [ "$(jq 'length' <<< "$output")" = "2" ]
    [ "$(jq -r '.[0].species' <<< "$output")" = "vaporeon" ]
    [ "$(jq -r '.[0].evolution_details[0].item.name' <<< "$output")" = "water-stone" ]
}

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
