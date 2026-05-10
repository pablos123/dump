#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    source "$REPO_ROOT/lib/evolution.bash"
}

@test "evolution_check_hard_filters: gender mismatch -> fail" {
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"gender":1}'   # 1 = female-only per PokeAPI canonical; encounter is M -> mismatch
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: gender match -> pass" {
    local enc='{"gender":"F","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"gender":1}'   # 1 = female-only per PokeAPI canonical; encounter is F -> match
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -eq 0 ]
}

@test "evolution_check_hard_filters: min_level below threshold -> fail" {
    local enc='{"gender":"M","level":15,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"min_level":20}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: min_happiness below -> fail" {
    local enc='{"gender":"M","level":40,"friendship":150,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"min_happiness":220}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: time_of_day mismatch -> fail" {
    EVOLUTION_TIME_OF_DAY=day
    export EVOLUTION_TIME_OF_DAY
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local evo='{"time_of_day":"night"}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: known_move not in list -> fail" {
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":["tackle","growl"]}'
    local evo='{"known_move":{"name":"mimic"}}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_check_hard_filters: known_move in list -> pass" {
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":["mimic"]}'
    local evo='{"known_move":{"name":"mimic"}}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -eq 0 ]
}

@test "evolution_check_hard_filters: relative_physical_stats atk>def required, atk<=def -> fail" {
    # encounter.stats indices: 0=hp, 1=atk, 2=def, 3=spa, 4=spd, 5=spe
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,15,20,20,20,20],"moves":[]}'
    local evo='{"relative_physical_stats":1}'
    run evolution_check_hard_filters "$enc" "$evo"
    [ "$status" -ne 0 ]
}

@test "evolution_path_kind: use-item with item -> item kind" {
    local evo='{"item":{"name":"water-stone"},"trigger":{"name":"use-item"}}'
    [ "$(evolution_path_kind "$evo")" = "item" ]
}

@test "evolution_path_kind: held_item -> item kind" {
    local evo='{"held_item":{"name":"kings-rock"}}'
    [ "$(evolution_path_kind "$evo")" = "item" ]
}

@test "evolution_path_kind: bare level evo -> synthetic" {
    local evo='{"min_level":16,"trigger":{"name":"level-up"}}'
    [ "$(evolution_path_kind "$evo")" = "synthetic" ]
}

@test "evolution_path_item_name extracts name from item or held_item" {
    [ "$(evolution_path_item_name '{"item":{"name":"water-stone"}}')" = "water-stone" ]
    [ "$(evolution_path_item_name '{"held_item":{"name":"kings-rock"}}')" = "kings-rock" ]
    [ "$(evolution_path_item_name '{"min_level":16}')" = "" ]
}

@test "evolution_enumerate_viable_paths: synthetic only when no item" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    local enc='{"gender":"M","level":20,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local stages='[{"species":"linoone","evolution_details":[{"min_level":20,"trigger":{"name":"level-up"}}]}]'
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$status" -eq 0 ]
    [ "$(jq 'length' <<< "$output")" = "1" ]
    [ "$(jq -r '.[0].species' <<< "$output")" = "linoone" ]
    [ "$(jq -r '.[0].kind' <<< "$output")" = "synthetic" ]
}

@test "evolution_enumerate_viable_paths: item path requires item in DB" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', 1700000000);"
    local enc='{"gender":"M","level":20,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local stages='[{"species":"vaporeon","evolution_details":[
        {"item":{"name":"water-stone"},"trigger":{"name":"use-item"}}]}]'
    # No item in DB → no viable path.
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$(jq 'length' <<< "$output")" = "0" ]

    # Add item.
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO item_drops(session_id, encountered_at, item) VALUES (1, 1, 'water-stone');"
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$(jq 'length' <<< "$output")" = "1" ]
    [ "$(jq -r '.[0].kind' <<< "$output")" = "item" ]
    [ "$(jq -r '.[0].item' <<< "$output")" = "water-stone" ]
}

@test "evolution_enumerate_viable_paths: hard filter blocks evo" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    db_init
    # Female-only path: encounter is M → blocked. (PokeAPI canonical: 1=female)
    local enc='{"gender":"M","level":40,"friendship":70,"stats":[20,30,30,20,20,20],"moves":[]}'
    local stages='[{"species":"gardevoir","evolution_details":[{"min_level":30,"gender":1}]}]'
    run evolution_enumerate_viable_paths "$enc" "$stages"
    [ "$(jq 'length' <<< "$output")" = "0" ]
}
