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
    [ "$n" = "17" ]
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
    [ "$n" = "17" ]
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
