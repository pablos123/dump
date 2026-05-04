#!/usr/bin/env bats

load helpers

setup() {
    load_lib showdown
}

@test "showdown_format: full encounter renders correctly" {
    local enc='{
        "species":"sceptile","level":42,"nature":"adamant","ability":"overgrow",
        "is_hidden_ability":0,"gender":"M","shiny":1,"held_berry":"sitrus",
        "ivs":[31,28,19,31,24,30],
        "evs":[252,0,0,6,0,252],
        "moves":["leaf-blade","dragon-claw","earthquake","x-scissor"]
    }'
    run showdown_format "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sceptile @ Sitrus Berry"* ]]
    [[ "$output" == *"Ability: Overgrow"* ]]
    [[ "$output" == *"Level: 42"* ]]
    [[ "$output" == *"Shiny: Yes"* ]]
    [[ "$output" == *"Adamant Nature"* ]]
    [[ "$output" == *"EVs: 252 HP / 6 SpA / 252 Spe"* ]]
    [[ "$output" == *"IVs: 31 HP / 28 Atk / 19 Def / 31 SpA / 24 SpD / 30 Spe"* ]]
    [[ "$output" == *"- Leaf Blade"* ]]
    [[ "$output" == *"- Dragon Claw"* ]]
}

@test "showdown_format: no berry, not shiny, no item line, no Shiny line" {
    local enc='{
        "species":"zubat","level":7,"nature":"timid","ability":"inner-focus",
        "is_hidden_ability":0,"gender":"M","shiny":0,"held_berry":null,
        "ivs":[10,20,30,15,5,25],
        "evs":[0,0,0,0,0,0],
        "moves":["leech-life","supersonic"]
    }'
    run showdown_format "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" != *"@ "* ]]
    [[ "$output" != *"Shiny:"* ]]
    [[ "$output" == *"Zubat"* ]]
}
