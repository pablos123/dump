#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
}

@test "notify_pokemon: dry-run prints rendered title and body to stdout" {
    local enc='{
        "species":"sceptile","level":42,"nature":"adamant","ability":"overgrow",
        "gender":"M","shiny":1,"held_berry":"sitrus",
        "stats":[142,198,95,129,95,152],
        "moves":["leaf-blade","dragon-claw","earthquake","x-scissor"],
        "sprite_path":"/tmp/sceptile.png",
        "biome_label":"Cave"
    }'
    run notify_pokemon "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SHINY"* ]]
    [[ "$output" == *"Sceptile"* ]]
    [[ "$output" == *"Cave"* ]]
    [[ "$output" == *"sitrus"* ]]
}

@test "notify_pokemon: not shiny -> no SHINY tag" {
    local enc='{
        "species":"zubat","level":7,"nature":"timid","ability":"inner-focus",
        "gender":"M","shiny":0,"held_berry":null,
        "stats":[22,18,15,12,15,30],
        "moves":["leech-life"],
        "sprite_path":"/tmp/zubat.png",
        "biome_label":"Cave"
    }'
    run notify_pokemon "$enc"
    [ "$status" -eq 0 ]
    [[ "$output" != *"SHINY"* ]]
    [[ "$output" == *"Zubat"* ]]
}

@test "notify_item: dry-run renders item line" {
    local item='{"item":"everstone","sprite_path":"/tmp/everstone.png","biome_label":"Cave"}'
    run notify_item "$item"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found"* ]]
    [[ "$output" == *"Everstone"* ]]
    [[ "$output" == *"Cave"* ]]
}

@test "notify_biome_change: dry-run prints title" {
    run notify_biome_change "Volcano" 42 12
    [ "$status" -eq 0 ]
    [[ "$output" == *"Biome changed"* ]]
    [[ "$output" == *"Volcano"* ]]
    [[ "$output" == *"42"* ]]
}

@test "notify_pokemon: legendary encounter emits LEGENDARY prefix + critical urgency" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_REPO_ROOT POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
    local enc out
    enc='{"species":"articuno","level":60,"nature":"timid","ability":"pressure","gender":"genderless","shiny":0,"held_berry":null,"biome_label":"Ice","stats":[210,180,200,240,220,230],"moves":["ice-beam"],"sprite_path":"","is_legendary":true}'
    out="$(notify_pokemon "$enc")"
    [[ "$out" == *"LEGENDARY"* ]]
    [[ "$out" == *"URGENCY: critical"* ]]
}

@test "notify_pokemon: shiny+legendary stacks prefixes" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_REPO_ROOT POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
    local enc out
    enc='{"species":"articuno","level":60,"nature":"timid","ability":"pressure","gender":"genderless","shiny":1,"held_berry":null,"biome_label":"Ice","stats":[210,180,200,240,220,230],"moves":["ice-beam"],"sprite_path":"","is_legendary":true}'
    out="$(notify_pokemon "$enc")"
    [[ "$out" == *"SHINY"* ]]
    [[ "$out" == *"LEGENDARY"* ]]
}

@test "notify_pokemon: non-legendary unchanged" {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_NO_NOTIFY=1
    POKIDLE_NO_SOUND=1
    export POKIDLE_REPO_ROOT POKIDLE_NO_NOTIFY POKIDLE_NO_SOUND
    load_lib notify
    local enc out
    enc='{"species":"pidgey","level":3,"nature":"jolly","ability":"keen-eye","gender":"M","shiny":0,"held_berry":null,"biome_label":"Plain","stats":[20,18,16,12,14,22],"moves":["tackle"],"sprite_path":""}'
    out="$(notify_pokemon "$enc")"
    [[ "$out" == *"URGENCY: normal"* ]]
    [[ "$out" != *"LEGENDARY"* ]]
}
