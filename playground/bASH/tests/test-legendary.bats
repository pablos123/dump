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
