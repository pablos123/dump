#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    load_lib biome
    stub_pokeapi
}

@test "classify_area: cave-named route maps to cave biome" {
    local area_json
    area_json="$(cat "$FIXTURE_DIR/area-cave-001.json")"
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    [ "$output" = "cave" ]
}

@test "classify_area: route-1 (pidgey/rattata) maps to plain via name regex" {
    local area_json
    area_json="$(cat "$FIXTURE_DIR/area-route-1.json")"
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    [ "$output" = "plain" ]
}

@test "classify_area: volcano area maps to volcano" {
    local area_json
    area_json="$(cat "$FIXTURE_DIR/area-volcano-crater.json")"
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    # mt-chimney-volcano matches both mountain (mt-) and volcano (volcano) — volcano scores higher with type overlap
    [ "$output" = "volcano" ]
}

@test "classify_area: area with no match falls back to wild" {
    local area_json='{"name":"unknown-zone","pokemon_encounters":[]}'
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    [ "$output" = "wild" ]
}
