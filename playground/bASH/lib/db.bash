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

# Insert an encounter described by a JSON object on stdin or argv[1].
# Required keys: session_id, encountered_at, species, dex_id, level, nature,
# ability, is_hidden_ability, gender, shiny, held_berry, ivs[6], evs[6],
# stats[6], moves[], sprite_path.
db_insert_encounter() {
    local enc="$1"
    local sql
    sql="$(jq -r '
        @sh "INSERT INTO encounters (
            session_id, encountered_at, species, dex_id, level,
            nature, ability, is_hidden_ability, gender, shiny, held_berry,
            iv_hp, iv_atk, iv_def, iv_spa, iv_spd, iv_spe,
            ev_hp, ev_atk, ev_def, ev_spa, ev_spd, ev_spe,
            stat_hp, stat_atk, stat_def, stat_spa, stat_spd, stat_spe,
            moves_json, sprite_path
        ) VALUES (
            \(.session_id),
            \(.encountered_at),
            \(.species),
            \(.dex_id),
            \(.level),
            \(.nature),
            \(.ability),
            \(.is_hidden_ability),
            \(.gender),
            \(.shiny),
            \(.held_berry // "NULL_SENTINEL"),
            \(.ivs[0]), \(.ivs[1]), \(.ivs[2]), \(.ivs[3]), \(.ivs[4]), \(.ivs[5]),
            \(.evs[0]), \(.evs[1]), \(.evs[2]), \(.evs[3]), \(.evs[4]), \(.evs[5]),
            \(.stats[0]), \(.stats[1]), \(.stats[2]), \(.stats[3]), \(.stats[4]), \(.stats[5]),
            \(.moves | tojson),
            \(.sprite_path // "NULL_SENTINEL")
        );"
    ' <<< "$enc")"
    # @sh quotes everything; replace NULL_SENTINEL strings with NULL
    sql="${sql//\'NULL_SENTINEL\'/NULL}"
    db_exec "$sql"
}

# List encounters as JSON. Supports filters parsed from argv:
#   --shiny --since YYYY-MM-DD --until YYYY-MM-DD --biome <id>
#   --species <name> --nature <name> --min-iv-total N --limit N
db_list_encounters() {
    local where=() limit=50
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --shiny)         where+=("e.shiny=1"); shift ;;
            --since)         where+=("e.encountered_at >= $(date -d "$2" +%s)"); shift 2 ;;
            --until)         where+=("e.encountered_at <= $(date -d "$2" +%s)"); shift 2 ;;
            --biome)         where+=("s.biome_id='${2//\'/\'\'}'"); shift 2 ;;
            --species)       where+=("e.species LIKE '%${2//\'/\'\'}%'"); shift 2 ;;
            --nature)        where+=("e.nature='${2//\'/\'\'}'"); shift 2 ;;
            --min-iv-total)  where+=("(e.iv_hp+e.iv_atk+e.iv_def+e.iv_spa+e.iv_spd+e.iv_spe) >= $2"); shift 2 ;;
            --limit)         limit="$2"; shift 2 ;;
            *)               shift ;;
        esac
    done
    local sql="SELECT e.*, s.biome_id FROM encounters e JOIN biome_sessions s ON s.id=e.session_id"
    if (( ${#where[@]} )); then
        local joined
        printf -v joined '%s AND ' "${where[@]}"
        sql+=" WHERE ${joined% AND }"
    fi
    sql+=" ORDER BY e.encountered_at DESC LIMIT $limit;"
    db_query_json "$sql"
}

db_insert_item_drop() {
    local session_id="$1" ts="$2" item="$3" sprite="$4"
    local sprite_sql="NULL"
    [[ -n "$sprite" ]] && sprite_sql="'${sprite//\'/\'\'}'"
    db_exec "INSERT INTO item_drops(session_id, encountered_at, item, sprite_path)
             VALUES ($session_id, $ts, '${item//\'/\'\'}', $sprite_sql);"
}

db_list_item_drops() {
    local where=() limit=50
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --since)  where+=("d.encountered_at >= $(date -d "$2" +%s)"); shift 2 ;;
            --until)  where+=("d.encountered_at <= $(date -d "$2" +%s)"); shift 2 ;;
            --biome)  where+=("s.biome_id='${2//\'/\'\'}'"); shift 2 ;;
            --item)   where+=("d.item LIKE '%${2//\'/\'\'}%'"); shift 2 ;;
            --limit)  limit="$2"; shift 2 ;;
            *)        shift ;;
        esac
    done
    local sql="SELECT d.*, s.biome_id FROM item_drops d JOIN biome_sessions s ON s.id=d.session_id"
    if (( ${#where[@]} )); then
        local joined
        printf -v joined '%s AND ' "${where[@]}"
        sql+=" WHERE ${joined% AND }"
    fi
    sql+=" ORDER BY d.encountered_at DESC LIMIT $limit;"
    db_query_json "$sql"
}

db_state_set() {
    local key="$1" value="$2"
    db_exec "INSERT INTO daemon_state(key, value) VALUES ('${key//\'/\'\'}', '${value//\'/\'\'}')
             ON CONFLICT(key) DO UPDATE SET value=excluded.value;"
}

db_state_get() {
    local key="$1"
    db_query "SELECT value FROM daemon_state WHERE key='${key//\'/\'\'}';"
}
