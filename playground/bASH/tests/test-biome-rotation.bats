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
