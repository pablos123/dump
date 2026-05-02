# pokidle Plan A: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the foundation layer of pokidle — test harness, HTTP rate-limit, pokeapi rename, SQLite database (`lib/db.bash` + `schema.sql`), and biome config + classifier + rotation (`lib/biome.bash` + `config/biomes.json`). At the end of Plan A, biomes can be loaded, classified, and rotated; encounters can be persisted and queried via direct library calls (no encounter engine yet).

**Architecture:** bats-core test harness sourcing real libs against ephemeral temp DBs. SQLite accessed via the `sqlite3` CLI per call (no long-lived connection). Existing `pokeapi.bash` is renamed to `pokeapi` and gains a 0.5 s post-fetch sleep. New `lib/db.bash` and `lib/biome.bash` are pure bash that depend only on `jq` and `sqlite3`. `config/biomes.json` ships with the repo and is the template for `pokidle setup` (Plan C).

**Tech Stack:** bash 4+, jq, sqlite3, curl (existing), bats-core (test).

**Spec reference:** `docs/superpowers/specs/2026-05-02-pokidle-design.md`.

---

## File map (Plan A)

| File | Status | Responsibility |
|---|---|---|
| `pokeapi` | rename from `pokeapi.bash` | generic API CLI entry (unchanged surface) |
| `lib/http.bash` | modify | add 0.5 s post-fetch sleep |
| `schema.sql` | create | SQLite schema |
| `lib/db.bash` | create | sqlite wrappers, schema init, CRUD |
| `lib/biome.bash` | create | config loader, classifier, rotation |
| `config/biomes.json` | create | 18 biomes with curated berry/item pools |
| `tests/helpers.bash` | create | bats helper (source libs, temp DB, fixtures) |
| `tests/test-db.bats` | create | DB layer tests |
| `tests/test-biome-config.bats` | create | config loader tests |
| `tests/test-biome-classifier.bats` | create | classifier tests |
| `tests/test-biome-rotation.bats` | create | rotation tests |
| `tests/fixtures/area-*.json` | create | minimal `/location-area` fixtures |
| `.gitignore` | create/modify | ignore `tests/tmp/` |

---

## Task 1: Verify and document test toolchain

**Files:**
- Create: `tests/README.md`
- Create: `.gitignore` (or modify if present)

- [ ] **Step 1: Confirm bats-core is installed**

Run:
```bash
command -v bats || echo "NOT INSTALLED"
bats --version 2>/dev/null || true
```

If missing, document install for the executor:
```bash
# Debian/Ubuntu
sudo apt-get install bats

# Or vendor it
git clone --depth=1 https://github.com/bats-core/bats-core.git tests/bats
```

- [ ] **Step 2: Create `tests/README.md`**

```markdown
# Tests

Run all:

```
bats tests/
```

Run one file:

```
bats tests/test-db.bats
```

Tests use ephemeral SQLite files via mktemp and stub `pokeapi_get` against
JSON fixtures under `tests/fixtures/`. Each test cleans up after itself.
```

- [ ] **Step 3: Create or update `.gitignore`**

```
tests/tmp/
*.swp
```

- [ ] **Step 4: Commit**

```bash
git add tests/README.md .gitignore
git commit -m "test: bats-core scaffolding docs and gitignore"
```

---

## Task 2: HTTP rate-limit

**Files:**
- Modify: `lib/http.bash`
- Create: `tests/test-http-ratelimit.bats`

- [ ] **Step 1: Write the failing test**

Create `tests/test-http-ratelimit.bats`:

```bash
#!/usr/bin/env bats

load helpers

@test "http_get sleeps POKEAPI_RATE_LIMIT_SLEEP seconds after a fetch" {
    # Stub curl to return immediately
    curl() { printf 'OK\n200'; }
    export -f curl

    POKEAPI_RATE_LIMIT_SLEEP=1
    POKEAPI_BASE_URL="http://stub.local"
    source "$LIB_DIR/http.bash"

    local start end elapsed
    start=$(date +%s)
    run http_get "pokemon/1"
    end=$(date +%s)
    elapsed=$((end - start))

    [ "$status" -eq 0 ]
    [ "$elapsed" -ge 1 ]
}

@test "http_get rate-limit defaults to 0.5 when var unset" {
    curl() { printf 'OK\n200'; }
    export -f curl
    unset POKEAPI_RATE_LIMIT_SLEEP
    POKEAPI_BASE_URL="http://stub.local"
    source "$LIB_DIR/http.bash"

    # Just assert no crash and value path resolves
    run http_get "pokemon/1"
    [ "$status" -eq 0 ]
}
```

Note: `tests/helpers.bash` is created in Task 4 — this test will fail to load it until then. We'll come back and run it after Task 4. For now write the test and move on.

- [ ] **Step 2: Modify `lib/http.bash`**

After the existing `printf '%s' "${body}"` line at the end of `http_get`, insert the sleep:

Open `lib/http.bash`. The current `http_get` ends with:

```bash
    printf '%s' "${body}"
}
```

Change it to:

```bash
    printf '%s' "${body}"
    # Be polite: pause after every live fetch (cache misses only — pokeapi_get
    # short-circuits on cache hits).
    sleep "${POKEAPI_RATE_LIMIT_SLEEP:-0.5}"
}
```

