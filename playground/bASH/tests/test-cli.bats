#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    export POKIDLE_DB_PATH
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    POKIDLE_CACHE_DIR="$BATS_TMPDIR/cache.$$"
    mkdir -p "$POKIDLE_CACHE_DIR"
    POKIDLE_DATA_DIR="$BATS_TMPDIR/data.$$"
    mkdir -p "$POKIDLE_DATA_DIR"
    POKEAPI_CACHE_DIR="$BATS_TMPDIR/papi.$$"
    mkdir -p "$POKEAPI_CACHE_DIR"
    export POKIDLE_CONFIG_DIR POKIDLE_CACHE_DIR POKIDLE_DATA_DIR POKEAPI_CACHE_DIR
    export POKIDLE_NO_NOTIFY=1 POKIDLE_NO_SOUND=1
}

teardown() {
    rm -f  "$POKIDLE_DB_PATH"
    rm -rf "$POKIDLE_CONFIG_DIR" "$POKIDLE_CACHE_DIR" "$POKIDLE_DATA_DIR" "$POKEAPI_CACHE_DIR"
}

@test "pokidle help exits 0" {
    run "$REPO_ROOT/pokidle" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "pokidle current with no session prints 'no active biome'" {
    run "$REPO_ROOT/pokidle" current
    [ "$status" -eq 0 ]
    [[ "$output" == *"no active biome"* ]]
}

@test "pokidle clean pools --yes purges pools dir" {
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    touch "$POKIDLE_CACHE_DIR/pools/cave.json"
    run "$REPO_ROOT/pokidle" clean pools --yes
    [ "$status" -eq 0 ]
    [ ! -f "$POKIDLE_CACHE_DIR/pools/cave.json" ]
}

@test "clean pools: removes biome-areas directory (legacy, no longer used)" {
    local tmpcache
    tmpcache="$(mktemp -d)"
    mkdir -p "$tmpcache/pools" "$tmpcache/biome-areas"
    : > "$tmpcache/pools/forest.json"
    : > "$tmpcache/biome-areas/forest.json"
    POKIDLE_CACHE_DIR="$tmpcache"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CACHE_DIR POKIDLE_REPO_ROOT
    run "$REPO_ROOT/pokidle" clean pools --yes
    [ "$status" -eq 0 ]
    [ ! -d "$tmpcache/pools" ]
    [ ! -d "$tmpcache/biome-areas" ]
}

@test "pokidle clean db --yes removes the sqlite db file" {
    local tmpdb
    tmpdb="$(mktemp "$BATS_TMPDIR/pokidle.XXXXXX.db")"
    POKIDLE_DB_PATH="$tmpdb"
    export POKIDLE_DB_PATH
    sqlite3 "$tmpdb" "CREATE TABLE x(a INTEGER);"
    [ -f "$tmpdb" ]
    run "$REPO_ROOT/pokidle" clean db --yes
    [ "$status" -eq 0 ]
    [ ! -f "$tmpdb" ]
}

@test "pokidle clean all --yes wipes pools + biome-areas + db" {
    local tmpcache tmpdb
    tmpcache="$(mktemp -d)"
    tmpdb="$(mktemp "$BATS_TMPDIR/pokidle.XXXXXX.db")"
    mkdir -p "$tmpcache/pools" "$tmpcache/biome-areas"
    : > "$tmpcache/pools/forest.json"
    sqlite3 "$tmpdb" "CREATE TABLE x(a INTEGER);"
    POKIDLE_CACHE_DIR="$tmpcache"
    POKIDLE_DB_PATH="$tmpdb"
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_CACHE_DIR POKIDLE_DB_PATH POKIDLE_REPO_ROOT
    run "$REPO_ROOT/pokidle" clean all --yes
    [ "$status" -eq 0 ]
    [ ! -d "$tmpcache/pools" ]
    [ ! -d "$tmpcache/biome-areas" ]
    [ ! -f "$tmpdb" ]
}

@test "pokidle clean without target prints usage and fails" {
    run "$REPO_ROOT/pokidle" clean
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage:"* ]]
}

# Helper for tick tests: seed POKEAPI_CACHE_DIR with proper layout
# (cache_path = $dir/$endpoint.json, slashes preserved as subdirs).
_seed_pokeapi_cache() {
    local d="$1"
    mkdir -p "$d/pokemon" "$d/pokemon-species" "$d/evolution-chain" "$d/nature" "$d/item" "$d/location-area"
    cp "$FIXTURE_DIR/pokemon-treecko.json"          "$d/pokemon/treecko.json"
    cp "$FIXTURE_DIR/pokemon-species-treecko.json"  "$d/pokemon-species/treecko.json"
    cp "$FIXTURE_DIR/evolution-chain-142.json"      "$d/evolution-chain/142.json"
    # nature?limit=100 → file with literal ?  in name
    cp "$FIXTURE_DIR/nature-limit-100.json"         "$d/nature?limit=100.json"
    local n
    for n in "$FIXTURE_DIR"/nature-*.json; do
        local base="${n##*/}"
        base="${base#nature-}"
        base="${base%.json}"
        [[ "$base" == "limit-100" ]] && continue
        cp "$n" "$d/nature/$base.json"
    done
    local i
    for i in "$FIXTURE_DIR"/item-*.json; do
        local base="${i##*/}"
        base="${base#item-}"
        cp "$i" "$d/item/$base"
    done
}

@test "pokidle list emits json with --json" {
    sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"
    local sid
    sid="$(sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));
         SELECT last_insert_rowid();")"
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level, nature,
            ability, is_hidden_ability, gender, shiny, held_berry,
            iv_hp,iv_atk,iv_def,iv_spa,iv_spd,iv_spe,
            ev_hp,ev_atk,ev_def,ev_spa,ev_spd,ev_spe,
            stat_hp,stat_atk,stat_def,stat_spa,stat_spd,stat_spe,
            moves_json, sprite_path)
        VALUES ($sid, $(date +%s), 'zubat', 41, 7, 'adamant', 'inner-focus', 0, 'M', 0, NULL,
            10,20,30,15,5,25,
            0,0,0,0,0,0,
            22,18,15,12,15,30,
            '[\"bite\"]', NULL);"

    run "$REPO_ROOT/pokidle" list --json --limit 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
    [[ "$output" == *"zubat"* ]]
}

