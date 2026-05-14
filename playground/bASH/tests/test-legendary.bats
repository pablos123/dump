#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib legendary
}

@test "LEGENDARY_SPECIES: contains canonical gen-1 legendaries" {
    local got
    got=" ${LEGENDARY_SPECIES[*]} "
    [[ "$got" == *" articuno "* ]]
    [[ "$got" == *" zapdos "* ]]
    [[ "$got" == *" moltres "* ]]
    [[ "$got" == *" mewtwo "* ]]
    [[ "$got" == *" mew "* ]]
}

@test "LEGENDARY_SPECIES: contains gen-7+ entries" {
    local got
    got=" ${LEGENDARY_SPECIES[*]} "
    [[ "$got" == *" tapu-koko "* ]]
    [[ "$got" == *" zacian "* ]]
}

@test "legendary_roll_species: prints a name from LEGENDARY_SPECIES" {
    local out
    out="$(legendary_roll_species)"
    local got
    got=" ${LEGENDARY_SPECIES[*]} "
    [[ "$got" == *" $out "* ]]
}

@test "legendary_build_encounter: returns encounter JSON with all required fields" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_LEVEL_MIN=50
    POKIDLE_LEGENDARY_LEVEL_MAX=70
    export POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_LEVEL_MIN POKIDLE_LEGENDARY_LEVEL_MAX
    load_lib encounter
    load_lib legendary
    stub_pokeapi
    local enc
    enc="$(legendary_build_encounter articuno forest)"
    [ -n "$enc" ]
    local sp lvl shiny is_leg
    sp="$(jq -r '.species' <<< "$enc")"
    lvl="$(jq -r '.level' <<< "$enc")"
    shiny="$(jq -r '.shiny' <<< "$enc")"
    is_leg="$(jq -r '.is_legendary' <<< "$enc")"
    [ "$sp" = "articuno" ]
    [ "$lvl" -ge 50 ] && [ "$lvl" -le 70 ]
    [[ "$shiny" =~ ^[01]$ ]]
    [ "$is_leg" = "true" ]
    local berry
    berry="$(jq -r '.held_berry' <<< "$enc")"
    [ "$berry" = "null" ]
}