- [ ] **Step 3: Manual sanity check**

```bash
time bash -c 'POKEAPI_RATE_LIMIT_SLEEP=0 source lib/http.bash; \
              curl(){ printf "OK\n200"; }; export -f curl; \
              POKEAPI_BASE_URL=http://x http_get x'
```

Should complete in well under 0.5 s (rate-limit disabled).

- [ ] **Step 4: Commit**

```bash
git add lib/http.bash tests/test-http-ratelimit.bats
git commit -m "feat(http): add POKEAPI_RATE_LIMIT_SLEEP post-fetch delay"
```

---

## Task 3: Rename `pokeapi.bash` → `pokeapi`

**Files:**
- Rename: `pokeapi.bash` → `pokeapi`

- [ ] **Step 1: Rename via git**

```bash
git mv pokeapi.bash pokeapi
```

- [ ] **Step 2: Verify it still runs**

```bash
./pokeapi help | head -5
```

Expected: usage banner.

```bash
./pokeapi natures | wc -l
```

Expected: `25`.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: rename pokeapi.bash -> pokeapi"
```

---

## Task 4: Test helpers

**Files:**
- Create: `tests/helpers.bash`

- [ ] **Step 1: Write `tests/helpers.bash`**

```bash
# Sourced by every .bats file via `load helpers`.
# Provides: REPO_ROOT, LIB_DIR, mktemp DB, fixture loader, pokeapi_get stub.

REPO_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/.." && pwd)"
LIB_DIR="${REPO_ROOT}/lib"
FIXTURE_DIR="${BATS_TEST_DIRNAME}/fixtures"

# Per-test temp dirs cleaned up by bats automatically when BATS_TMPDIR.
make_tmp_db() {
    local f
    f="$(mktemp "${BATS_TMPDIR}/pokidle.XXXXXX.db")"
    printf '%s' "$f"
}

load_lib() {
    local name="$1"
    # shellcheck disable=SC1090
    source "${LIB_DIR}/${name}.bash"
}

# Replace pokeapi_get with a fixture-backed stub.
# Fixtures live at tests/fixtures/<endpoint-with-slash-as-dash>.json
stub_pokeapi() {
    pokeapi_get() {
        local endpoint="$1"
        local key="${endpoint//\//-}"
        key="${key//\?/-}"
        key="${key//=/-}"
        local f="${FIXTURE_DIR}/${key}.json"
        if [[ ! -f "$f" ]]; then
            printf 'stub_pokeapi: missing fixture %s\n' "$f" >&2
            return 1
        fi
        cat "$f"
    }
    export -f pokeapi_get
}
```

- [ ] **Step 2: Now run Task 2 tests**

```bash
bats tests/test-http-ratelimit.bats
```

Expected: 2 passed.

- [ ] **Step 3: Commit**

```bash
git add tests/helpers.bash
git commit -m "test: bats helpers (tmp db, lib loader, pokeapi stub)"
```

---

## Task 5: Schema

**Files:**
- Create: `schema.sql`

- [ ] **Step 1: Write `schema.sql`**

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS biome_sessions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    biome_id        TEXT NOT NULL,
    started_at      INTEGER NOT NULL,
    ended_at        INTEGER
);
CREATE INDEX IF NOT EXISTS idx_biome_sessions_active
    ON biome_sessions(ended_at) WHERE ended_at IS NULL;

CREATE TABLE IF NOT EXISTS encounters (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      INTEGER NOT NULL REFERENCES biome_sessions(id),
    encountered_at  INTEGER NOT NULL,
    species         TEXT NOT NULL,
    dex_id          INTEGER NOT NULL,
    level           INTEGER NOT NULL,
    nature          TEXT NOT NULL,
    ability         TEXT NOT NULL,
    is_hidden_ability INTEGER NOT NULL,
    gender          TEXT NOT NULL,
    shiny           INTEGER NOT NULL,
    held_berry      TEXT,
    iv_hp INTEGER, iv_atk INTEGER, iv_def INTEGER,
    iv_spa INTEGER, iv_spd INTEGER, iv_spe INTEGER,
    ev_hp INTEGER, ev_atk INTEGER, ev_def INTEGER,
    ev_spa INTEGER, ev_spd INTEGER, ev_spe INTEGER,
    stat_hp INTEGER, stat_atk INTEGER, stat_def INTEGER,
    stat_spa INTEGER, stat_spd INTEGER, stat_spe INTEGER,
    moves_json      TEXT NOT NULL,
    sprite_path     TEXT
);
CREATE INDEX IF NOT EXISTS idx_enc_session ON encounters(session_id);
CREATE INDEX IF NOT EXISTS idx_enc_shiny   ON encounters(shiny) WHERE shiny=1;
CREATE INDEX IF NOT EXISTS idx_enc_species ON encounters(species);
CREATE INDEX IF NOT EXISTS idx_enc_time    ON encounters(encountered_at);

CREATE TABLE IF NOT EXISTS item_drops (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      INTEGER NOT NULL REFERENCES biome_sessions(id),
    encountered_at  INTEGER NOT NULL,
    item            TEXT NOT NULL,
    sprite_path     TEXT
);
CREATE INDEX IF NOT EXISTS idx_item_session ON item_drops(session_id);
CREATE INDEX IF NOT EXISTS idx_item_time    ON item_drops(encountered_at);

CREATE TABLE IF NOT EXISTS daemon_state (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT OR IGNORE INTO daemon_state (key, value) VALUES ('schema_version', '1');
```

