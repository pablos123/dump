#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR
    load_lib biome
}

@test "biome_pick_random returns a valid biome id" {
    run biome_pick_random
    [ "$status" -eq 0 ]
    biome_get "$output" >/dev/null
}

@test "biome_pick_random_excluding never returns the excluded id" {
    local i out
    for i in {1..30}; do
        out="$(biome_pick_random_excluding cave)"
        [ "$out" != "cave" ]
    done
}

@test "biome_pick_random_excluding fails if only biome remaining is excluded" {
    # Patch config to have only 1 biome
    jq '.biomes = [.biomes[0]] | .fallback_biome = .biomes[0].id' \
        "$POKIDLE_CONFIG_DIR/biomes.json" > "$POKIDLE_CONFIG_DIR/tmp.json"
    mv "$POKIDLE_CONFIG_DIR/tmp.json" "$POKIDLE_CONFIG_DIR/biomes.json"

    run biome_pick_random_excluding "$(biome_ids)"
    [ "$status" -ne 0 ]
}

# Helper: write a v2 pool file with N entries spread across common.
_write_pool() {
    local biome="$1" n="$2"
    mkdir -p -- "$POKIDLE_CACHE_DIR/pools"
    jq -n --arg b "$biome" --argjson n "$n" '
        {biome: $b, schema: 2, tiers: {
            common: [range(0; $n) | {species: ("s\(.))"), min: 5, max: 8}],
            uncommon: [], rare: [], very_rare: []
        }}
    ' > "$POKIDLE_CACHE_DIR/pools/$biome.json"
}

@test "biome_pick_random skips biomes with pool size <= 10" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    # Patch config to two biomes; only the second has a populated pool.
    jq '.biomes = [.biomes[0], .biomes[1]] | .fallback_biome = .biomes[0].id' \
        "$POKIDLE_CONFIG_DIR/biomes.json" > "$POKIDLE_CONFIG_DIR/tmp.json"
    mv "$POKIDLE_CONFIG_DIR/tmp.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    local big small
    big="$(biome_ids | sed -n 1p)"
    small="$(biome_ids | sed -n 2p)"
    _write_pool "$big"   50
    _write_pool "$small" 5

    local i out
    for i in {1..30}; do
        out="$(biome_pick_random)"
        [ "$out" = "$big" ]
    done
}

@test "biome_pick_random fails when every pool has <= 10 entries" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    local id
    while IFS= read -r id; do
        _write_pool "$id" 3
    done < <(biome_ids)

    run biome_pick_random
    [ "$status" -ne 0 ]
    [[ "$output" == *"pool>"* ]]
}

@test "biome_pick_random treats missing pool as size 0 and skips" {
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    export POKIDLE_CACHE_DIR
    # No pool files written; every biome ineligible.
    run biome_pick_random
    [ "$status" -ne 0 ]
}
