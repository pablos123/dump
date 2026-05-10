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

@test "evolution_apply: synthetic path updates encounter species/dex/sprite/stats" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    load_lib encounter
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship,
            iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe)
            VALUES (1, 1700000000, 'zigzagoon', 263, 20, 'hardy', 'pickup', 0, 'M', 0, '[]',
                70, 10,10,10,10,10,10, 0,0,0,0,0,0);"

    pokeapi_get() {
        case "$1" in
            pokemon/linoone)
                printf '%s' '{"id":264,"sprites":{"front_default":"linoone.png","front_shiny":""},
                  "stats":[
                    {"base_stat":78,"stat":{"name":"hp"}},
                    {"base_stat":70,"stat":{"name":"attack"}},
                    {"base_stat":61,"stat":{"name":"defense"}},
                    {"base_stat":50,"stat":{"name":"special-attack"}},
                    {"base_stat":61,"stat":{"name":"special-defense"}},
                    {"base_stat":100,"stat":{"name":"speed"}}]}'
                ;;
            nature/hardy) printf '{"increased_stat":null,"decreased_stat":null}' ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get

    local path='{"species":"linoone","kind":"synthetic","evo":{"min_level":20}}'
    run evolution_apply 1 "$path"
    [ "$status" -eq 0 ]
    local row
    row="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT species||','||dex_id||','||sprite_path FROM encounters WHERE id=1;")"
    [ "$row" = "linoone,264,linoone.png" ]
}

@test "evolution_apply: item path consumes one item_drops row" {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    load_lib db
    load_lib encounter
    db_init
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO biome_sessions(biome_id, started_at) VALUES ('plain', 1700000000);
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, moves_json, friendship,
            iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe)
            VALUES (1, 1700000000, 'eevee', 133, 20, 'hardy', 'run-away', 0, 'M', 0, '[]',
                70, 10,10,10,10,10,10, 0,0,0,0,0,0);
        INSERT INTO item_drops(session_id, encountered_at, item) VALUES
            (1, 1, 'water-stone'),
            (1, 2, 'water-stone');"

    pokeapi_get() {
        case "$1" in
            pokemon/vaporeon)
                printf '%s' '{"id":134,"sprites":{"front_default":"vap.png","front_shiny":""},
                  "stats":[
                    {"base_stat":130,"stat":{"name":"hp"}},
                    {"base_stat":65,"stat":{"name":"attack"}},
                    {"base_stat":60,"stat":{"name":"defense"}},
                    {"base_stat":110,"stat":{"name":"special-attack"}},
                    {"base_stat":95,"stat":{"name":"special-defense"}},
                    {"base_stat":65,"stat":{"name":"speed"}}]}'
                ;;
            nature/hardy) printf '{"increased_stat":null,"decreased_stat":null}' ;;
            *) return 1 ;;
        esac
    }
    export -f pokeapi_get

    local path='{"species":"vaporeon","kind":"item","item":"water-stone","evo":{}}'
    evolution_apply 1 "$path"
    local n
    n="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM item_drops WHERE item='water-stone';")"
    [ "$n" = "1" ]
}