- [ ] **Step 2: Commit**

```bash
git add schema.sql
git commit -m "feat(db): initial sqlite schema"
```

---

## Task 6: `lib/db.bash` core wrappers

**Files:**
- Create: `lib/db.bash`
- Create: `tests/test-db.bats`

- [ ] **Step 1: Write the failing test**

`tests/test-db.bats`:

```bash
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
```

- [ ] **Step 2: Run test, expect fail**

```bash
bats tests/test-db.bats
```

Expected: all fail with `db_init: command not found` or similar (lib/db.bash empty).

- [ ] **Step 3: Implement `lib/db.bash`**

```bash
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
```

- [ ] **Step 4: Run tests, expect pass**

```bash
bats tests/test-db.bats
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "feat(db): core sqlite wrappers (init/exec/query/query_json)"
```

---

## Task 7: `lib/db.bash` — biome_sessions helpers

**Files:**
- Modify: `lib/db.bash`
- Modify: `tests/test-db.bats`

- [ ] **Step 1: Add tests for session CRUD**

Append to `tests/test-db.bats`:

```bash
@test "db_open_biome_session inserts and returns session id" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    [[ "$id" =~ ^[0-9]+$ ]]
    run db_query "SELECT biome_id FROM biome_sessions WHERE id=$id;"
    [ "$output" = "cave" ]
}

@test "db_close_biome_session sets ended_at" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    db_close_biome_session "$id" 1700003600
    run db_query "SELECT ended_at FROM biome_sessions WHERE id=$id;"
    [ "$output" = "1700003600" ]
}

@test "db_active_biome_session returns the open one" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    run db_active_biome_session
    [ "$status" -eq 0 ]
    [[ "$output" == *"cave"* ]]
    [[ "$output" == *"$id"* ]]
}

@test "db_active_biome_session returns empty when none open" {
    db_init
    local id
    id="$(db_open_biome_session 'cave' 1700000000)"
    db_close_biome_session "$id" 1700003600
    run db_active_biome_session
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-db.bats
```

Expected: 4 new tests fail.

- [ ] **Step 3: Implement helpers**

Append to `lib/db.bash`:

```bash
db_open_biome_session() {
    local biome="$1" started_at="$2"
    db_exec "INSERT INTO biome_sessions(biome_id, started_at) VALUES ('${biome//\'/\'\'}', $started_at);"
    db_query "SELECT last_insert_rowid();"
}

db_close_biome_session() {
    local id="$1" ended_at="$2"
    db_exec "UPDATE biome_sessions SET ended_at=$ended_at WHERE id=$id;"
}

# Prints "id\tbiome_id\tstarted_at" of the active session, or empty.
db_active_biome_session() {
    db_query "SELECT id, biome_id, started_at FROM biome_sessions WHERE ended_at IS NULL ORDER BY id DESC LIMIT 1;"
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-db.bats
```

Expected: all 8 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "feat(db): biome_session open/close/active helpers"
```

---

## Task 8: `lib/db.bash` — encounter & item helpers

**Files:**
- Modify: `lib/db.bash`
- Modify: `tests/test-db.bats`

- [ ] **Step 1: Add tests**

Append to `tests/test-db.bats`:

```bash
@test "db_insert_encounter persists all columns" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"

    local enc='{
        "session_id": '"$sid"',
        "encountered_at": 1700000123,
        "species": "zubat",
        "dex_id": 41,
        "level": 7,
        "nature": "adamant",
        "ability": "inner-focus",
        "is_hidden_ability": 0,
        "gender": "M",
        "shiny": 0,
        "held_berry": null,
        "ivs": [10,20,30,15,5,25],
        "evs": [0,0,0,0,0,0],
        "stats": [22,18,15,12,15,30],
        "moves": ["leech-life","supersonic","astonish","bite"],
        "sprite_path": "/tmp/zubat.png"
    }'
    db_insert_encounter "$enc"

    run db_query "SELECT species, level, nature, moves_json FROM encounters;"
    [ "$status" -eq 0 ]
    [[ "$output" == *"zubat"* ]]
    [[ "$output" == *"adamant"* ]]
    [[ "$output" == *"leech-life"* ]]
}

@test "db_list_encounters supports filters" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"

    db_insert_encounter '{"session_id":'"$sid"',"encountered_at":1700000100,"species":"zubat","dex_id":41,"level":7,"nature":"adamant","ability":"inner-focus","is_hidden_ability":0,"gender":"M","shiny":0,"held_berry":null,"ivs":[1,2,3,4,5,6],"evs":[0,0,0,0,0,0],"stats":[10,10,10,10,10,10],"moves":["bite"],"sprite_path":null}'
    db_insert_encounter '{"session_id":'"$sid"',"encountered_at":1700000200,"species":"pidgey","dex_id":16,"level":3,"nature":"jolly","ability":"keen-eye","is_hidden_ability":0,"gender":"F","shiny":1,"held_berry":"oran","ivs":[31,31,31,31,31,31],"evs":[0,0,0,0,0,0],"stats":[20,20,20,20,20,20],"moves":["tackle"],"sprite_path":null}'

    run db_list_encounters --shiny --limit 10
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
    [[ "$output" == *"pidgey"* ]]
}

