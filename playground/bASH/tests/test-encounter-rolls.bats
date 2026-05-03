#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib encounter
    stub_pokeapi
}

@test "encounter_natures_list returns 25 names" {
    run encounter_natures_list
    [ "$status" -eq 0 ]
    local n
    n="$(printf '%s\n' "$output" | wc -l)"
    [ "$n" = "25" ]
}

@test "encounter_nature_mods adamant: +atk -spa" {
    run encounter_nature_mods adamant
    [ "$status" -eq 0 ]
    local mods=($output)
    [ "${mods[0]}" = "1.0" ]
    [ "${mods[1]}" = "1.1" ]
    [ "${mods[2]}" = "1.0" ]
    [ "${mods[3]}" = "0.9" ]
    [ "${mods[4]}" = "1.0" ]
    [ "${mods[5]}" = "1.0" ]
}

@test "encounter_nature_mods bashful: all 1.0 (neutral)" {
    run encounter_nature_mods bashful
    [ "$status" -eq 0 ]
    local mods=($output)
    [ "${mods[0]}" = "1.0" ]
    [ "${mods[1]}" = "1.0" ]
    [ "${mods[2]}" = "1.0" ]
    [ "${mods[3]}" = "1.0" ]
    [ "${mods[4]}" = "1.0" ]
    [ "${mods[5]}" = "1.0" ]
}
