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