@test "db_insert_item_drop persists" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"
    db_insert_item_drop "$sid" 1700000300 "everstone" "/tmp/es.png"
    run db_query "SELECT item FROM item_drops;"
    [ "$output" = "everstone" ]
}

@test "db_list_item_drops returns json" {
    db_init
    local sid
    sid="$(db_open_biome_session 'cave' 1700000000)"
    db_insert_item_drop "$sid" 1700000300 "everstone" "/tmp/es.png"
    db_insert_item_drop "$sid" 1700000400 "soothe-bell" "/tmp/sb.png"
    run db_list_item_drops --limit 10
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "2" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-db.bats
```

Expected: 4 new fail.

- [ ] **Step 3: Implement**

Append to `lib/db.bash`:

```bash
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
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-db.bats
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "feat(db): encounter and item_drop CRUD with filters"
```

---

## Task 9: `lib/db.bash` — daemon_state helpers

**Files:**
- Modify: `lib/db.bash`
- Modify: `tests/test-db.bats`

- [ ] **Step 1: Add tests**

```bash
@test "db_state_set / db_state_get round-trip" {
    db_init
    db_state_set "last_pokemon_tick_target" "1700009999"
    run db_state_get "last_pokemon_tick_target"
    [ "$output" = "1700009999" ]
}

@test "db_state_get returns empty for missing key" {
    db_init
    run db_state_get "no_such_key"
    [ -z "$output" ]
}

@test "db_state_set overwrites existing value" {
    db_init
    db_state_set "k" "a"
    db_state_set "k" "b"
    run db_state_get "k"
    [ "$output" = "b" ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-db.bats
```

- [ ] **Step 3: Implement**

Append to `lib/db.bash`:

```bash
db_state_set() {
    local key="$1" value="$2"
    db_exec "INSERT INTO daemon_state(key, value) VALUES ('${key//\'/\'\'}', '${value//\'/\'\'}')
             ON CONFLICT(key) DO UPDATE SET value=excluded.value;"
}

db_state_get() {
    local key="$1"
    db_query "SELECT value FROM daemon_state WHERE key='${key//\'/\'\'}';"
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-db.bats
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/db.bash tests/test-db.bats
git commit -m "feat(db): daemon_state get/set helpers"
```

---

## Task 10: `config/biomes.json` — initial 18 biomes

**Files:**
- Create: `config/biomes.json`

- [ ] **Step 1: Author the config**

Create `config/biomes.json` with 18 biomes plus pool curation. Each `berry_pool` and `item_pool` is a list of PokeAPI item names.

```json
{
  "biomes": [
    {
      "id": "cave",
      "label": "Cave",
      "name_regex": "(?i)cave|cavern|grotto|tunnel|mine",
      "type_affinity": ["rock", "ground", "dark"],
      "berry_pool": ["rawst", "aspear", "chesto", "lum"],
      "item_pool": ["everstone", "hard-stone", "smoke-ball", "dusk-stone", "thick-club"]
    },
    {
      "id": "desert",
      "label": "Desert",
      "name_regex": "(?i)desert|dunes|sand",
      "type_affinity": ["ground", "fire"],
      "berry_pool": ["watmel", "figy", "rabuta"],
      "item_pool": ["soft-sand", "heat-rock", "stick"]
    },
    {
      "id": "forest",
      "label": "Forest",
      "name_regex": "(?i)forest|woods|jungle",
      "type_affinity": ["grass", "bug"],
      "berry_pool": ["chesto", "pecha", "leppa", "oran", "leaf"],
      "item_pool": ["leaf-stone", "miracle-seed", "silver-powder", "shed-shell"]
    },
    {
      "id": "mountain",
      "label": "Mountain",
      "name_regex": "(?i)mt-|mountain|peak|summit",
      "type_affinity": ["rock", "ice", "flying"],
      "berry_pool": ["cheri", "persim", "kee"],
      "item_pool": ["sharp-beak", "sky-plate", "rocky-helmet"]
    },
    {
      "id": "volcano",
      "label": "Volcano",
      "name_regex": "(?i)volcano|crater|magma|lava",
      "type_affinity": ["fire", "rock"],
      "berry_pool": ["occa", "rowap", "jaboca"],
      "item_pool": ["fire-stone", "charcoal", "magmarizer", "flame-plate"]
    },
    {
      "id": "plain",
      "label": "Plain",
      "name_regex": "(?i)route-[0-9]+|meadow|field|plains",
      "type_affinity": ["normal", "flying", "grass"],
      "berry_pool": ["pecha", "lum", "sitrus", "iapapa"],
      "item_pool": ["silk-scarf", "lucky-egg", "exp-share"]
    },
    {
      "id": "savanna",
      "label": "Savanna",
      "name_regex": "(?i)savann?a",
      "type_affinity": ["normal", "fire", "ground"],
      "berry_pool": ["liechi", "salac"],
      "item_pool": ["choice-scarf", "muscle-band"]
    },
    {
      "id": "safari",
      "label": "Safari",
      "name_regex": "(?i)safari",
      "type_affinity": [],
      "berry_pool": ["apicot", "lansat", "starf", "micle", "custap"],
      "item_pool": ["king-s-rock", "amulet-coin", "shell-bell"]
    },
    {
      "id": "water",
      "label": "Water",
      "name_regex": "(?i)lake|sea|ocean|beach|shore|bay",
      "type_affinity": ["water"],
      "berry_pool": ["wacan", "passho", "babiri"],
      "item_pool": ["water-stone", "mystic-water", "sea-incense", "wave-incense", "deep-sea-tooth"]
    },
    {
      "id": "swamp",
      "label": "Swamp",
      "name_regex": "(?i)swamp|marsh|bog|mire",
      "type_affinity": ["grass", "poison", "water"],
      "berry_pool": ["kebia", "tanga", "shuca"],
      "item_pool": ["poison-barb", "black-sludge", "binding-band"]
    },
    {
      "id": "ice",
      "label": "Ice",
      "name_regex": "(?i)ice|frozen|snow|glacier|frost",
      "type_affinity": ["ice"],
      "berry_pool": ["yache", "pamtre"],
      "item_pool": ["never-melt-ice", "icy-rock", "ice-stone", "snowball"]
    },
    {
      "id": "ruins",
      "label": "Ruins",
      "name_regex": "(?i)ruins|tomb|tower|chamber",
      "type_affinity": ["ghost", "psychic", "rock"],
      "berry_pool": ["payapa", "colbur", "haban"],
      "item_pool": ["odd-keystone", "twisted-spoon", "spell-tag", "ancient-power"]
    },
    {
      "id": "urban",
      "label": "Urban",
      "name_regex": "(?i)city|town|gym",
      "type_affinity": ["normal", "electric", "steel"],
      "berry_pool": ["enigma", "ganlon"],
      "item_pool": ["soothe-bell", "metronome", "white-herb", "mental-herb"]
    },
    {
      "id": "sky",
      "label": "Sky",
      "name_regex": "(?i)sky|cloud|bell-tower-roof",
      "type_affinity": ["flying", "dragon"],
      "berry_pool": ["coba", "chilan"],
      "item_pool": ["dragon-fang", "dragon-scale", "draco-plate"]
    },
    {
      "id": "power-plant",
      "label": "Power Plant",
      "name_regex": "(?i)power|plant|reactor|lab",
      "type_affinity": ["electric", "steel"],
      "berry_pool": ["wepear", "pinap", "tamato"],
      "item_pool": ["magnet", "thunder-stone", "electirizer", "metal-coat"]
    },
    {
      "id": "graveyard",
      "label": "Graveyard",
      "name_regex": "(?i)grave|cemetery|lost-tower",
      "type_affinity": ["ghost"],
      "berry_pool": ["kasib", "rindo"],
      "item_pool": ["spell-tag", "reaper-cloth", "cursed-body"]
    },
    {
      "id": "farm",
      "label": "Farm",
      "name_regex": "(?i)farm|ranch|berry-fields",
      "type_affinity": ["grass", "normal"],
      "berry_pool": ["nanab", "razz", "bluk", "wepear"],
      "item_pool": ["soothe-bell", "leftovers"]
    },
    {
      "id": "wild",
      "label": "Wild",
      "name_regex": "",
      "type_affinity": [],
      "berry_pool": ["sitrus", "oran"],
      "item_pool": ["potion", "ether"]
    }
  ],
  "fallback_biome": "wild"
}
```

> Note for executor: this is a curated *starting* set. Pool entries are illustrative; user can refine post-install. Validation in Task 12 only checks structural shape, not curation quality.

- [ ] **Step 2: Validate it parses**

```bash
jq '.biomes | length' config/biomes.json
```

Expected: `18`.

```bash
jq -r '.biomes[].id' config/biomes.json | sort | uniq -d
```

Expected: empty (no duplicate ids).

- [ ] **Step 3: Commit**

```bash
git add config/biomes.json
git commit -m "feat(biome): initial 18-biome config with curated berry/item pools"
```

---

## Task 11: `lib/biome.bash` — config loader

**Files:**
- Create: `lib/biome.bash`
- Create: `tests/test-biome-config.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-biome-config.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR
    load_lib biome
}

teardown() {
    rm -rf "$POKIDLE_CONFIG_DIR"
}

@test "biome_config_path resolves env override or repo default" {
    run biome_config_path
    [ "$status" -eq 0 ]
    [ "$output" = "$POKIDLE_CONFIG_DIR/biomes.json" ]
}

@test "biome_load returns full config json" {
    run biome_load
    [ "$status" -eq 0 ]
    local n
    n="$(jq '.biomes | length' <<< "$output")"
    [ "$n" = "18" ]
}

@test "biome_get returns one biome by id" {
    run biome_get cave
    [ "$status" -eq 0 ]
    local id label
    id="$(jq -r '.id' <<< "$output")"
    label="$(jq -r '.label' <<< "$output")"
    [ "$id" = "cave" ]
    [ "$label" = "Cave" ]
}

@test "biome_get unknown id fails" {
    run biome_get not-a-biome
    [ "$status" -ne 0 ]
}

@test "biome_ids lists all ids" {
    run biome_ids
    [ "$status" -eq 0 ]
    local n
    n="$(printf '%s\n' "$output" | wc -l)"
    [ "$n" = "18" ]
}

@test "biome_validate passes on valid config" {
    run biome_validate
    [ "$status" -eq 0 ]
}

@test "biome_validate fails on duplicate id" {
    jq '.biomes[1].id="cave"' "$POKIDLE_CONFIG_DIR/biomes.json" > "$POKIDLE_CONFIG_DIR/biomes.json.new"
    mv "$POKIDLE_CONFIG_DIR/biomes.json.new" "$POKIDLE_CONFIG_DIR/biomes.json"
    run biome_validate
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-biome-config.bats
```

- [ ] **Step 3: Implement loader**

`lib/biome.bash`:

```bash
#!/usr/bin/env bash
# lib/biome.bash — biome config loader, classifier, rotation.

biome_config_path() {
    local p
    if [[ -n "${POKIDLE_CONFIG_DIR:-}" && -f "${POKIDLE_CONFIG_DIR}/biomes.json" ]]; then
        p="${POKIDLE_CONFIG_DIR}/biomes.json"
    elif [[ -n "${POKIDLE_REPO_ROOT:-}" && -f "${POKIDLE_REPO_ROOT}/config/biomes.json" ]]; then
        p="${POKIDLE_REPO_ROOT}/config/biomes.json"
    else
        printf 'biome_config_path: cannot find biomes.json\n' >&2
        return 1
    fi
    printf '%s' "$p"
}

biome_load() {
    local p
    p="$(biome_config_path)" || return 1
    cat "$p"
}

biome_get() {
    local id="$1"
    local out
    out="$(biome_load | jq --arg id "$id" '.biomes[] | select(.id==$id)')"
    [[ -n "$out" ]] || { printf 'biome_get: unknown biome %s\n' "$id" >&2; return 1; }
    printf '%s' "$out"
}

biome_ids() {
    biome_load | jq -r '.biomes[].id'
}

biome_validate() {
    local cfg
    cfg="$(biome_load)" || return 1

    # Required top-level shape
    if ! jq -e 'has("biomes") and has("fallback_biome")' <<< "$cfg" > /dev/null; then
        printf 'biome_validate: missing biomes or fallback_biome\n' >&2
        return 1
    fi

    # All biome objects have required keys
    local missing
    missing="$(jq -r '
        .biomes[] |
        select(
            (has("id")|not) or (has("label")|not) or
            (has("name_regex")|not) or (has("type_affinity")|not) or
            (has("berry_pool")|not) or (has("item_pool")|not)
        ) | .id // "<no-id>"
    ' <<< "$cfg")"
    if [[ -n "$missing" ]]; then
        printf 'biome_validate: biomes missing keys: %s\n' "$missing" >&2
        return 1
    fi

    # Duplicate ids
    local dupes
    dupes="$(jq -r '.biomes | group_by(.id) | map(select(length>1) | .[0].id) | .[]' <<< "$cfg")"
    if [[ -n "$dupes" ]]; then
        printf 'biome_validate: duplicate biome ids: %s\n' "$dupes" >&2
        return 1
    fi

    # Fallback biome must exist
    local fb
    fb="$(jq -r '.fallback_biome' <<< "$cfg")"
    if ! jq -e --arg fb "$fb" '.biomes[] | select(.id==$fb)' <<< "$cfg" > /dev/null; then
        printf 'biome_validate: fallback_biome "%s" not in biomes\n' "$fb" >&2
        return 1
    fi

    return 0
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-biome-config.bats
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/biome.bash tests/test-biome-config.bats
git commit -m "feat(biome): config loader, getter, validator"
```

---

## Task 12: `lib/biome.bash` — classifier

**Files:**
- Modify: `lib/biome.bash`
- Create: `tests/test-biome-classifier.bats`
- Create: `tests/fixtures/area-cave-001.json`
- Create: `tests/fixtures/area-route-1.json`
- Create: `tests/fixtures/area-volcano-crater.json`

- [ ] **Step 1: Add fixtures**

`tests/fixtures/area-cave-001.json` (minimal `/location-area` shape):

```json
{
  "name": "mt-moon-1f-area",
  "pokemon_encounters": [
    {"pokemon": {"name": "zubat"}},
    {"pokemon": {"name": "geodude"}}
  ]
}
```

`tests/fixtures/area-route-1.json`:

```json
{
  "name": "kanto-route-1-area",
  "pokemon_encounters": [
    {"pokemon": {"name": "pidgey"}},
    {"pokemon": {"name": "rattata"}}
  ]
}
```

`tests/fixtures/area-volcano-crater.json`:

```json
{
  "name": "mt-chimney-volcano-area",
  "pokemon_encounters": [
    {"pokemon": {"name": "numel"}},
    {"pokemon": {"name": "slugma"}}
  ]
}
```

The classifier needs pokemon-type info. We'll add type fixtures too.

`tests/fixtures/pokemon-zubat.json`:

```json
{"name":"zubat","types":[{"type":{"name":"poison"}},{"type":{"name":"flying"}}]}
```

`tests/fixtures/pokemon-geodude.json`:

```json
{"name":"geodude","types":[{"type":{"name":"rock"}},{"type":{"name":"ground"}}]}
```

`tests/fixtures/pokemon-pidgey.json`:

```json
{"name":"pidgey","types":[{"type":{"name":"normal"}},{"type":{"name":"flying"}}]}
```

`tests/fixtures/pokemon-rattata.json`:

```json
{"name":"rattata","types":[{"type":{"name":"normal"}}]}
```

`tests/fixtures/pokemon-numel.json`:

```json
{"name":"numel","types":[{"type":{"name":"fire"}},{"type":{"name":"ground"}}]}
```

`tests/fixtures/pokemon-slugma.json`:

```json
{"name":"slugma","types":[{"type":{"name":"fire"}}]}
```

- [ ] **Step 2: Write failing tests**

`tests/test-biome-classifier.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    load_lib biome
    stub_pokeapi
}

@test "classify_area: cave-named route maps to cave biome" {
    local area_json
    area_json="$(cat "$FIXTURE_DIR/area-cave-001.json")"
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    [ "$output" = "cave" ]
}

@test "classify_area: route-1 (pidgey/rattata) maps to plain via name regex" {
    local area_json
    area_json="$(cat "$FIXTURE_DIR/area-route-1.json")"
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    [ "$output" = "plain" ]
}

@test "classify_area: volcano area maps to volcano" {
    local area_json
    area_json="$(cat "$FIXTURE_DIR/area-volcano-crater.json")"
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    # mt-chimney-volcano matches both mountain (mt-) and volcano (volcano) — volcano scores higher with type overlap
    [ "$output" = "volcano" ]
}

@test "classify_area: area with no match falls back to wild" {
    local area_json='{"name":"unknown-zone","pokemon_encounters":[]}'
    run biome_classify_area "$area_json"
    [ "$status" -eq 0 ]
    [ "$output" = "wild" ]
}
```

- [ ] **Step 3: Run, expect fail**

```bash
bats tests/test-biome-classifier.bats
```

- [ ] **Step 4: Implement classifier**

Append to `lib/biome.bash`:

```bash
# Compute the union of types of every pokemon listed in an area's encounters.
# Echoes one type-name per line.
_biome_area_types() {
    local area_json="$1"
    local species
    species="$(jq -r '.pokemon_encounters[].pokemon.name' <<< "$area_json")"
    local s types
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        types="$(pokeapi_get "pokemon/$s" | jq -r '.types[].type.name')"
        printf '%s\n' $types
    done <<< "$species" | sort -u
}

# Classify a /location-area JSON to a biome id.
# Algorithm: name_regex match = +10, count of intersecting types in type_affinity
# adds to score. Highest scoring biome wins; on tie, first match by config order.
biome_classify_area() {
    local area_json="$1"
    local cfg
    cfg="$(biome_load)" || return 1
    local area_name
    area_name="$(jq -r '.name' <<< "$area_json")"

    local area_types_list
    area_types_list="$(_biome_area_types "$area_json")"

    local best_id="" best_score=0
    local i count
    count="$(jq '.biomes | length' <<< "$cfg")"

    for ((i=0; i<count; i++)); do
        local id regex affinity
        id="$(jq -r ".biomes[$i].id" <<< "$cfg")"
        regex="$(jq -r ".biomes[$i].name_regex" <<< "$cfg")"
        affinity="$(jq -r ".biomes[$i].type_affinity[]?" <<< "$cfg")"

        local score=0
        if [[ -n "$regex" ]] && grep -E -q "$regex" <<< "$area_name"; then
            score=$((score + 10))
        fi
        local t
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            if grep -Fxq "$t" <<< "$area_types_list"; then
                score=$((score + 1))
            fi
        done <<< "$affinity"

        if (( score > best_score )); then
            best_score=$score
            best_id="$id"
        fi
    done

    if (( best_score == 0 )); then
        jq -r '.fallback_biome' <<< "$cfg"
    else
        printf '%s' "$best_id"
    fi
}
```

Note: `grep -E -q` uses POSIX ERE — the `(?i)` PCRE syntax in `name_regex` needs translation. Replace with `grep -Ei` and strip `(?i)` from regex before matching.

Update the matching block:

```bash
        local pat="$regex"
        local flags="-E"
        if [[ "$pat" == *"(?i)"* ]]; then
            pat="${pat//\(?i\)/}"
            flags="-Ei"
        fi
        if [[ -n "$pat" ]] && grep $flags -q "$pat" <<< "$area_name"; then
            score=$((score + 10))
        fi
```

(replace the prior simple `grep -E -q "$regex"` block with this updated version above before running tests).

- [ ] **Step 5: Run tests, expect pass**

```bash
bats tests/test-biome-classifier.bats
```

Expected: 4 pass.

- [ ] **Step 6: Commit**

```bash
git add lib/biome.bash tests/test-biome-classifier.bats tests/fixtures
git commit -m "feat(biome): area classifier (regex + type-affinity scoring)"
```

---

## Task 13: `lib/biome.bash` — rotation

**Files:**
- Modify: `lib/biome.bash`
- Create: `tests/test-biome-rotation.bats`

- [ ] **Step 1: Write failing tests**

`tests/test-biome-rotation.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR
    load_lib biome
}

@test "biome_pick_random returns a valid biome id" {
    run biome_pick_random
    [ "$status" -eq 0 ]
    biome_get "$output" >/dev/null
}

@test "biome_pick_random_excluding never returns the excluded id" {
    local i out
    for i in {1..30}; do
        out="$(biome_pick_random_excluding cave)"
        [ "$out" != "cave" ]
    done
}

@test "biome_pick_random_excluding fails if only biome remaining is excluded" {
    # Patch config to have only 1 biome
    jq '.biomes = [.biomes[0]] | .fallback_biome = .biomes[0].id' \
        "$POKIDLE_CONFIG_DIR/biomes.json" > "$POKIDLE_CONFIG_DIR/tmp.json"
    mv "$POKIDLE_CONFIG_DIR/tmp.json" "$POKIDLE_CONFIG_DIR/biomes.json"

    run biome_pick_random_excluding "$(biome_ids)"
    [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run, expect fail**

```bash
bats tests/test-biome-rotation.bats
```

- [ ] **Step 3: Implement rotation**

Append to `lib/biome.bash`:

```bash
biome_pick_random() {
    local ids n idx
    mapfile -t ids < <(biome_ids)
    n="${#ids[@]}"
    (( n > 0 )) || { printf 'biome_pick_random: no biomes\n' >&2; return 1; }
    idx=$((RANDOM % n))
    printf '%s' "${ids[$idx]}"
}

biome_pick_random_excluding() {
    local exclude="$1"
    local ids filtered idx n
    mapfile -t ids < <(biome_ids)
    filtered=()
    local id
    for id in "${ids[@]}"; do
        [[ "$id" != "$exclude" ]] && filtered+=("$id")
    done
    n="${#filtered[@]}"
    (( n > 0 )) || { printf 'biome_pick_random_excluding: no eligible biome\n' >&2; return 1; }
    idx=$((RANDOM % n))
    printf '%s' "${filtered[$idx]}"
}
```

- [ ] **Step 4: Run, expect pass**

```bash
bats tests/test-biome-rotation.bats
```

Expected: 3 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/biome.bash tests/test-biome-rotation.bats
git commit -m "feat(biome): random rotation pickers"
```

---

## Task 14: Final integration smoke test

**Files:**
- Create: `tests/test-foundation-smoke.bats`

- [ ] **Step 1: Write integration smoke**

```bash
#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_DB_PATH="$(make_tmp_db)"
    export POKIDLE_DB_PATH
    POKIDLE_REPO_ROOT="$REPO_ROOT"
    export POKIDLE_REPO_ROOT
    POKIDLE_CONFIG_DIR="$BATS_TMPDIR/cfg.$$"
    mkdir -p "$POKIDLE_CONFIG_DIR"
    cp "$REPO_ROOT/config/biomes.json" "$POKIDLE_CONFIG_DIR/biomes.json"
    export POKIDLE_CONFIG_DIR

    load_lib db
    load_lib biome
}

teardown() {
    rm -f "$POKIDLE_DB_PATH"
    rm -rf "$POKIDLE_CONFIG_DIR"
}

@test "foundation: pick biome -> open session -> insert encounter -> list" {
    db_init
    biome_validate

    local biome
    biome="$(biome_pick_random)"
    local sid
    sid="$(db_open_biome_session "$biome" "$(date +%s)")"

    local enc
    enc=$(jq -n --argjson sid "$sid" '{
        session_id: $sid, encountered_at: 1700001000,
        species: "zubat", dex_id: 41, level: 7,
        nature: "adamant", ability: "inner-focus", is_hidden_ability: 0,
        gender: "M", shiny: 0, held_berry: null,
        ivs: [10,20,30,15,5,25], evs: [0,0,0,0,0,0],
        stats: [22,18,15,12,15,30],
        moves: ["leech-life","supersonic","astonish","bite"],
        sprite_path: null
    }')
    db_insert_encounter "$enc"

    run db_list_encounters --limit 5
    [ "$status" -eq 0 ]
    local n
    n="$(jq 'length' <<< "$output")"
    [ "$n" = "1" ]
}
```

- [ ] **Step 2: Run, expect pass**

```bash
bats tests/test-foundation-smoke.bats
```

Expected: 1 pass.

- [ ] **Step 3: Run full suite**

```bash
bats tests/
```

Expected: every test in every file passes.

- [ ] **Step 4: Commit**

```bash
git add tests/test-foundation-smoke.bats
git commit -m "test: foundation integration smoke (biome pick + session + encounter)"
```

---

## Plan A complete

End state: `lib/db.bash`, `lib/biome.bash`, `schema.sql`, `config/biomes.json` all in place and tested. `pokeapi` renamed and rate-limited. Foundation is ready for Plan B's encounter engine.

## Self-review notes

- All spec sections covered by Plan A: HTTP rate-limit, pokeapi rename, schema, db CRUD (sessions/encounters/items/state), biome config, classifier, rotation, initial 18-biome curation. Encounter engine + CLI + daemon are intentionally deferred to Plans B and C.
- Type consistency: function names used in tests (`db_init`, `db_open_biome_session`, `db_insert_encounter`, `biome_load`, `biome_get`, `biome_classify_area`, `biome_pick_random`, `biome_pick_random_excluding`) match implementations.
- `_biome_area_types` is a helper defined and used inside classifier (Task 12).
- `POKIDLE_REPO_ROOT` is required by `db_init` to locate `schema.sql`; tests export it; pokidle entry script (Plan B Task 23) will export it from `BASH_SOURCE`.
