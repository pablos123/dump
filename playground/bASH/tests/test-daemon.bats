#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    export POKIDLE_DB_PATH
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    load_lib db
    db_init
}

teardown() {
    rm -f "$POKIDLE_DB_PATH"
}

# Source pokidle as a library by extracting its functions.
# We do this by sourcing the script with a guard so it doesn't dispatch.
source_pokidle_lib() {
    POKIDLE_TEST_SOURCE_ONLY=1 source "$REPO_ROOT/pokidle"
}

@test "schedule_next_tick: target is in [next_hour, next_hour+interval)" {
    POKIDLE_POKEMON_INTERVAL=3600
    source_pokidle_lib
    local now=1700000000   # epoch
    local next
    next="$(_pokidle_next_tick_target "$now" "$POKIDLE_POKEMON_INTERVAL")"
    local hour_floor=$((now / 3600 * 3600))
    local next_hour=$((hour_floor + 3600))
    [ "$next" -ge "$next_hour" ]
    [ "$next" -lt "$((next_hour + 3600))" ]
}

@test "_pokidle_should_rotate_biome: 3h elapsed yes" {
    POKIDLE_BIOME_HOURS=3
    source_pokidle_lib
    local now=1700010800   # 3h+ after 1700000000
    run _pokidle_should_rotate_biome 1700000000 "$now"
    [ "$status" -eq 0 ]
}

@test "_pokidle_should_rotate_biome: 1h elapsed no" {
    POKIDLE_BIOME_HOURS=3
    source_pokidle_lib
    local now=1700003600
    run _pokidle_should_rotate_biome 1700000000 "$now"
    [ "$status" -ne 0 ]
}

@test "schedule_next_tick: POKIDLE_TICK_FAST=1 uses cadence in [now, now+interval)" {
    POKIDLE_TICK_FAST=1 source_pokidle_lib
    local now=1700000000
    local interval=60
    local next
    next="$(POKIDLE_TICK_FAST=1 _pokidle_next_tick_target "$now" "$interval")"
    [ "$next" -ge "$now" ]
    [ "$next" -lt "$((now + interval))" ]
}
