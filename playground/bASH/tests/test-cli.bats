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
    export POKIDLE_CONFIG_DIR POKIDLE_CACHE_DIR POKIDLE_DATA_DIR
    export POKIDLE_NO_NOTIFY=1 POKIDLE_NO_SOUND=1
}

teardown() {
    rm -f  "$POKIDLE_DB_PATH"
    rm -rf "$POKIDLE_CONFIG_DIR" "$POKIDLE_CACHE_DIR" "$POKIDLE_DATA_DIR"
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

@test "pokidle clean --yes purges pools dir" {
    mkdir -p "$POKIDLE_CACHE_DIR/pools"
    touch "$POKIDLE_CACHE_DIR/pools/cave.json"
    run "$REPO_ROOT/pokidle" clean --yes
    [ "$status" -eq 0 ]
    [ ! -f "$POKIDLE_CACHE_DIR/pools/cave.json" ]
}
