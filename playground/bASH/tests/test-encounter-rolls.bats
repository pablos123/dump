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

@test "encounter_ev_split: total exact, each ≤ 252" {
    local i
    for i in {1..50}; do
        local want=$((RANDOM % 511))
        local out
        out="$(encounter_ev_split "$want")"
        local arr=($out)
        [ "${#arr[@]}" -eq 6 ]
        local total=0 v
        for v in "${arr[@]}"; do
            [ "$v" -le 252 ]
            [ "$v" -ge 0 ]
            total=$((total + v))
        done
        [ "$total" -eq "$want" ]
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

@test "encounter_roll_ability: forced normal yields slot1+slot2 only" {
    POKIDLE_HIDDEN_ABILITY_RATE=0
    local i out
    for i in {1..30}; do
        out="$(encounter_roll_ability treecko)"
        local name hidden
        name="$(jq -r '.name' <<< "$out")"
        hidden="$(jq -r '.is_hidden' <<< "$out")"
        [ "$hidden" = "false" ]
        [ "$name" = "overgrow" ]
    done
}

@test "encounter_roll_ability: forced hidden yields hidden when present" {
    POKIDLE_HIDDEN_ABILITY_RATE=100
    run encounter_roll_ability treecko
    [ "$status" -eq 0 ]
    local hidden
    hidden="$(jq -r '.is_hidden' <<< "$output")"
    [ "$hidden" = "true" ]
}

@test "encounter_roll_moves: at level 5 returns 4 candidates ≤ level" {
    # Treecko fixture has level-up moves at 1,3,6,11,17 + machine/egg/tutor (level 0)
    # At level 5 candidates ≤5: pound(1), leer(3), giga-drain(0,machine), endeavor(0,egg), snatch(0,tutor) = 5 candidates
    run encounter_roll_moves treecko 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "4" ]
}

@test "encounter_roll_moves: at level 1 with limited pool returns 4 (or fewer if not enough)" {
    # Level 1: pound(1) + machine + egg + tutor = 4
    run encounter_roll_moves treecko 1
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "4" ]
}

@test "encounter_roll_gender: gender_rate -1 returns genderless" {
    run encounter_roll_gender magnemite
    [ "$status" -eq 0 ]
    [ "$output" = "genderless" ]
}

@test "encounter_roll_gender: gender_rate 1 yields ~12.5% F" {
    local f=0 m=0 i out
    for i in {1..200}; do
        out="$(encounter_roll_gender treecko)"
        case "$out" in
            F) f=$((f+1)) ;;
            M) m=$((m+1)) ;;
        esac
    done
    [ "$f" -ge 5 ]   && [ "$f" -le 60 ]
    [ "$m" -ge 140 ] && [ "$m" -le 195 ]
}

@test "encounter_roll_shiny: rate 1 always shiny" {
    POKIDLE_SHINY_RATE=1
    run encounter_roll_shiny
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "encounter_roll_shiny: rate 1000000 almost never shiny" {
    POKIDLE_SHINY_RATE=1000000
    local i s out
    s=0
    for i in {1..50}; do
        out="$(encounter_roll_shiny)"
        s=$((s + out))
    done
    [ "$s" -le 1 ]
}

@test "encounter_roll_held_berry: 0% rate returns null" {
    POKIDLE_BERRY_RATE=0
    run encounter_roll_held_berry "cave"
    [ "$status" -eq 0 ]
    [ "$output" = "null" ]
}

@test "encounter_roll_held_berry: 100% rate returns one of biome berries" {
    POKIDLE_BERRY_RATE=100
    run encounter_roll_held_berry "cave"
    [ "$status" -eq 0 ]
    # cave berry_pool: rawst, aspear, chesto, lum
    [[ "$output" =~ ^(rawst|aspear|chesto|lum)$ ]]
}

@test "encounter_roll_item: emits json with item + sprite_url" {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    run encounter_roll_item cave
    [ "$status" -eq 0 ]
    local item sprite
    item="$(jq -r '.item' <<< "$output")"
    sprite="$(jq -r '.sprite_url' <<< "$output")"
    [[ "$item" =~ ^(everstone|hard-stone|smoke-ball|dusk-stone|thick-club)$ ]]
    [[ "$sprite" == *"$item.png"* ]]
}

@test "encounter_roll_pokemon: full encounter has all required keys" {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    local entry='{"species":"treecko","min":5,"max":7,"pct":100}'
    run encounter_roll_pokemon "$entry" "cave"
    [ "$status" -eq 0 ]

    local enc="$output"
    local k
    for k in species dex_id level nature ability is_hidden_ability gender shiny held_berry ivs evs stats moves sprite_url; do
        local v
        v="$(jq -r --arg k "$k" 'has($k) | tostring' <<< "$enc")"
        [ "$v" = "true" ]
    done
}
