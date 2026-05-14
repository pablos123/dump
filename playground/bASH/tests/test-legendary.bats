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

@test "tick legendary --dry-run: rolls but does not insert" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_CHANCE=100
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_CHANCE POKIDLE_NO_NOTIFY
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700000000);"
    run "$REPO_ROOT/pokidle" tick legendary --dry-run
    [ "$status" -eq 0 ]
    local count
    count="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$count" = "0" ]
}

@test "tick legendary --no-dry-run: inserts encounter when chance is 100" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_CHANCE=100
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_CHANCE POKIDLE_NO_NOTIFY
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700000000);"
    run "$REPO_ROOT/pokidle" tick legendary --no-dry-run --json
    [ "$status" -eq 0 ]
    local count is_in_roster sp
    count="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$count" = "1" ]
    sp="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT species FROM encounters LIMIT 1;")"
    load_lib legendary
    is_in_roster=0
    local s
    for s in "${LEGENDARY_SPECIES[@]}"; do
        [[ "$s" == "$sp" ]] && is_in_roster=1 && break
    done
    [ "$is_in_roster" = "1" ]
}

@test "tick legendary: no spawn when chance is 0" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    POKIDLE_LEGENDARY_CHANCE=0
    POKIDLE_NO_NOTIFY=1
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT POKIDLE_LEGENDARY_CHANCE POKIDLE_NO_NOTIFY
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('forest', 1700000000);"
    run "$REPO_ROOT/pokidle" tick legendary --no-dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"no spawn"* ]]
    local count
    count="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$count" = "0" ]
}
