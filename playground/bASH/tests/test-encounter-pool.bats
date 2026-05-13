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

@test "build_pool: type-derived produces tier shape, includes evolution stages" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_REPO_ROOT POKIDLE_CACHE_DIR
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
    local has_tiers
    has_tiers="$(jq 'has("tiers") and (.tiers | has("common") and has("uncommon") and has("rare") and has("very_rare"))' <<< "$output")"
    [ "$has_tiers" = "true" ]
    local cat_tier
    cat_tier="$(jq -r '.tiers | to_entries[] | select(.value | map(.species) | index("caterpie")) | .key' <<< "$output")"
    [ "$cat_tier" = "common" ]
    local meta_tier
    meta_tier="$(jq -r '.tiers | to_entries[] | select(.value | map(.species) | index("metapod")) | .key' <<< "$output")"
    [ "$meta_tier" = "uncommon" ]
    local tre_tier
    tre_tier="$(jq -r '.tiers | to_entries[] | select(.value | map(.species) | index("treecko")) | .key' <<< "$output")"
    [ "$tre_tier" = "uncommon" ]
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
