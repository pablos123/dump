#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    export POKIDLE_DB_PATH
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib db
}

teardown() {
    rm -f "$POKIDLE_DB_PATH"
}

@test "db_init applies schema and creates all tables" {
    db_init
    run sqlite3 "$POKIDLE_DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    [ "$status" -eq 0 ]
    [[ "$output" == *"biome_sessions"* ]]
    [[ "$output" == *"daemon_state"* ]]
    [[ "$output" == *"encounters"* ]]
    [[ "$output" == *"item_drops"* ]]
}

@test "db_init is idempotent" {
    db_init
    db_init
    run sqlite3 "$POKIDLE_DB_PATH" "SELECT value FROM daemon_state WHERE key='schema_version';"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "db_exec inserts and db_query selects rows" {
    db_init
    db_exec "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);"
    run db_query "SELECT biome_id FROM biome_sessions;"
    [ "$status" -eq 0 ]
    [ "$output" = "cave" ]
}

@test "db_query_json returns valid JSON array" {
    db_init
    db_exec "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);"
    db_exec "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700001000);"
    run db_query_json "SELECT biome_id, started_at FROM biome_sessions ORDER BY id;"
    [ "$status" -eq 0 ]
    # Validate it parses as JSON and has 2 elements
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "2" ]
}

@test "db_open_biome_session inserts and returns session id" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    [[ "$id" =~ ^[0-9]+$ ]]
    run db_query "SELECT biome_id FROM biome_sessions WHERE id=$id;"
    [ "$output" = "cave" ]
}

@test "db_close_biome_session sets ended_at" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    db_close_biome_session "$id" 1700003600
    run db_query "SELECT ended_at FROM biome_sessions WHERE id=$id;"
    [ "$output" = "1700003600" ]
}

@test "db_active_biome_session returns the open one" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    run db_active_biome_session
    [ "$status" -eq 0 ]
    [[ "$output" == *"cave"* ]]
    [[ "$output" == *"$id"* ]]
}

@test "db_active_biome_session returns empty when none open" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    db_close_biome_session "$id" 1700003600
    run db_active_biome_session
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "db_insert_encounter persists all columns" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"

    local enc='{
        "session_id": '"$sid"',
        "encountered_at": 1700000123,
        "species": "zubat",
        "dex_id": 41,
        "level": 7,
        "nature": "adamant",
        "ability": "inner-focus",
        "is_hidden_ability": 0,
        "gender": "M",
        "shiny": 0,
        "held_berry": null,
        "ivs": [10,20,30,15,5,25],
        "evs": [0,0,0,0,0,0],
        "stats": [22,18,15,12,15,30],
        "moves": ["leech-life","supersonic","astonish","bite"],
        "sprite_path": "/tmp/zubat.png"
    }'
    db_insert_encounter "$enc"

    run db_query "SELECT species, level, nature, moves_json FROM encounters;"
    [ "$status" -eq 0 ]
    [[ "$output" == *"zubat"* ]]
    [[ "$output" == *"adamant"* ]]
    [[ "$output" == *"leech-life"* ]]
}

@test "db_list_encounters supports filters" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"

    db_insert_encounter '{"session_id":'"$sid"',"encountered_at":1700000100,"species":"zubat","dex_id":41,"level":7,"nature":"adamant","ability":"inner-focus","is_hidden_ability":0,"gender":"M","shiny":0,"held_berry":null,"ivs":[1,2,3,4,5,6],"evs":[0,0,0,0,0,0],"stats":[10,10,10,10,10,10],"moves":["bite"],"sprite_path":null}'
    db_insert_encounter '{"session_id":'"$sid"',"encountered_at":1700000200,"species":"pidgey","dex_id":16,"level":3,"nature":"jolly","ability":"keen-eye","is_hidden_ability":0,"gender":"F","shiny":1,"held_berry":"oran","ivs":[31,31,31,31,31,31],"evs":[0,0,0,0,0,0],"stats":[20,20,20,20,20,20],"moves":["tackle"],"sprite_path":null}'

    run db_list_encounters --shiny --limit 10
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
    [[ "$output" == *"pidgey"* ]]
}

@test "db_insert_item_drop persists" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"
    db_insert_item_drop "$sid" 1700000300 "everstone" "/tmp/es.png"
    run db_query "SELECT item FROM item_drops;"
    [ "$output" = "everstone" ]
}

@test "db_list_item_drops returns json" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"
    db_insert_item_drop "$sid" 1700000300 "everstone" "/tmp/es.png"
    db_insert_item_drop "$sid" 1700000400 "soothe-bell" "/tmp/sb.png"
    run db_list_item_drops --limit 10
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "2" ]
}

@test "db_state_set / db_state_get round-trip" {
    db_init
    db_state_set "last_pokemon_tick_target" "1700009999"
    run db_state_get "last_pokemon_tick_target"
    [ "$output" = "1700009999" ]
}

@test "db_state_get returns empty for missing key" {
    db_init
    run db_state_get "no_such_key"
    [ -z "$output" ]
}

@test "db_state_set overwrites existing value" {
    db_init
    db_state_set "k" "a"
    db_state_set "k" "b"
    run db_state_get "k"
    [ "$output" = "b" ]
}
