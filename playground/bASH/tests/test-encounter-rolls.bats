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

@test "encounter_nature_mods: missing nature returns non-zero" {
    run encounter_nature_mods does-not-exist
    [ "$status" -ne 0 ]
}

@test "encounter_roll_ivs returns 6 ints in [0,31]" {
    run encounter_roll_ivs
    [ "$status" -eq 0 ]
    local ivs=($output)
    [ "${#ivs[@]}" -eq 6 ]
    local i
    for i in "${ivs[@]}"; do
        [ "$i" -ge 0 ] && [ "$i" -le 31 ]
    done
}

@test "encounter_ev_split: total ≤ 510, each ≤ 252" {
    local i
    for i in {1..50}; do
        local out
        out="$(encounter_ev_split "$((RANDOM % 511))")"
        local arr=($out)
        [ "${#arr[@]}" -eq 6 ]
        local total=0 v
        for v in "${arr[@]}"; do
            [ "$v" -le 252 ]
            [ "$v" -ge 0 ]
            total=$((total + v))
        done
        [ "$total" -le 510 ]
    done
}

@test "encounter_ev_split(0) = all zeros" {
    run encounter_ev_split 0
    [ "$output" = "0 0 0 0 0 0" ]
}

@test "encounter_roll_level: uniform within [min,max] inclusive" {
    local i out
    for i in {1..30}; do
        out="$(encounter_roll_level 5 8)"
        [ "$out" -ge 5 ] && [ "$out" -le 8 ]
    done
}
