#!/usr/bin/env bash
# lib/db.bash — sqlite wrappers.
# Requires:
#   POKIDLE_DB_PATH      path to sqlite db file
#   POKIDLE_REPO_ROOT    repo root (for locating schema.sql)

: "${POKIDLE_DB_PATH:?POKIDLE_DB_PATH must be set before sourcing lib/db.bash}"

db_init() {
    local schema="${POKIDLE_REPO_ROOT}/schema.sql"
    if [[ ! -f "$schema" ]]; then
        printf 'db_init: schema.sql not found at %s\n' "$schema" >&2
        return 1
    fi
    mkdir -p -- "$(dirname -- "$POKIDLE_DB_PATH")"
    sqlite3 "$POKIDLE_DB_PATH" < "$schema"
}

db_exec() {
    sqlite3 "$POKIDLE_DB_PATH" "$@"
}

db_query() {
    sqlite3 -separator $'\t' "$POKIDLE_DB_PATH" "$@"
}

db_query_json() {
    sqlite3 -json "$POKIDLE_DB_PATH" "$@"
}

db_open_biome_session() {
    local biome="$1" started_at="$2"
    db_query "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('${biome//\'/\'\'}', $started_at); SELECT last_insert_rowid();"
}

db_close_biome_session() {
    local id="$1" ended_at="$2"
    db_exec "UPDATE biome_sessions SET ended_at=$ended_at WHERE id=$id;"
}

# Prints "id\tbiome_id\tstarted_at" of the active session, or empty.
db_active_biome_session() {
    db_query "SELECT id, biome_id, started_at FROM biome_sessions WHERE ended_at IS NULL ORDER BY id DESC LIMIT 1;"
}
