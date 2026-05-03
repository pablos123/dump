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
