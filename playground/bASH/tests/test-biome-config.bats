#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR
    load_lib biome
}

teardown() {
    rm -rf "$POKIDLE_CONFIG_DIR"
}

@test "biome_config_path resolves env override or repo default" {
    run biome_config_path
    [ "$status" -eq 0 ]
    [ "$output" = "$POKIDLE_CONFIG_DIR/biomes.json" ]
}

@test "biome_load returns full config json" {
    run biome_load
    [ "$status" -eq 0 ]
    local n
    n="$(jq '.biomes | length' <<< "$output")"
    [ "$n" = "18" ]
}

@test "biome_get returns one biome by id" {
    run biome_get cave
    [ "$status" -eq 0 ]
    local id label
    id="$(jq -r '.id' <<< "$output")"
    label="$(jq -r '.label' <<< "$output")"
    [ "$id" = "cave" ]
    [ "$label" = "Cave" ]
}

@test "biome_get unknown id fails" {
    run biome_get not-a-biome
    [ "$status" -ne 0 ]
}

@test "biome_ids lists all ids" {
    run biome_ids
    [ "$status" -eq 0 ]
    local n
    n="$(printf '%s\n' "$output" | wc -l)"
    [ "$n" = "18" ]
}

@test "biome_validate passes on valid config" {
    run biome_validate
    [ "$status" -eq 0 ]
}

@test "biome_validate fails on duplicate id" {
    jq '.biomes[1].id="cave"' "$POKIDLE_CONFIG_DIR/biomes.json" > "$POKIDLE_CONFIG_DIR/biomes.json.new"
    mv "$POKIDLE_CONFIG_DIR/biomes.json.new" "$POKIDLE_CONFIG_DIR/biomes.json"
    run biome_validate
    [ "$status" -ne 0 ]
}
