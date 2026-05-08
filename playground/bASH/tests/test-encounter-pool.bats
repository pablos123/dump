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