@test "pokidle list --export emits showdown set text" {
    sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"
    local sid
    sid="$(sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));
         SELECT last_insert_rowid();")"
    sqlite3 "$POKIDLE_DB_PATH" "
        INSERT INTO encounters(session_id, encountered_at, species, dex_id, level, nature,
            ability, is_hidden_ability, gender, shiny, held_berry,
            iv_hp,iv_atk,iv_def,iv_spa,iv_spd,iv_spe,
            ev_hp,ev_atk,ev_def,ev_spa,ev_spd,ev_spe,
            stat_hp,stat_atk,stat_def,stat_spa,stat_spd,stat_spe,
            moves_json, sprite_path)
        VALUES ($sid, $(date +%s), 'sceptile', 254, 42, 'adamant', 'overgrow', 0, 'M', 1, 'sitrus',
            31,28,19,31,24,30,
            252,0,0,6,0,252,
            142,198,95,129,95,152,
            '[\"leaf-blade\",\"dragon-claw\",\"earthquake\",\"x-scissor\"]', NULL);"

    run "$REPO_ROOT/pokidle" list --export
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sceptile @ Sitrus Berry"* ]]
    [[ "$output" == *"Adamant Nature"* ]]
}

@test "pokidle items --json" {
    sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"
    local sid
    sid="$(sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));
         SELECT last_insert_rowid();")"
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO item_drops(session_id, encountered_at, item, sprite_path)
         VALUES ($sid, $(date +%s), 'everstone', NULL);"
    run "$REPO_ROOT/pokidle" items --json --limit 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
}

@test "pokidle stats prints totals" {
    sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));"
    run "$REPO_ROOT/pokidle" stats
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total encounters"* ]]
}

@test "pokidle tick pokemon --dry-run --no-notify --json: emits encounter without writing db" {
    sqlite3 "$POKIDLE_DB_PATH" < "$REPO_ROOT/schema.sql"
    sqlite3 "$POKIDLE_DB_PATH" \
        "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('cave', $(date +%s));"

    local pool='{"biome":"cave","built_at":"2026-05-08T00:00:00Z","schema":2,"tiers":{"common":[{"species":"treecko","min":5,"max":7}],"uncommon":[],"rare":[],"very_rare":[]}}'
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    printf '%s' "$pool" > "$POKIDLE_CACHE_DIR/pools/cave.json"

    POKEAPI_CACHE_DIR="$BATS_TMPDIR/papi.$$"
    export POKEAPI_CACHE_DIR
    _seed_pokeapi_cache "$POKEAPI_CACHE_DIR"

    run "$REPO_ROOT/pokidle" tick pokemon --dry-run --no-notify --json
    [ "$status" -eq 0 ]
    local sp
    sp="$(jq -r '.species' <<< "$output")"
    [ "$sp" = "treecko" ]

    local n
    n="$(sqlite3 "$POKIDLE_DB_PATH" "SELECT COUNT(*) FROM encounters;")"
    [ "$n" = "0" ]
}
